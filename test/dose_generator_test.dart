// `DoseGenerator` against real `DriftMedicineRepository`/`DriftDoseRepository`
// over an in-memory database -- the matrix rows `schedule_occurrence_test.dart`
// does not already cover as pure date math, plus this spec's acceptance
// criteria.
//
// Testing depth is LIGHTER (project-context.md), with the exception this spec
// itself names: generation writes rows, so the idempotency row ("rerun, no
// state change") and the cleanup row get a mutation-testing spot-check via
// `RecordingInterceptor`, watching for deletes exactly as
// `dose_repository_test.dart` watches `deleteMedicine`'s transaction.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/domain/service/dose_generator.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/recording_interceptor.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase database;
  late RecordingInterceptor recorder;
  late DoseRepository doses;
  late MedicineRepository medicines;
  late DoseGenerator generator;
  late int nextId;

  setUp(() {
    recorder = RecordingInterceptor();
    database = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
    doses = DriftDoseRepository(database);
    nextId = 0;
    medicines = DriftMedicineRepository(
      database,
      newId: () => 'id-${++nextId}',
    );
    generator = DoseGenerator(medicines, doses);
  });

  tearDown(() async {
    await database.close();
  });

  // A Wednesday, mid-morning -- FixedClock's own reference instant, reused
  // here so the calendar-day reasoning in each test's comment matches.
  final DateTime now = DateTime(2026, 9, 9, 10, 30);
  final DateTime startDate = DateTime(2026, 9, 7);

  Future<Medicine> addMedicine({
    String name = 'Metformin',
    double dosageAmount = 1,
    DateTime? start,
    DateTime? endDate,
    bool active = true,
  }) => medicines.addMedicine(
    name: name,
    form: 'tablet',
    dosageAmount: dosageAmount,
    dosageUnit: 'tablet',
    startDate: start ?? startDate,
    endDate: endDate,
    active: active,
  );

  Future<Schedule> addSchedule({
    required String medicineId,
    String timeOfDay = '08:00',
    Frequency frequency = Frequency.everyDay,
    Set<int>? daysOfWeek,
    int? intervalDays,
    double dosageAmount = 1,
    String? reminderOverride,
  }) => medicines.addSchedule(
    medicineId: medicineId,
    timeOfDay: timeOfDay,
    ianaTimezone: 'Asia/Colombo',
    frequency: frequency,
    daysOfWeek: daysOfWeek,
    intervalDays: intervalDays,
    dosageAmount: dosageAmount,
    reminderOverride: reminderOverride,
  );

  /// [original] with [takenAt] set -- standing in for `DoseRecorder`, which
  /// does not exist until Epic 2 (AD-4). Directly through the port, matching
  /// how `dose_repository_test.dart` builds an acted-on Dose.
  Dose actedOn(Dose original, {required DateTime takenAt}) => Dose(
    scheduleId: original.scheduleId,
    medicineId: original.medicineId,
    scheduledLocal: original.scheduledLocal,
    ianaTimezone: original.ianaTimezone,
    takenAt: takenAt,
    snoozeCount: original.snoozeCount,
    escalationWindowMinutes: original.escalationWindowMinutes,
    followUpOffsetsMinutes: original.followUpOffsetsMinutes,
    medicineName: original.medicineName,
    dosageAmount: original.dosageAmount,
    dosageUnit: original.dosageUnit,
    form: original.form,
  );

  group('inactive Medicine (the spec\'s "Inactive Medicine" row)', () {
    test('no Doses are generated for it, while an active sibling still gets '
        'its full horizon', () async {
      final Medicine inactive = await addMedicine(
        name: 'Paused',
        active: false,
      );
      final Schedule pausedSchedule = await addSchedule(
        medicineId: inactive.id,
      );
      final Medicine active = await addMedicine(name: 'Active');
      final Schedule activeSchedule = await addSchedule(medicineId: active.id);

      await generator.generate(now);

      expect(await doses.dosesForSchedule(pausedSchedule.id), isEmpty);
      expect(await doses.dosesForSchedule(activeSchedule.id), hasLength(14));
    });
  });

  group(
    'rerun with no state change (the spec\'s "Rerun, unchanged" row, AC2)',
    () {
      test('the second run writes nothing new: same row count, same ids, '
          'identical rows, and nothing deleted', () async {
        final Medicine medicine = await addMedicine();
        final Schedule schedule = await addSchedule(medicineId: medicine.id);

        await generator.generate(now);
        final List<Dose> first = await doses.dosesForSchedule(schedule.id);

        recorder.clear();
        await generator.generate(now);
        final List<Dose> second = await doses.dosesForSchedule(schedule.id);

        expect(second, hasLength(first.length));
        expect(second, unorderedEquals(first));
        expect(
          recorder.deletes,
          isEmpty,
          reason: 'AD-10: a plain sweep is additive and never deletes',
        );
      });
    },
  );

  group('rerun after a dose is acted on (the spec\'s "Rerun, dose acted on" '
      'row)', () {
    test('regeneration leaves the acted-on Dose untouched, and still '
        'refreshes the rest', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await addSchedule(medicineId: medicine.id);

      await generator.generate(now);
      final Dose today = (await doses.findDose(
        '${schedule.id}:${DateTime(2026, 9, 9, 8, 0).toIso8601String()}',
      ))!;
      final Dose recorded = actedOn(
        today,
        // UTC, not local: `Dose.==` compares `DateTime`s including their
        // UTC/local flavour, and a value read back from the database is
        // always UTC-flavoured (`DriftDoseRepository._doseFromRow`) --
        // matching `dose_repository_test.dart`'s own `DateTime.utc(...)` for
        // exactly this reason.
        takenAt: DateTime.utc(2026, 9, 9, 8, 5),
      );
      await doses.saveDose(recorded);

      await generator.generate(now);

      final Dose? afterRerun = await doses.findDose(today.id);
      expect(afterRerun, equals(recorded));

      final Dose? tomorrow = await doses.findDose(
        '${schedule.id}:${DateTime(2026, 9, 10, 8, 0).toIso8601String()}',
      );
      expect(tomorrow, isNotNull);
      expect(tomorrow!.takenAt, isNull);
    });
  });

  group('catch-up after days closed (the spec\'s "Catch-up after days '
      'closed" row)', () {
    test('a run 4 days after the last leaves no gap between them', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await addSchedule(medicineId: medicine.id);

      await generator.generate(now);
      await generator.generate(now.add(const Duration(days: 4)));

      final List<DateTime> scheduledDates = (await doses.dosesForSchedule(
        schedule.id,
      )).map((Dose d) => d.scheduledLocal).toList()..sort();

      // 18 consecutive days: the first run's 14 (day0..13) plus the second
      // run's horizon extending to day17, with every day in between present.
      expect(scheduledDates, hasLength(18));
      for (int i = 0; i < scheduledDates.length; i++) {
        expect(
          scheduledDates[i],
          DateTime(2026, 9, 9, 8, 0).add(Duration(days: i)),
          reason:
              'day $i must not be missing -- no gap across the 4-day '
              'idle period',
        );
      }
    });
  });

  group('cleanup on Schedule change (the spec\'s "Cleanup on Schedule '
      'change" row)', () {
    test(
      'stale future un-acted rows under the old time are deleted and '
      'replaced; an already-acted row under the old key is never touched',
      () async {
        final Medicine medicine = await addMedicine();
        final Schedule schedule = await addSchedule(medicineId: medicine.id);

        await generator.generate(now);
        // now (10:30) is after today's 08:00, so today's dose stands in for
        // an already-acted, already-past row that must survive untouched.
        final Dose todayDose = (await doses.findDose(
          '${schedule.id}:${DateTime(2026, 9, 9, 8, 0).toIso8601String()}',
        ))!;
        final Dose recordedToday = actedOn(
          todayDose,
          // UTC, not local -- see the identical note in the "rerun after a
          // dose is acted on" test above.
          takenAt: DateTime.utc(2026, 9, 9, 8, 10),
        );
        await doses.saveDose(recordedToday);

        final Schedule updated = schedule.copyWith(timeOfDay: '09:00');
        await medicines.saveSchedule(updated);

        recorder.clear();
        await generator.regenerateAfterScheduleChange(updated, now);

        final List<Dose> after = await doses.dosesForSchedule(schedule.id);

        expect(
          await doses.findDose(recordedToday.id),
          equals(recordedToday),
          reason: 'an already-acted Dose under the old key is never touched',
        );
        expect(
          after.where((Dose d) => d.scheduledLocal.hour == 8),
          hasLength(1),
          reason: 'the only surviving 08:00 row is the acted-on, past one',
        );
        expect(
          after.where((Dose d) => d.scheduledLocal.hour == 9),
          hasLength(14),
          reason: 'generation replaced the stale future rows at the new time',
        );
        expect(
          recorder.deletes,
          hasLength(13),
          reason:
              'exactly the 13 future, un-acted 08:00 rows (tomorrow '
              'through day 13) were the stale ones',
        );
      },
    );

    test('pausing a Medicine deletes its future un-acted Doses but does not '
        'regenerate them: pausing IS a cleanup trigger, not an exemption '
        'from one (AD-10 names "active state" alongside time and '
        'Frequency)', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await addSchedule(medicineId: medicine.id);
      await generator.generate(now);
      final int before = (await doses.dosesForSchedule(schedule.id)).length;
      expect(before, 14, reason: 'the full horizon, before pausing');

      await medicines.saveMedicine(medicine.copyWith(active: false));

      recorder.clear();
      await generator.regenerateAfterScheduleChange(schedule, now);

      final List<Dose> remaining = await doses.dosesForSchedule(schedule.id);
      expect(
        remaining,
        hasLength(1),
        reason:
            'today\'s 08:00 dose is already before `now` (10:30), so it is '
            'not a FUTURE dose -- AD-10 scopes cleanup to future, un-acted '
            'Doses only, and this one is neither deleted by this method nor '
            'anyone\'s to touch here',
      );
      expect(
        remaining.single.scheduledLocal,
        DateTime(2026, 9, 9, 8),
        reason: 'the one dose left is today\'s, not a future one',
      );
      expect(
        recorder.deletes,
        hasLength(13),
        reason:
            'the other 13 were future and un-acted -- stale the moment the '
            'Medicine was paused. Leaving them would strand them on Home '
            'exactly as AD-10 names for a time change, applied here to '
            'pausing instead',
      );
    });

    test('an already-acted-on Dose survives a Medicine being paused', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await addSchedule(medicineId: medicine.id);
      await generator.generate(now);
      final List<Dose> generated = await doses.dosesForSchedule(schedule.id);
      generated.sort(
        (Dose a, Dose b) => a.scheduledAt.compareTo(b.scheduledAt),
      );
      // The furthest-future one: safely later than [now] regardless of the
      // horizon's exact start, so it is unambiguously a candidate the delete
      // loop would otherwise remove.
      final Dose future = generated.last;
      await doses.saveDose(actedOn(future, takenAt: now));

      await medicines.saveMedicine(medicine.copyWith(active: false));
      await generator.regenerateAfterScheduleChange(schedule, now);

      final Dose? survivor = await doses.findDose(future.id);
      expect(
        survivor,
        isNotNull,
        reason: 'a recorded action is never undone by pausing',
      );
      expect(survivor!.takenAt, isNotNull);
    });
  });

  group('escalation window, twice daily (the spec\'s "Escalation window, twice '
      'daily" row and this spec\'s AC1)', () {
    test('two Schedules 12h apart -> every Dose escalates in 180 minutes '
        '(3h)', () async {
      final Medicine medicine = await addMedicine();
      final Schedule morning = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
      );
      final Schedule evening = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '20:00',
      );

      await generator.generate(now);

      final List<Dose> all = <Dose>[
        ...await doses.dosesForSchedule(morning.id),
        ...await doses.dosesForSchedule(evening.id),
      ];
      expect(all, hasLength(28));
      expect(all.every((Dose d) => d.escalationWindowMinutes == 180), isTrue);
    });
  });

  group('escalation window, last dose of the day (the spec\'s own row)', () {
    test('measured to the Medicine\'s first occurrence on its next covered '
        'day, including for the horizon\'s own last day (beyond it, '
        'unpersisted)', () async {
      final Medicine medicine = await addMedicine();
      final Schedule morning = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
      );
      final Schedule later = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '09:00',
      );

      await generator.generate(now);

      // 09:00 today to 08:00 tomorrow is 23h -> 345 minutes, never the
      // 6h ceiling -- this only comes out right for the horizon's last
      // (day 13) occurrence if the beyond-horizon lookahead supplied
      // day 14's 08:00 as a candidate.
      final List<Dose> laterDoses = await doses.dosesForSchedule(later.id);
      expect(laterDoses, hasLength(14));
      expect(
        laterDoses.every((Dose d) => d.escalationWindowMinutes == 345),
        isTrue,
      );

      // Sanity: the 08:00 doses measure to the SAME day's 09:00, 1h
      // away, clamped to the 1h floor -- a different number, so the
      // two schedules are not being conflated.
      final List<Dose> morningDoses = await doses.dosesForSchedule(morning.id);
      expect(
        morningDoses.every((Dose d) => d.escalationWindowMinutes == 60),
        isTrue,
      );
    });
  });

  group('escalation window, Medicine ends (the spec\'s own row)', () {
    test('the genuinely last-ever occurrence gets the 6h ceiling, and no '
        'other occurrence does', () async {
      final DateTime endDate = now.add(const Duration(days: 5)); // Sep 14.
      final Medicine medicine = await addMedicine(endDate: endDate);
      final Schedule morning = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
      );
      final Schedule later = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '09:00',
      );

      await generator.generate(now);

      final List<Dose> laterDoses = await doses.dosesForSchedule(later.id);
      // endDate clips the horizon to Sep 9..14 -- 6 occurrences, not 14.
      expect(laterDoses, hasLength(6));
      final Dose lastOverall = laterDoses.reduce(
        (Dose a, Dose b) => a.scheduledAt.isAfter(b.scheduledAt) ? a : b,
      );
      expect(lastOverall.scheduledLocal, DateTime(2026, 9, 14, 9, 0));
      expect(
        lastOverall.escalationWindowMinutes,
        const Duration(hours: 6).inMinutes,
        reason:
            'no later Dose of this Medicine exists, in-horizon or '
            'beyond it -- there is nothing left to escalate faster for',
      );

      final Dose sameDayMorning = (await doses.dosesForSchedule(morning.id))
          .firstWhere(
            (Dose d) => d.scheduledLocal == DateTime(2026, 9, 14, 8, 0),
          );
      expect(
        sameDayMorning.escalationWindowMinutes,
        isNot(const Duration(hours: 6).inMinutes),
        reason:
            'this one still has a later dose the same day (09:00), so '
            'only the true last occurrence gets the ceiling',
      );
    });
  });

  group('snapshot freeze (the spec\'s own row, AD-11)', () {
    test('medicineName/dosageUnit/form come from the Medicine, dosageAmount '
        'from the Schedule', () async {
      final Medicine medicine = await addMedicine(
        name: 'Metformin',
        dosageAmount: 1,
      );
      final Schedule schedule = await addSchedule(
        medicineId: medicine.id,
        dosageAmount: 2,
      );

      await generator.generate(now);

      final List<Dose> all = await doses.dosesForSchedule(schedule.id);
      expect(all, isNotEmpty);
      expect(
        all.every(
          (Dose d) =>
              d.medicineName == 'Metformin' &&
              d.dosageAmount == 2 &&
              d.dosageUnit == 'tablet' &&
              d.form == 'tablet',
        ),
        isTrue,
      );
    });
  });

  group('AD-16 rung 1: a Schedule\'s own reminderOverride (spec-1-7b\'s Never '
      'boundary, "implement the first and third rungs")', () {
    test('generation freezes the override onto every Dose, bypassing the '
        'formula entirely', () async {
      final Medicine medicine = await addMedicine();
      // Two Schedules 12h apart would otherwise formula-compute to 3h
      // (180 min) -- proving the override, not a coincidental formula
      // result, is what ends up on the Dose.
      final Schedule overridden = await addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        reminderOverride: 'PT10M',
      );
      await addSchedule(medicineId: medicine.id, timeOfDay: '20:00');

      await generator.generate(now);

      final List<Dose> all = await doses.dosesForSchedule(overridden.id);
      expect(all, hasLength(14));
      expect(all.every((Dose d) => d.escalationWindowMinutes == 10), isTrue);
    });
  });
}
