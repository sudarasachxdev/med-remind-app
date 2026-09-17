// `DoseRecorder` -- one test per row of this spec's I/O & Edge-Case Matrix,
// following `dose_generator_test.dart`'s shape: a real `DriftDoseRepository`
// over an in-memory database (AD-19: in-memory, not a device), a `FixedClock`
// so "now" is an assertion about a known instant, and a `FakeDoseNotifier` so
// cancellation can be counted rather than merely trusted.
//
// Testing depth is STANDARD for this story specifically (project-context.md
// names the dose-state resolver as one of the cases worth a full table
// regardless of the general lighter policy, and DoseRecorder is that
// resolver's write-side counterpart) -- every matrix row gets its own test,
// including both failure-surfacing rows.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/dose_state.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/policy/dose_resolver.dart';
import 'package:med_remind_app/domain/policy/snooze_policy.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/domain/service/dose_recorder.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_dose_notifier.dart';
import 'support/fixed_clock.dart';

void main() {
  // Every `Dose` construction resolves its zone through `package:timezone`
  // (`Dose._asInstant`), which throws until the database is loaded -- the
  // same house rule `dose_generator_test.dart`/`dose_repository_test.dart`
  // follow: only the composition root and a test's own setUp call this.
  setUpAll(tzdata.initializeTimeZones);

  // `FixedClock`'s own reference instant: a Wednesday, mid-morning, reused
  // here so this file's arithmetic reads the same way sibling test files'
  // does. Every test below is anchored on this one "now".
  final DateTime now = FixedClock.defaultInstant;

  /// Compares by instant only, ignoring UTC/local/`TZDateTime` flavour.
  ///
  /// `DateTime.==` does not: a value read back from the database is always
  /// UTC-flavoured (`DriftDoseRepository._doseFromRow`), matching
  /// `dose_generator_test.dart`'s own note on why its `actedOn` helper takes
  /// a `DateTime.utc(...)` rather than a local one. `now` here is local
  /// (`FixedClock`'s own shape), so a raw `equals(now)` against a round-
  /// tripped field fails despite naming the same instant.
  Matcher sameMoment(DateTime expected) => predicate<DateTime?>(
    (DateTime? actual) => actual != null && actual.isAtSameMomentAs(expected),
    'is at the same moment as $expected',
  );

  late AppDatabase database;
  late DoseRepository doses;
  late MedicineRepository medicines;
  late Schedule schedule;
  late FakeDoseNotifier notifier;
  late DoseRecorder recorder;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    doses = DriftDoseRepository(database);
    medicines = DriftMedicineRepository(database);
    notifier = FakeDoseNotifier();
    recorder = DoseRecorder(FixedClock(), doses, notifier);

    // A real Medicine and Schedule for every Dose below to reference:
    // `doses.schedule_id`/`doses.medicine_id` are enforced foreign keys,
    // matching `dose_repository_test.dart`'s own `seedSchedule` pattern.
    final Medicine medicine = await medicines.addMedicine(
      name: 'Metformin',
      form: 'tablet',
      dosageAmount: 1,
      dosageUnit: 'tablet',
      startDate: DateTime(2026, 8, 1),
    );
    schedule = await medicines.addSchedule(
      remindersEnabled: true,
      medicineId: medicine.id,
      timeOfDay: '08:00',
      ianaTimezone: 'Asia/Colombo',
      frequency: Frequency.everyDay,
      dosageAmount: 1,
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// A Dose scheduled at [scheduledLocal] on the seeded [schedule], with
  /// every other field defaulted to something plausible.
  Dose buildDose({
    required DateTime scheduledLocal,
    int escalationWindowMinutes = 60,
    DateTime? takenAt,
    DateTime? skippedAt,
    DateTime? snoozedUntil,
    int snoozeCount = 0,
  }) => Dose(
    scheduleId: schedule.id,
    medicineId: schedule.medicineId,
    scheduledLocal: scheduledLocal,
    ianaTimezone: schedule.ianaTimezone,
    takenAt: takenAt,
    skippedAt: skippedAt,
    snoozedUntil: snoozedUntil,
    snoozeCount: snoozeCount,
    escalationWindowMinutes: escalationWindowMinutes,
    medicineName: 'Metformin',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    form: 'tablet',
  );

  group('take', () {
    test('on time: takenAt = now, resolves Taken, not late', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        escalationWindowMinutes: 60,
      );
      await doses.saveDose(dose);

      await recorder.take(dose);

      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.takenAt, sameMoment(now));
      expect(resolve(saved, now), DoseResolution(DoseState.taken));
      expect(notifier.cancelled, equals([dose.id]));
    });

    test(
      'after the window: takenAt = now, resolves Taken, logged late',
      () async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          escalationWindowMinutes: 60,
        );
        await doses.saveDose(dose);
        expect(
          resolve(dose, now).state,
          DoseState.overdue,
          reason: 'the fixture should be Overdue before it is taken',
        );

        await recorder.take(dose);

        final Dose saved = (await doses.findDose(dose.id))!;
        expect(saved.takenAt, sameMoment(now));
        expect(
          resolve(saved, now),
          DoseResolution(DoseState.taken, loggedLate: true),
        );
        expect(notifier.cancelled, equals([dose.id]));
      },
    );

    test(
      'a Missed Dose 10 days old, within the 14-day edge: recorded as Taken',
      () async {
        final DateTime scheduledLocal = now.subtract(const Duration(days: 10));
        final Dose dose = buildDose(scheduledLocal: scheduledLocal);
        await doses.saveDose(dose);
        expect(resolve(dose, now).state, DoseState.missed);

        await recorder.take(dose);

        final Dose saved = (await doses.findDose(dose.id))!;
        expect(
          resolve(saved, now),
          DoseResolution(DoseState.taken, loggedLate: true),
        );
        expect(notifier.cancelled, equals([dose.id]));
      },
    );

    test('a Missed Dose 20 days old, past the 14-day edge: refused, nothing '
        'written', () async {
      final DateTime scheduledLocal = now.subtract(const Duration(days: 20));
      final Dose dose = buildDose(scheduledLocal: scheduledLocal);
      await doses.saveDose(dose);
      expect(dose.isResolvable(now), isFalse);

      await expectLater(
        recorder.take(dose),
        throwsA(isA<DoseNotResolvableFailure>()),
      );

      final Dose unchanged = (await doses.findDose(dose.id))!;
      expect(unchanged.takenAt, isNull);
      expect(notifier.cancelled, isEmpty);
    });

    test('a future Dose: refused, nothing written', () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2026, 9, 10, 8, 0));
      await doses.saveDose(dose);

      await expectLater(
        recorder.take(dose),
        throwsA(isA<DoseNotYetDueFailure>()),
      );

      final Dose unchanged = (await doses.findDose(dose.id))!;
      expect(unchanged.takenAt, isNull);
      expect(notifier.cancelled, isEmpty);
    });

    test('called twice in immediate succession: the second call no-ops, '
        'cancels once, and never corrupts snoozeCount', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        snoozeCount: 2,
      );
      await doses.saveDose(dose);

      await recorder.take(dose);
      // The same, now-stale `dose` reference again -- exactly the shape a
      // rapid double-tap takes when the UI has not yet rebuilt with the
      // first call's result.
      await recorder.take(dose);

      expect(
        notifier.cancelled,
        equals([dose.id]),
        reason: 'the second call must not cancel again',
      );
      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.takenAt, sameMoment(now));
      expect(saved.snoozeCount, 2);
    });
  });

  group('skip', () {
    test('a Due Dose: skippedAt = now, resolves Skipped', () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2026, 9, 9, 10, 0));
      await doses.saveDose(dose);

      await recorder.skip(dose);

      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.skippedAt, sameMoment(now));
      expect(resolve(saved, now), DoseResolution(DoseState.skipped));
      expect(notifier.cancelled, equals([dose.id]));
    });

    test('an Overdue Dose: skippedAt = now, resolves Skipped -- permanently '
        'distinct from Missed', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 8, 0),
        escalationWindowMinutes: 60,
      );
      await doses.saveDose(dose);
      expect(resolve(dose, now).state, DoseState.overdue);

      await recorder.skip(dose);

      final Dose saved = (await doses.findDose(dose.id))!;
      expect(resolve(saved, now), DoseResolution(DoseState.skipped));
      expect(notifier.cancelled, equals([dose.id]));
    });
  });

  group('snooze', () {
    test('ordinary case: snoozedUntil = now + 15min, snoozeCount + 1, '
        'scheduledAt unchanged, resolves Snoozed', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        escalationWindowMinutes: 120,
      );
      await doses.saveDose(dose);

      await recorder.snooze(dose);

      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.snoozedUntil, sameMoment(now.add(defaultSnoozeInterval)));
      expect(saved.snoozeCount, 1);
      expect(saved.scheduledAt, sameMoment(dose.scheduledAt));
      expect(resolve(saved, now), DoseResolution(DoseState.snoozed));
      expect(notifier.cancelled, equals([dose.id]));
    });

    test('repeated: snoozeCount increments again, no cap (FR-8)', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        escalationWindowMinutes: 120,
        snoozeCount: 1,
        // An earlier snooze that has already lapsed by "now".
        snoozedUntil: DateTime(2026, 9, 9, 10, 20),
      );
      await doses.saveDose(dose);

      await recorder.snooze(dose);

      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.snoozeCount, 2);
      expect(saved.snoozedUntil, sameMoment(now.add(defaultSnoozeInterval)));
    });

    test('would cross into Overdue: now + 15min >= scheduledAt + window is '
        'refused, Dose keeps resolving as it already was', () async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        escalationWindowMinutes: 45,
      );
      await doses.saveDose(dose);
      expect(
        resolve(dose, now).state,
        DoseState.due,
        reason: 'the fixture should still be Due before the failed snooze',
      );
      // The exact boundary: scheduledAt (10:00) + window (45min) = 10:45,
      // and now (10:30) + defaultSnoozeInterval (15min) = 10:45 too -- "at
      // or past", not merely "past".
      expect(
        now.add(defaultSnoozeInterval),
        sameMoment(dose.scheduledAt.add(dose.window)),
      );

      await expectLater(
        recorder.snooze(dose),
        throwsA(isA<SnoozeWindowExceededFailure>()),
      );

      final Dose unchanged = (await doses.findDose(dose.id))!;
      expect(unchanged.snoozedUntil, isNull);
      expect(unchanged.snoozeCount, 0);
      expect(resolve(unchanged, now).state, DoseState.due);
      expect(notifier.cancelled, isEmpty);
    });

    test(
      'already Overdue: refused unconditionally, Overdue stands unchanged',
      () async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          escalationWindowMinutes: 60,
        );
        await doses.saveDose(dose);
        expect(resolve(dose, now).state, DoseState.overdue);

        await expectLater(
          recorder.snooze(dose),
          throwsA(isA<SnoozeWindowExceededFailure>()),
        );

        final Dose unchanged = (await doses.findDose(dose.id))!;
        expect(resolve(unchanged, now).state, DoseState.overdue);
        expect(notifier.cancelled, isEmpty);
      },
    );
  });

  group('the write/notify unit of work', () {
    test(
      'a repository failure surfaces and the notifier is never called',
      () async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        );
        final _SaveFailingDoses failing = _SaveFailingDoses(doses);
        final DoseRecorder failingRecorder = DoseRecorder(
          FixedClock(),
          failing,
          notifier,
        );
        await doses.saveDose(dose);
        failing.failureToThrow = StateError('write failed');

        await expectLater(
          failingRecorder.take(dose),
          throwsA(isA<StateError>()),
        );

        final Dose unchanged = (await doses.findDose(dose.id))!;
        expect(unchanged.takenAt, isNull);
        expect(notifier.cancelled, isEmpty);
      },
    );

    test('a notifier failure also fails the whole action -- no partial success '
        'is reported, even though the write already landed', () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2026, 9, 9, 10, 0));
      await doses.saveDose(dose);
      final FakeDoseNotifier failingNotifier = FakeDoseNotifier(
        failure: StateError('cancel failed'),
      );
      final DoseRecorder recorderWithFailingNotifier = DoseRecorder(
        FixedClock(),
        doses,
        failingNotifier,
      );

      await expectLater(
        recorderWithFailingNotifier.take(dose),
        throwsA(isA<StateError>()),
        reason:
            'the caller must never see this as a success (PRD §9), even '
            'though the write below did complete',
      );

      expect(failingNotifier.cancelled, equals([dose.id]));
      final Dose saved = (await doses.findDose(dose.id))!;
      expect(saved.takenAt, sameMoment(now));
    });
  });
}

/// Delegates every [DoseRepository] method to [_inner] except [saveDose],
/// which throws [failureToThrow] once set -- the spec's "Write fails" row,
/// without a whole hand-rolled in-memory store. Mirrors
/// `add_medicine_flow_test.dart`'s `_RejectingSchedules`.
final class _SaveFailingDoses implements DoseRepository {
  _SaveFailingDoses(this._inner);

  final DoseRepository _inner;

  /// Thrown by [saveDose] once set, instead of delegating.
  Object? failureToThrow;

  @override
  Future<void> saveDose(Dose dose) async {
    final Object? failure = failureToThrow;
    if (failure != null) throw failure;
    return _inner.saveDose(dose);
  }

  @override
  Future<List<Dose>> dosesForSchedule(String scheduleId) =>
      _inner.dosesForSchedule(scheduleId);

  @override
  Future<Dose?> findDose(String id) => _inner.findDose(id);

  @override
  Future<void> deleteDose(String id) => _inner.deleteDose(id);

  @override
  Future<List<Dose>> dosesScheduledBetween(DateTime start, DateTime end) =>
      _inner.dosesScheduledBetween(start, end);
}
