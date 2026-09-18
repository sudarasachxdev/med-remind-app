// `Reconciler` -- AD-9's five-step pipeline, this story's own orchestrator.
//
// Testing depth is LIGHTER (project-context.md): the rows this spec's own
// task list names, not an exhaustive matrix. `DoseGenerator`,
// `ReminderScheduler` and `notification_budget_policy.dart` each already have
// their own exhaustive test files -- this file is about ORCHESTRATION: did
// `Reconciler` call the right things, in the right order, with the right
// arguments, not about re-proving what those already-tested pieces do on
// their own.
//
// Driven against REAL `DriftMedicineRepository`/`DriftDoseRepository`/
// `DriftReconciliationStateStore` over an in-memory database, and a REAL
// `DoseGenerator`/`ReminderScheduler` -- both are `final class`es (a domain
// SERVICE, not a port), so nothing here can fake them, matching
// `dose_generator_test.dart`'s own shape. Only `DoseNotifier` (a port) is
// faked, with `FakeDoseNotifier`. A `RecordingInterceptor` watches the SQL
// that reaches the in-memory database, which is how a delete-then-regenerate
// (`regenerateAfterScheduleChange`'s own shape) is told apart from a bare
// `generate()` call, which never deletes anything.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/data/repository/drift_reconciliation_state_store.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/policy/dose_resolution_policy.dart';
import 'package:med_remind_app/domain/policy/notification_budget_policy.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/domain/port/reconciliation_state_store.dart';
import 'package:med_remind_app/domain/service/dose_generator.dart';
import 'package:med_remind_app/domain/service/reconciler.dart';
import 'package:med_remind_app/domain/service/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_dose_notifier.dart';
import 'support/fixed_clock.dart';
import 'support/recording_interceptor.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // A Wednesday, mid-morning -- `FixedClock`'s own reference instant, reused
  // so this file's reasoning about "future" vs "already due" matches
  // `dose_generator_test.dart`/`home_plan_test.dart`'s own tests.
  final DateTime now = DateTime(2026, 9, 9, 10, 30);
  final DateTime startDate = DateTime(2026, 9, 7);

  late AppDatabase database;
  late RecordingInterceptor recorder;
  late MedicineRepository medicines;
  late DoseRepository doses;
  late ReconciliationStateStore reconciliationState;
  late FakeDoseNotifier notifier;

  setUp(() {
    recorder = RecordingInterceptor();
    database = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
    medicines = DriftMedicineRepository(database);
    doses = DriftDoseRepository(database);
    reconciliationState = DriftReconciliationStateStore(database);
    notifier = FakeDoseNotifier();
  });

  tearDown(() async {
    await database.close();
  });

  /// A fresh `Reconciler` over this test's shared repositories/notifier, with
  /// its own `Clock` fixed at [now] in [zone]. A new instance each call
  /// (rather than one shared across a test) mirrors how `reconcilerProvider`
  /// itself is stateless and rebuilt on every `HomePlanController.build()`.
  Reconciler buildReconciler({String zone = FixedClock.defaultZone}) {
    final FixedClock clock = FixedClock(instant: now, ianaTimezone: zone);
    return Reconciler(
      clock,
      medicines,
      doses,
      DoseGenerator(medicines, doses),
      ReminderScheduler(notifier),
      notifier,
      reconciliationState,
    );
  }

  Future<Medicine> addMedicine({bool active = true}) => medicines.addMedicine(
    name: 'Metformin',
    form: 'tablet',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    startDate: startDate,
    active: active,
  );

  Future<Schedule> addSchedule(
    String medicineId, {
    String timeOfDay = '08:00',
    String zone = FixedClock.defaultZone,
    bool remindersEnabled = true,
  }) => medicines.addSchedule(
    medicineId: medicineId,
    timeOfDay: timeOfDay,
    ianaTimezone: zone,
    frequency: Frequency.everyDay,
    dosageAmount: 1,
    remindersEnabled: remindersEnabled,
  );

  final DateTime today = Medicine.dateOnly(now);
  final DateTime horizonEnd = today.add(
    const Duration(days: doseResolveWindowDays),
  );

  group('first run (no prior zone)', () {
    test('does not react to a zone change -- there is nothing to react to '
        'yet -- but does establish the baseline', () async {
      final Medicine medicine = await addMedicine();
      await addSchedule(medicine.id);
      recorder.clear();

      await buildReconciler().run();

      expect(
        recorder.deletes,
        isEmpty,
        reason:
            'a null stored zone must not be treated as a change: every '
            'Schedule that exists was already created with a real zone',
      );
      expect(
        await reconciliationState.lastKnownIanaTimezone(),
        FixedClock.defaultZone,
        reason:
            'step 3 persists the current zone unconditionally, even on '
            'a first run',
      );
    });

    test(
      'does not react even when an existing Schedule\'s own zone differs '
      'from the current one, as long as no baseline was ever stored',
      () async {
        // The test above cannot tell "the null-baseline guard is doing its
        // job" apart from "there is nothing to react to regardless" -- its
        // Schedule and its Reconciler both use `FixedClock.defaultZone`, so
        // the per-Schedule `if (schedule.ianaTimezone == currentZone)
        // continue` inside `_reactToZoneChange` would mask a missing outer
        // guard just as completely as a correct one. Seeding a genuine
        // mismatch here is what actually exercises "a `null` stored value
        // does not count as a change" (`reconciler.dart`'s own step-1 doc
        // comment) rather than merely being consistent with it.
        final Medicine medicine = await addMedicine();
        final Schedule schedule = await addSchedule(
          medicine.id,
          zone: 'Asia/Colombo',
        );
        recorder.clear();

        await buildReconciler(zone: 'America/New_York').run();

        expect(
          recorder.deletes,
          isEmpty,
          reason:
              'a first run must not treat a pre-existing zone mismatch as '
              'something to react to -- there is no prior baseline to have '
              'changed FROM',
        );
        final Schedule stored = (await medicines.schedulesFor(
          medicine.id,
        )).single;
        expect(
          stored.ianaTimezone,
          schedule.ianaTimezone,
          reason:
              'the Schedule\'s own zone must be left exactly as it was '
              'saved -- only step 2, gated on a real detected change, is '
              'permitted to rewrite it',
        );
      },
    );
  });

  group('unchanged zone', () {
    test(
      'reacts to neither -- no delete, no Schedule write for the zone',
      () async {
        final Medicine medicine = await addMedicine();
        await addSchedule(medicine.id);
        await buildReconciler().run(); // establishes the baseline
        recorder.clear();

        await buildReconciler().run(); // same zone as the baseline

        expect(
          recorder.deletes,
          isEmpty,
          reason:
              'an unchanged zone must trigger neither a Schedule update nor '
              'regenerateAfterScheduleChange\'s own delete step',
        );
      },
    );
  });

  group('changed zone', () {
    test('updates every Schedule\'s ianaTimezone and regenerates its Doses '
        '-- scheduledUtc needs no separate recompute step', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await addSchedule(
        medicine.id,
        zone: 'Asia/Colombo',
      );
      await buildReconciler(zone: 'Asia/Colombo').run(); // baseline

      recorder.clear();
      const String newZone = 'America/New_York';
      await buildReconciler(zone: newZone).run();

      expect(
        recorder.deletes,
        isNotEmpty,
        reason:
            'regenerateAfterScheduleChange deletes future Doses before '
            'rebuilding them -- a bare generate() call never deletes '
            'anything, so a delete is only explainable by this call having '
            'happened',
      );

      final Schedule updated = (await medicines.schedulesFor(
        medicine.id,
      )).single;
      expect(updated.ianaTimezone, newZone);

      final List<Dose> regenerated = await doses.dosesForSchedule(schedule.id);
      expect(regenerated, isNotEmpty);
      for (final Dose dose in regenerated) {
        expect(
          dose.ianaTimezone,
          newZone,
          reason:
              'the load-bearing fact this design rests on: Dose always '
              're-derives scheduledAt from scheduledLocal + ianaTimezone, so '
              'updating the stored zone and regenerating is the whole of '
              '"recompute scheduledUtc" -- no separate persistence step',
        );
      }
    });

    test('reacts regardless of the owning Medicine\'s active state', () async {
      final Medicine medicine = await addMedicine(active: false);
      await addSchedule(medicine.id, zone: 'Asia/Colombo');
      await buildReconciler(zone: 'Asia/Colombo').run();

      recorder.clear();
      const String newZone = 'America/New_York';
      await buildReconciler(zone: newZone).run();

      final Schedule updated = (await medicines.schedulesFor(
        medicine.id,
      )).single;
      expect(
        updated.ianaTimezone,
        newZone,
        reason:
            'a paused medicine\'s schedule should still reflect where the '
            'user actually is; regenerateAfterScheduleChange\'s own '
            'active-state check already no-ops the dose side of it',
      );
    });
  });

  group('generation', () {
    test('generate() always runs, unconditionally', () async {
      final Medicine medicine = await addMedicine();
      await addSchedule(medicine.id);

      await buildReconciler().run();

      final List<Dose> visible = await doses.dosesScheduledBetween(
        today,
        horizonEnd,
      );
      expect(
        visible,
        isNotEmpty,
        reason:
            'this is what makes "the app was closed across several days" '
            'work regardless of whether a zone change also occurred',
      );
    });
  });

  group('re-registration within budget', () {
    test('cancels every candidate and schedules a primary only for those '
        'planBudget gives a non-empty tier list, in ascending scheduledAt '
        'order', () async {
      final Medicine medicine = await addMedicine();
      // Both times are still ahead of `now` (10:30), so both today's
      // occurrences are real candidates -- `needsChainConsidered` excludes
      // anything already at or past its own scheduled time.
      await addSchedule(medicine.id, timeOfDay: '11:00');
      await addSchedule(medicine.id, timeOfDay: '12:00');

      await buildReconciler().run();

      final List<Dose> visible = await doses.dosesScheduledBetween(
        today,
        horizonEnd,
      );
      final List<Dose> candidates =
          visible.where((Dose dose) => needsChainConsidered(dose, now)).toList()
            ..sort((Dose a, Dose b) => a.scheduledAt.compareTo(b.scheduledAt));
      // Both schedules generate a Dose for every one of the 14 horizon days,
      // well within `fullChainDoseCount`, so every one of them is scheduled.
      expect(candidates.length, greaterThan(1));

      expect(notifier.cancelled, hasLength(candidates.length));
      expect(notifier.scheduled, hasLength(candidates.length));

      final List<String> scheduledOrder = notifier.scheduled
          .map((r) => r.$1)
          .toList();
      expect(
        scheduledOrder,
        candidates.map((Dose d) => d.id).toList(),
        reason:
            'schedulePrimary must be called in ascending scheduledAt order, '
            'matching the rank planBudget assigned',
      );
    });

    test(
      'a rank beyond budget (AD-8) is cancelled and left unscheduled',
      () async {
        final Medicine medicine = await addMedicine();
        // Four schedules, all still ahead of `now`, each producing one Dose
        // per horizon day (14) -- 56 candidates, comfortably past
        // `budgetedDoseCount` (44), without needing 45+ distinct Schedules.
        for (final String time in <String>[
          '11:00',
          '12:00',
          '13:00',
          '14:00',
        ]) {
          await addSchedule(medicine.id, timeOfDay: time);
        }

        await buildReconciler().run();

        final List<Dose> visible = await doses.dosesScheduledBetween(
          today,
          horizonEnd,
        );
        final List<Dose> candidates =
            visible
                .where((Dose dose) => needsChainConsidered(dose, now))
                .toList()
              ..sort(
                (Dose a, Dose b) => a.scheduledAt.compareTo(b.scheduledAt),
              );
        expect(candidates.length, greaterThan(budgetedDoseCount));

        expect(
          notifier.cancelled,
          hasLength(candidates.length),
          reason: 'cancelPending runs for every candidate, regardless of rank',
        );

        final Set<String> scheduledIds = notifier.scheduled
            .map((r) => r.$1)
            .toSet();
        for (int rank = 0; rank < candidates.length; rank++) {
          final bool withinBudget = rank < budgetedDoseCount;
          expect(
            scheduledIds.contains(candidates[rank].id),
            withinBudget,
            reason:
                'rank $rank ${withinBudget ? "is" : "is not"} within budget',
          );
        }
      },
    );

    test('a reminders-disabled Schedule\'s Doses are excluded from ranking '
        'entirely -- never cancelled or scheduled', () async {
      final Medicine medicine = await addMedicine();
      await addSchedule(
        medicine.id,
        timeOfDay: '11:00',
        remindersEnabled: false,
      );

      await buildReconciler().run();

      expect(
        notifier.cancelled,
        isEmpty,
        reason:
            'a reminders-disabled Dose must not spend a rank a real, '
            'enabled Dose could use -- so it is excluded from ranking '
            'entirely, not merely left unscheduled',
      );
      expect(notifier.scheduled, isEmpty);
    });
  });

  group('order of operations', () {
    test('zone reaction happens before generation happens before '
        're-registration', () async {
      // One scenario that would fail under any of the three ordering bugs
      // AD-9 names, without needing a byte-level interleaving of DB
      // statements and notifier calls (this file's own testing-depth note):
      //
      //  * if re-registration ran BEFORE generation, `notifier.scheduled`
      //    would be empty here -- there would be nothing generated yet to
      //    query.
      //  * if the zone were persisted BEFORE being compared against, this
      //    zone change would never be detected at all (the "changed zone"
      //    group above already guards this specific case).
      //  * if generation ran BEFORE the zone reaction in a way that left the
      //    regenerated Doses under the OLD zone, the assertion below would
      //    catch it directly.
      final Medicine medicine = await addMedicine();
      await addSchedule(medicine.id, zone: 'Asia/Colombo');
      await buildReconciler(zone: 'Asia/Colombo').run(); // baseline

      const String newZone = 'America/New_York';
      await buildReconciler(zone: newZone).run();

      final List<Dose> visible = await doses.dosesScheduledBetween(
        today,
        horizonEnd,
      );
      expect(visible, isNotEmpty);
      for (final Dose dose in visible) {
        expect(dose.ianaTimezone, newZone);
      }
      expect(
        notifier.scheduled,
        isNotEmpty,
        reason:
            're-registration must see generation\'s own output, in the new '
            'zone -- proving both "react before generate" and "generate '
            'before re-register" held in the same run',
      );
    });
  });
}
