// `DriftDoseRepository` against a real SQLite database -- one test per row of
// this spec's I/O matrix, following `test/medicine_repository_test.dart`'s
// shape.
//
// Testing depth is LIGHTER (project-context.md), with the one exception this
// spec itself names: this story touches persistence and a migration, so the
// save/delete paths carry a small mutation-testing pass -- specifically the
// cascade delete ("deleting a Medicine takes its Doses with it too" below) and
// the upsert-not-insert behaviour ("save the same Dose again"), watched
// through `RecordingInterceptor` exactly as `medicine_repository_test.dart`
// watches `deleteMedicine`'s own transaction.
//
// In-memory (AD-19): no test here needs a real file, unlike
// `medicine_repository_test.dart`'s "survives a real restart" group, which
// already proves a Drift connection over this same `AppDatabase` persists.

// `hide`: drift exports `isNull`/`isNotNull` as SQL expression builders, and
// matcher exports them as matchers. Only the matchers are wanted here.
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
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/recording_interceptor.dart';

void main() {
  // Every `Dose` construction resolves its zone through `package:timezone`
  // (`Dose._asInstant`), which throws until the database is loaded. Per the
  // house rule `test/dose_resolver_test.dart` follows: only the composition
  // root and test `setUp`/`setUpAll` call this, never domain code.
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase database;
  late RecordingInterceptor recorder;
  late DoseRepository doses;
  late MedicineRepository medicines;
  late int nextId;

  setUp(() {
    recorder = RecordingInterceptor();
    database = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
    doses = DriftDoseRepository(database);
    nextId = 0;
    // Deterministic ids for the Medicine/Schedule a Dose has to reference
    // (AD-12: by id only). `Dose.id` itself is never minted here -- Story 1.6
    // already made it deterministic from scheduleId + scheduledLocal.
    medicines = DriftMedicineRepository(
      database,
      newId: () => 'id-${++nextId}',
    );
  });

  tearDown(() async {
    await database.close();
  });

  // A Medicine and one Schedule for Doses to reference. Real rows, not
  // fabricated ids: `doses.schedule_id`/`doses.medicine_id` are enforced
  // foreign keys, so a Dose in these tests always names a row that exists.
  Future<Schedule> seedSchedule() async {
    final Medicine medicine = await medicines.addMedicine(
      name: 'Metformin',
      form: 'tablet',
      dosageAmount: 1,
      dosageUnit: 'tablet',
      startDate: DateTime(2026, 9, 7),
    );
    return medicines.addSchedule(
      medicineId: medicine.id,
      timeOfDay: '08:00',
      ianaTimezone: 'Asia/Colombo',
      frequency: Frequency.everyDay,
      dosageAmount: 1,
    );
  }

  Dose doseFor(
    Schedule schedule, {
    DateTime? scheduledLocal,
    DateTime? takenAt,
    DateTime? skippedAt,
    DateTime? snoozedUntil,
    int snoozeCount = 0,
    String medicineName = 'Metformin',
    double dosageAmount = 1,
    String dosageUnit = 'tablet',
    String form = 'tablet',
    int escalationWindowMinutes = 60,
  }) => Dose(
    scheduleId: schedule.id,
    medicineId: schedule.medicineId,
    scheduledLocal: scheduledLocal ?? DateTime(2026, 9, 9, 8, 0),
    ianaTimezone: schedule.ianaTimezone,
    takenAt: takenAt,
    skippedAt: skippedAt,
    snoozedUntil: snoozedUntil,
    snoozeCount: snoozeCount,
    escalationWindowMinutes: escalationWindowMinutes,
    medicineName: medicineName,
    dosageAmount: dosageAmount,
    dosageUnit: dosageUnit,
    form: form,
  );

  group('the port is the only write path (AD-12)', () {
    test('the adapter implements the domain port and nothing wider', () {
      expect(doses, isA<DoseRepository>());
      expect(doses, isA<DriftDoseRepository>());
    });
  });

  group('save a new Dose (the spec\'s "Save a new Dose" row)', () {
    test('one row exists, readable back with every field equal', () async {
      final Schedule schedule = await seedSchedule();
      final Dose saved = doseFor(schedule);

      await doses.saveDose(saved);

      expect(await doses.dosesForSchedule(schedule.id), hasLength(1));
      expect(await doses.findDose(saved.id), equals(saved));
    });
  });

  group(
    'save the same Dose again (the spec\'s "Save the same Dose again" row)',
    () {
      test('still one row -- an upsert, not an insert', () async {
        final Schedule schedule = await seedSchedule();
        await doses.saveDose(doseFor(schedule));

        // Same id (same scheduleId + scheduledLocal), changed facts -- proving
        // this really re-wrote the row rather than either throwing on a
        // second insert or silently skipping a write that already exists.
        final Dose updated = doseFor(
          schedule,
          snoozeCount: 1,
          snoozedUntil: DateTime.utc(2026, 9, 9, 3, 0),
        );
        await doses.saveDose(updated);

        expect(await doses.dosesForSchedule(schedule.id), hasLength(1));
        expect(await doses.findDose(updated.id), equals(updated));
      });
    },
  );

  group('duplicate natural key (the spec\'s "Duplicate natural key" row)', () {
    test('a row already on this natural key under a different id is refused, '
        'nothing written', () async {
      final Schedule schedule = await seedSchedule();
      final Dose candidate = doseFor(schedule);

      // Dose.id is always derived from (scheduleId, scheduledLocal), so
      // two Dose OBJECTS sharing a natural key always compute the same
      // id -- that path is the upsert row above, not this one. The only
      // way to observe two different ids on one natural key is a row that
      // did not go through Dose's own derivation; planted directly here to
      // simulate exactly that, matching the spec's "a different in-memory
      // identity" wording.
      await database.customStatement(
        'INSERT INTO doses (id, schedule_id, medicine_id, '
        'scheduled_local, iana_timezone, scheduled_utc, medicine_name, '
        'dosage_amount, dosage_unit, form, escalation_window_minutes, '
        'follow_up_offsets_minutes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?)',
        <Object?>[
          'a-different-identity',
          schedule.id,
          schedule.medicineId,
          candidate.scheduledLocal.toIso8601String(),
          schedule.ianaTimezone,
          candidate.scheduledAt.toUtc().toIso8601String(),
          'Metformin',
          1.0,
          'tablet',
          'tablet',
          60,
          '15,30,60',
        ],
      );

      await expectLater(
        doses.saveDose(candidate),
        throwsA(
          isA<DuplicateDoseFailure>()
              .having(
                (DuplicateDoseFailure e) => e.scheduleId,
                'scheduleId',
                schedule.id,
              )
              .having(
                (DuplicateDoseFailure e) => e.message,
                'message',
                isNotEmpty,
              ),
        ),
        reason: 'the unique index is the truth, not the id string',
      );

      expect(
        await doses.dosesForSchedule(schedule.id),
        hasLength(1),
        reason: 'the rejected save wrote nothing',
      );

      // The raw stored `id` column, not `Dose.id` -- reconstructing through
      // the port would recompute the id from (scheduleId, scheduledLocal) and
      // report the candidate's own id even for the untouched planted row, so
      // only a read below the domain model can show which physical row this
      // still is.
      final List<QueryRow> rows = await database
          .customSelect('SELECT id FROM doses')
          .get();
      expect(
        rows.single.read<String>('id'),
        'a-different-identity',
        reason:
            'the row the rejected save must not have touched is still '
            'the one planted above',
      );
    });
  });

  group('read by schedule (the spec\'s "Read by schedule" rows)', () {
    test('a Schedule with three saved Doses returns all three', () async {
      final Schedule schedule = await seedSchedule();
      for (final DateTime day in <DateTime>[
        DateTime(2026, 9, 9, 8, 0),
        DateTime(2026, 9, 10, 8, 0),
        DateTime(2026, 9, 11, 8, 0),
      ]) {
        await doses.saveDose(doseFor(schedule, scheduledLocal: day));
      }

      expect(await doses.dosesForSchedule(schedule.id), hasLength(3));
    });

    test('a Schedule with no Doses reads as an empty list', () async {
      final Schedule schedule = await seedSchedule();
      expect(await doses.dosesForSchedule(schedule.id), isEmpty);
    });
  });

  group('find by id (the spec\'s "Find by id" rows)', () {
    test('present -> that Dose', () async {
      final Schedule schedule = await seedSchedule();
      final Dose saved = doseFor(schedule);
      await doses.saveDose(saved);

      expect(await doses.findDose(saved.id), equals(saved));
    });

    test('absent -> null', () async {
      expect(await doses.findDose('nope'), isNull);
    });
  });

  group('delete one Dose (the spec\'s "Delete one Dose" row)', () {
    test('the row is gone, and a second delete is a no-op', () async {
      final Schedule schedule = await seedSchedule();
      final Dose saved = doseFor(schedule);
      await doses.saveDose(saved);

      await doses.deleteDose(saved.id);
      expect(await doses.findDose(saved.id), isNull);

      await doses.deleteDose(saved.id);
      expect(await doses.dosesForSchedule(schedule.id), isEmpty);
    });
  });

  group('deleting a Medicine takes its Doses with it too '
      '(the spec\'s "Delete a Medicine" row, AD-12)', () {
    test(
      'the Medicine, its Schedule and its Dose all go, in ONE transaction',
      () async {
        final Schedule schedule = await seedSchedule();
        final Dose saved = doseFor(schedule);
        await doses.saveDose(saved);

        recorder.clear();
        await medicines.deleteMedicine(schedule.medicineId);
        // Snapshotted before the reads below, for the same reason
        // `medicine_repository_test.dart` snapshots it: those reads would
        // otherwise append their own SELECTs and make `issued.last` one of
        // them rather than the COMMIT.
        final List<String> issued = List<String>.of(recorder.log);

        expect(await doses.findDose(saved.id), isNull);
        expect(await medicines.findMedicine(schedule.medicineId), isNull);
        expect(await medicines.schedulesFor(schedule.medicineId), isEmpty);

        expect(
          issued,
          equals(<String>[
            'begin',
            'delete: DELETE FROM "doses" WHERE "medicine_id" = ?;',
            'delete: DELETE FROM "schedules" WHERE "medicine_id" = ?;',
            'delete: DELETE FROM "medicines" WHERE "id" = ?;',
            'commit',
          ]),
          reason:
              'All three deletes between one BEGIN and one COMMIT: a '
              'failure part-way must leave none of the three removed -- '
              'never a Medicine or Schedule stripped of Doses that still '
              'reference it, and never a Dose outliving either.',
        );
      },
    );

    test('another Medicine\'s Doses are left alone', () async {
      final Schedule doomedSchedule = await seedSchedule();
      await doses.saveDose(doseFor(doomedSchedule));

      final Medicine kept = await medicines.addMedicine(
        name: 'Kept',
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 7),
      );
      final Schedule keptSchedule = await medicines.addSchedule(
        medicineId: kept.id,
        timeOfDay: '20:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      await doses.saveDose(doseFor(keptSchedule));

      await medicines.deleteMedicine(doomedSchedule.medicineId);

      expect(await doses.dosesForSchedule(keptSchedule.id), hasLength(1));
      expect(await medicines.findMedicine(kept.id), isNotNull);
    });

    test('deleting an id that is not stored is not an error', () async {
      await medicines.deleteMedicine('no-such-medicine');
      expect(await medicines.allMedicines(), isEmpty);
    });
  });

  group('round-trip the snapshot (the spec\'s "Round-trip the snapshot" row, '
      'AD-11)', () {
    test('all four frozen fields read back unchanged, independent of the live '
        'Medicine', () async {
      final Schedule schedule = await seedSchedule();
      final Dose saved = doseFor(
        schedule,
        medicineName: 'Metformin',
        dosageAmount: 2.5,
        dosageUnit: 'ml',
        form: 'liquid',
      );
      await doses.saveDose(saved);

      // The live Medicine changes after the Dose was saved; the frozen
      // snapshot must not follow it (AD-11) -- `DriftDoseRepository`
      // never joins back to `medicines` to answer `findDose`.
      final Medicine? medicine = await medicines.findMedicine(
        schedule.medicineId,
      );
      await medicines.saveMedicine(
        medicine!.copyWith(name: 'Renamed', dosageAmount: 99, dosageUnit: 'mg'),
      );

      final Dose? read = await doses.findDose(saved.id);
      expect(read, isNotNull);
      expect(read!.medicineName, 'Metformin');
      expect(read.dosageAmount, 2.5);
      expect(read.dosageUnit, 'ml');
      expect(read.form, 'liquid');
    });
  });
}
