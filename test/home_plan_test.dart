// `HomePlanController` against real `DriftMedicineRepository`/
// `DriftDoseRepository` over an in-memory database -- one test per row of this
// spec's I/O matrix, following `dose_generator_test.dart`'s shape.
//
// Testing depth is LIGHTER (project-context.md): this story writes no new
// save/delete path of its own (the provisional generation call reuses 1.7b's
// already-tested logic), so there is no mutation-testing pass here, only the
// matrix.
//
// Every test builds its own `ProviderContainer` over its own in-memory
// database, overriding exactly `medicineRepositoryProvider`,
// `doseRepositoryProvider` and `clockProvider` -- `doseGeneratorProvider`
// needs no override of its own, since it composes the two repository
// providers once they are bound (`dose_generator_provider.dart`'s own file
// comment).

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/dose_repository_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/dose_state.dart';
import 'package:med_remind_app/domain/port/clock.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/features/home/application/home_plan_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fixed_clock.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // A Wednesday, mid-morning -- `FixedClock`'s own reference instant, reused
  // so a test that does not need a different "now" reads the same way
  // `dose_generator_test.dart`'s own tests do.
  final DateTime defaultNow = DateTime(2026, 9, 9, 10, 30);
  final DateTime defaultStart = DateTime(2026, 9, 7);

  /// A fresh in-memory database, its two repositories, and a
  /// `ProviderContainer` wired over them and [clock].
  ///
  /// Returned together because every test needs to seed through the
  /// repositories and then read the controller over the same instances.
  ({
    ProviderContainer container,
    MedicineRepository medicines,
    DoseRepository doses,
  })
  buildContainer({DateTime? now}) {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final MedicineRepository medicines = DriftMedicineRepository(database);
    final DoseRepository doses = DriftDoseRepository(database);
    final Clock clock = FixedClock(instant: now ?? defaultNow);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        medicineRepositoryProvider.overrideWithValue(medicines),
        doseRepositoryProvider.overrideWithValue(doses),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    return (container: container, medicines: medicines, doses: doses);
  }

  Future<Medicine> addMedicine(
    MedicineRepository medicines, {
    String name = 'Metformin',
    String? condition,
    DateTime? startDate,
    DateTime? endDate,
  }) => medicines.addMedicine(
    name: name,
    condition: condition,
    form: 'tablet',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    startDate: startDate ?? defaultStart,
    endDate: endDate,
  );

  Future<Schedule> addSchedule(
    MedicineRepository medicines,
    String medicineId, {
    required String timeOfDay,
  }) => medicines.addSchedule(
    medicineId: medicineId,
    timeOfDay: timeOfDay,
    ianaTimezone: FixedClock.defaultZone,
    frequency: Frequency.everyDay,
    dosageAmount: 1,
  );

  group('no Medicines (the spec\'s "No Medicines" row)', () {
    test(
      'the plan is empty and coherent -- rendering the empty state is '
      'Story 1.9\'s, but this controller must not fail one story early',
      () async {
        final c = buildContainer();

        final HomePlan plan = await c.container.read(
          homePlanControllerProvider.future,
        );

        expect(plan.dosesScheduled, 0);
        expect(plan.dosesTaken, 0);
        expect(plan.overdueCount, 0);
        expect(plan.nextDoseAt, isNull);
        expect(plan.doses, isEmpty);
        expect(plan.weekStrip, hasLength(7));
        expect(plan.weekStrip.first.isToday, isTrue);
      },
    );
  });

  group('Doses exist, none acted on (the spec\'s own row)', () {
    test('3 Doses today, all Scheduled/Due -- ascending by time, progress '
        '0 of 3', () async {
      final c = buildContainer();
      final Medicine medicine = await addMedicine(c.medicines);
      // A single-schedule Medicine's own escalation window is 6h (its
      // only later occurrence is 24h away, quartered and clamped) -- long
      // enough that 08:00 is still Due at 10:30, the default `now`.
      await addSchedule(c.medicines, medicine.id, timeOfDay: '08:00');
      final Medicine second = await addMedicine(c.medicines, name: 'B');
      await addSchedule(c.medicines, second.id, timeOfDay: '12:00');
      final Medicine third = await addMedicine(c.medicines, name: 'C');
      await addSchedule(c.medicines, third.id, timeOfDay: '18:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.dosesScheduled, 3);
      expect(plan.dosesTaken, 0);
      expect(
        plan.doses.map((HomeDoseEntry e) => e.dose.scheduledLocal.hour),
        <int>[8, 12, 18],
        reason: 'ascending by scheduled time',
      );
      expect(plan.doses[0].resolution.state, DoseState.due);
      expect(plan.doses[1].resolution.state, DoseState.scheduled);
      expect(plan.doses[2].resolution.state, DoseState.scheduled);
    });
  });

  group('an overdue Dose (the spec\'s own row)', () {
    test(
      'one Dose past its window, same logical day -- counted Overdue',
      () async {
        final c = buildContainer(now: DateTime(2026, 9, 9, 14, 0));
        final Medicine medicine = await addMedicine(c.medicines);
        // 6h window (single schedule): Due until 13:00, Overdue from 13:00
        // until the logical day turns over at 04:00 the next morning. `now` is
        // 14:00, comfortably inside the Overdue span and nowhere near that
        // boundary.
        await addSchedule(c.medicines, medicine.id, timeOfDay: '07:00');

        final HomePlan plan = await c.container.read(
          homePlanControllerProvider.future,
        );

        expect(plan.overdueCount, 1);
        expect(plan.doses.single.resolution.state, DoseState.overdue);
      },
    );
  });

  group('no overdue Doses (the spec\'s own row)', () {
    test('all Scheduled/Due -- banner absent (overdueCount is 0)', () async {
      final c = buildContainer();
      final Medicine medicine = await addMedicine(c.medicines);
      await addSchedule(c.medicines, medicine.id, timeOfDay: '08:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.overdueCount, 0);
    });
  });

  group('Condition present (the spec\'s own row)', () {
    test('the entry carries the Medicine\'s Condition', () async {
      final c = buildContainer();
      final Medicine medicine = await addMedicine(
        c.medicines,
        condition: 'Type 2 diabetes',
      );
      await addSchedule(c.medicines, medicine.id, timeOfDay: '08:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.doses.single.condition, 'Type 2 diabetes');
    });
  });

  group('no Condition (the spec\'s own row)', () {
    test('the entry\'s condition is null', () async {
      final c = buildContainer();
      final Medicine medicine = await addMedicine(c.medicines);
      await addSchedule(c.medicines, medicine.id, timeOfDay: '08:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.doses.single.condition, isNull);
    });
  });

  group('Same Medicine, two Schedules (the spec\'s own row)', () {
    test('both Doses carry the identical glyphIndex', () async {
      final c = buildContainer();
      final Medicine medicine = await addMedicine(c.medicines);
      await addSchedule(c.medicines, medicine.id, timeOfDay: '08:00');
      await addSchedule(c.medicines, medicine.id, timeOfDay: '20:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.doses, hasLength(2));
      expect(plan.doses[0].glyphIndex, plan.doses[1].glyphIndex);
    });
  });

  group('Next-dose chip, doses remain (the spec\'s own row)', () {
    test(
      'a later Scheduled/Due Dose exists today -- chip shows its time',
      () async {
        final c = buildContainer(now: DateTime(2026, 9, 9, 14, 0));
        final Medicine early = await addMedicine(c.medicines, name: 'Early');
        // Overdue by 14:00 (see the "overdue Dose" group above), so it must be
        // skipped by the next-dose search.
        await addSchedule(c.medicines, early.id, timeOfDay: '07:00');
        final Medicine later = await addMedicine(c.medicines, name: 'Later');
        await addSchedule(c.medicines, later.id, timeOfDay: '16:00');

        final HomePlan plan = await c.container.read(
          homePlanControllerProvider.future,
        );

        expect(plan.nextDoseAt, isNotNull);
        expect(plan.nextDoseAt!.hour, 16);
      },
    );
  });

  group('Next-dose chip, none left today (the spec\'s own row)', () {
    test('every today\'s Dose already past Due/Overdue -- falls back to '
        'tomorrow\'s first Dose', () async {
      final c = buildContainer(now: DateTime(2026, 9, 9, 14, 0));
      final Medicine medicine = await addMedicine(c.medicines);
      // Overdue by 14:00, and the only Dose today; the everyDay Schedule
      // also has a Dose tomorrow at the same wall-clock time, inside the
      // 14-day horizon.
      await addSchedule(c.medicines, medicine.id, timeOfDay: '07:00');

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.overdueCount, 1, reason: 'today\'s own Dose is Overdue');
      expect(plan.nextDoseAt, isNotNull);
      // Compared against today's own (Overdue) Dose instant rather than a
      // bare `DateTime(2026, 9, 10)`: both sides here are real
      // `Asia/Colombo` instants built the same way, so the comparison holds
      // on any host machine. A naive local literal would not -- see
      // `dose_repository_test.dart`'s own note on exactly this pitfall.
      expect(
        plan.nextDoseAt!.isAfter(plan.doses.single.dose.scheduledAt),
        isTrue,
        reason: 'the fallback is tomorrow\'s occurrence, not today\'s',
      );
    });
  });

  group('Next-dose chip, nothing anywhere (the spec\'s own row)', () {
    test(
      'no Dose exists in the visible future -- nextDoseAt is null',
      () async {
        final c = buildContainer();
        // Started and ended entirely in the past: `occurrencesFor` clips the
        // horizon to `endDate`, which is before `today`, so generation writes
        // nothing at all for this Medicine.
        await addMedicine(
          c.medicines,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        );

        final HomePlan plan = await c.container.read(
          homePlanControllerProvider.future,
        );

        expect(plan.nextDoseAt, isNull);
        expect(plan.dosesScheduled, 0);
      },
    );
  });

  group(
    'First Medicine just saved (the spec\'s own row, this story\'s AC1)',
    () {
      test(
        'end to end through MedicineRepository -- not a test that seeds '
        'Doses directly -- the plan is populated with no manual refresh',
        () async {
          final c = buildContainer();

          // Nothing seeded yet: the same starting point as Story 1.9's empty
          // state.
          final HomePlan before = await c.container.read(
            homePlanControllerProvider.future,
          );
          expect(before.dosesScheduled, 0);

          // The real save path a user's "Add medicine" flow takes --
          // `MedicineRepository`, never a Dose constructed and inserted by
          // hand.
          final Medicine saved = await addMedicine(
            c.medicines,
            name: 'Atorvastatin',
          );
          await addSchedule(c.medicines, saved.id, timeOfDay: '08:00');

          // "Returns to Home": a fresh read of the controller, exactly what
          // happens when the add-medicine route replaces itself with Home's
          // and `homePlanControllerProvider` (`autoDispose`) rebuilds from
          // nothing. A new container stands in for that remount here.
          final ProviderContainer after = ProviderContainer(
            overrides: <Override>[
              medicineRepositoryProvider.overrideWithValue(c.medicines),
              doseRepositoryProvider.overrideWithValue(c.doses),
              clockProvider.overrideWithValue(FixedClock(instant: defaultNow)),
            ],
          );
          addTearDown(after.dispose);

          final HomePlan plan = await after.read(
            homePlanControllerProvider.future,
          );

          expect(plan.dosesScheduled, 1);
          expect(plan.doses.single.dose.medicineName, 'Atorvastatin');
        },
      );
    },
  );

  group('Cold start (the spec\'s own row)', () {
    test('five Medicines -- generation and the read both complete and produce '
        'a coherent plan', () async {
      // This is a correctness smoke test, not a latency measurement: a
      // `flutter test` process on arbitrary CI hardware cannot stand in for
      // "a mid-tier Android device", so the 1.5s budget itself (AD-21,
      // NFR-4) is not asserted here. What IS verified is the property a
      // unit test can actually see: `build()` runs to completion over a
      // typical five-Medicine regimen and returns a well-formed plan, and
      // (by inspection, not by clocking) `build()` is `async` throughout --
      // see `home_plan_controller.dart`'s own file comment for why that is
      // what "dispatched after first frame, not gating it" reduces to
      // outside a real device.
      final c = buildContainer();
      for (int i = 0; i < 5; i++) {
        final Medicine medicine = await addMedicine(
          c.medicines,
          name: 'Medicine $i',
        );
        await addSchedule(
          c.medicines,
          medicine.id,
          timeOfDay: '${(8 + i).toString().padLeft(2, '0')}:00',
        );
      }

      final HomePlan plan = await c.container.read(
        homePlanControllerProvider.future,
      );

      expect(plan.dosesScheduled, 5);
      expect(
        plan.doses.map((HomeDoseEntry e) => e.dose.medicineName).toSet(),
        <String>{for (int i = 0; i < 5; i++) 'Medicine $i'},
      );
    });
  });
}
