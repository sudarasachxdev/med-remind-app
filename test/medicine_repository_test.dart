// `DriftMedicineRepository` against a real SQLite database — every row of the
// spec's I/O matrix that involves a write.
//
// In-memory (AD-19) except where a real file is the point. The distinction
// matters more than it looks: `AppDatabase.close()` followed by a query does
// NOT throw -- drift's delegate quietly opens a fresh, empty in-memory
// database -- so a close-and-reopen test on an in-memory executor reads a
// blank database as a valid fresh install and passes while proving the
// opposite of what it claims. The "survives a restart" group below therefore
// uses a file in a temp directory, closes the first connection, and opens a
// second one on the same path.

import 'dart:io';

// `hide`: drift exports `isNull`/`isNotNull` as SQL expression builders, and
// matcher exports them as matchers. Only the matchers are wanted here.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/domain_failure.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';

import 'support/recording_interceptor.dart';

void main() {
  late AppDatabase database;
  late RecordingInterceptor recorder;
  late MedicineRepository repository;
  late int nextId;

  setUp(() {
    recorder = RecordingInterceptor();
    database = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
    nextId = 0;
    // Deterministic ids. A UUID v4 would make every assertion below match a
    // random string, and the ids are what the failure messages name.
    repository = DriftMedicineRepository(
      database,
      newId: () => 'id-${++nextId}',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<Medicine> addMedicine({String name = 'Metformin'}) =>
      repository.addMedicine(
        name: name,
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 7),
      );

  group('the port is the only write path (AD-12)', () {
    test('the adapter implements the domain port and nothing wider', () {
      expect(repository, isA<MedicineRepository>());
      expect(repository, isA<DriftMedicineRepository>());
    });
  });

  group('glyphIndex (AD-22)', () {
    test('the first medicine gets 0', () async {
      final Medicine first = await addMedicine();

      expect(first.glyphIndex, 0);
      expect(first.id, 'id-1', reason: 'the repository mints the identity');
    });

    test('five in sequence get 0, 1, 2, 3, 0', () async {
      final List<int> glyphs = <int>[];
      for (int i = 1; i <= 5; i++) {
        glyphs.add((await addMedicine(name: 'Medicine $i')).glyphIndex);
      }

      expect(glyphs, equals(<int>[0, 1, 2, 3, 0]));
    });

    test('the index is persisted, not derived on read', () async {
      for (int i = 1; i <= 5; i++) {
        await addMedicine(name: 'Medicine $i');
      }

      final List<Medicine> stored = await repository.allMedicines();
      expect(
        stored.map((Medicine m) => m.glyphIndex).toList(),
        equals(<int>[0, 1, 2, 3, 0]),
        reason:
            'read back out of the table -- if the index were derived from list '
            'position on read, the fifth would be 4 and not 0',
      );
    });

    test('deleting one never reshuffles the others', () async {
      final List<Medicine> created = <Medicine>[
        for (int i = 1; i <= 4; i++) await addMedicine(name: 'Medicine $i'),
      ];

      await repository.deleteMedicine(created[1].id);

      final List<Medicine> left = await repository.allMedicines();
      expect(
        left.map((Medicine m) => '${m.name}:${m.glyphIndex}').toList(),
        equals(<String>['Medicine 1:0', 'Medicine 3:2', 'Medicine 4:3']),
        reason:
            'AD-22: renumbering would change a Medicine\'s silhouette on every '
            'surface it appears on, which is the failure the decision exists '
            'to prevent',
      );
    });

    test(
      'an index may be reused after a deletion, and that is correct',
      () async {
        // The spec's "Delete then create" row. Deliberately its own test with
        // its own name, so that a future reader who thinks this is a collision
        // bug finds the reason before "fixing" it.
        final Medicine only = await addMedicine(name: 'Only');
        expect(only.glyphIndex, 0);

        await repository.deleteMedicine(only.id);
        final Medicine replacement = await addMedicine(name: 'Replacement');

        expect(
          replacement.glyphIndex,
          0,
          reason:
              'the table is empty again, so the count is 0. AD-22 promises only '
              'that consecutive additions differ and that no existing row is '
              'reshuffled.',
        );
      },
    );

    test('two medicines still standing can share an index', () async {
      // The overlap AD-22 explicitly tolerates: delete the second of two, add
      // a third, and the third is handed the index the first already wears.
      final Medicine first = await addMedicine(name: 'First');
      final Medicine second = await addMedicine(name: 'Second');
      await repository.deleteMedicine(second.id);
      final Medicine third = await addMedicine(name: 'Third');

      expect(first.glyphIndex, 0);
      expect(third.glyphIndex, 1);

      // And with both removed, the next one starts over.
      await repository.deleteMedicine(first.id);
      await repository.deleteMedicine(third.id);
      expect((await addMedicine(name: 'Fourth')).glyphIndex, 0);
    });

    test('the count and the insert share one transaction', () async {
      recorder.clear();
      await addMedicine();

      final int begin = recorder.log.indexOf('begin');
      final int commit = recorder.log.indexOf('commit');
      final int count = recorder.log.indexWhere(
        (String entry) =>
            entry.startsWith('select:') &&
            entry.toUpperCase().contains('COUNT('),
      );
      final int insert = recorder.log.indexWhere(
        (String entry) => entry.startsWith('insert:'),
      );

      expect(begin, isNonNegative, reason: recorder.log.toString());
      expect(count, greaterThan(begin));
      expect(insert, greaterThan(count));
      expect(
        commit,
        greaterThan(insert),
        reason:
            'a count read outside the transaction is a read-modify-write: two '
            'medicines added in the same moment would read the same count and '
            'be handed the same glyph',
      );
    });
  });

  group('reading medicines', () {
    test('an unknown id is null, not a failure', () async {
      expect(await repository.findMedicine('nope'), isNull);
    });

    test('every field round-trips, including the optional ones', () async {
      final Medicine saved = await repository.addMedicine(
        name: 'Metformin',
        condition: 'blood sugar',
        form: 'tablet',
        dosageAmount: 2.5,
        dosageUnit: 'ml',
        instructions: 'with food',
        startDate: DateTime(2026, 9, 7),
        endDate: DateTime(2026, 12, 31),
        active: false,
      );

      final Medicine? read = await repository.findMedicine(saved.id);
      expect(read, isNotNull);
      expect(read!.name, 'Metformin');
      expect(read.condition, 'blood sugar');
      expect(read.dosageAmount, 2.5);
      expect(read.dosageUnit, 'ml');
      expect(read.instructions, 'with food');
      expect(read.startDate, DateTime(2026, 9, 7));
      expect(read.endDate, DateTime(2026, 12, 31));
      expect(read.active, isFalse);
      expect(read.glyphIndex, 0);
    });

    test(
      'the optional fields come back null when they were not given',
      () async {
        final Medicine? read = await repository.findMedicine(
          (await addMedicine()).id,
        );

        expect(read!.condition, isNull);
        expect(read.instructions, isNull);
        expect(read.endDate, isNull);
        expect(read.active, isTrue);
      },
    );

    test('a date is stored as ten characters of calendar date', () async {
      await addMedicine();

      final List<QueryRow> rows = await database
          .customSelect('SELECT start_date FROM medicines')
          .get();
      expect(
        rows.single.data['start_date'],
        '2026-09-07',
        reason:
            'not an epoch and not an ISO instant -- a calendar date has no '
            'time to convert, and converting one moves a medicine started '
            'today to yesterday for every user east of UTC',
      );
    });

    test('the list is in insertion order, which is glyph order', () async {
      // Named so a future "sort alphabetically" change fails here with the
      // reason: the glyph sequence is only observable while the order is
      // insertion order.
      await addMedicine(name: 'Zinc');
      await addMedicine(name: 'Amlodipine');

      expect(
        (await repository.allMedicines()).map((Medicine m) => m.name).toList(),
        equals(<String>['Zinc', 'Amlodipine']),
      );
    });

    test('the insertion order is ASKED for, not assumed', () async {
      // The previous test passes either way: SQLite happens to return rows in
      // rowid order for a `SELECT` with no `ORDER BY`, so dropping the clause
      // is invisible in the result and stays invisible until a query plan
      // changes -- an index, a join, a `VACUUM`. The only observable
      // difference is the statement itself, so this reads the SQL.
      await addMedicine();
      recorder.clear();
      await repository.allMedicines();

      expect(
        recorder.log.single,
        contains('ORDER BY rowid'),
        reason:
            'SQLite does not promise the order of a SELECT without ORDER BY. '
            'The glyph sequence AD-22 assigns is only observable while the '
            'order is insertion order, so it has to be requested.',
      );
    });

    test('an empty table reads as an empty list', () async {
      expect(await repository.allMedicines(), isEmpty);
    });
  });

  group('editing a medicine', () {
    test('a saved edit is read back, and the glyph is untouched', () async {
      final Medicine original = await addMedicine();
      await addMedicine(name: 'Second');
      final Medicine second = (await repository.allMedicines()).last;
      expect(second.glyphIndex, 1);

      await repository.saveMedicine(
        second.copyWith(name: 'Amlodipine', dosageAmount: 5, active: false),
      );

      final Medicine? read = await repository.findMedicine(second.id);
      expect(read!.name, 'Amlodipine');
      expect(read.dosageAmount, 5);
      expect(read.active, isFalse);
      expect(read.glyphIndex, 1, reason: 'AD-22 forbids recomputing it');

      // And the other medicine was not touched.
      final Medicine? untouched = await repository.findMedicine(original.id);
      expect(untouched!.name, 'Metformin');
    });

    test(
      'saving a medicine that is not there fails, and inserts nothing',
      () async {
        final Medicine ghost = Medicine(
          id: 'never-stored',
          name: 'Ghost',
          glyphIndex: 0,
          form: 'tablet',
          dosageAmount: 1,
          dosageUnit: 'tablet',
          startDate: DateTime(2026, 9, 7),
        );

        await expectLater(
          repository.saveMedicine(ghost),
          throwsA(
            isA<MedicineNotFoundFailure>().having(
              (MedicineNotFoundFailure e) => e.medicineId,
              'medicineId',
              'never-stored',
            ),
          ),
        );
        expect(
          await repository.allMedicines(),
          isEmpty,
          reason:
              'an update that fell back to an insert would resurrect a medicine '
              'the user deleted on another surface',
        );
      },
    );
  });

  group('schedules store a wall clock and a zone (AD-6)', () {
    test(
      'the row holds the time as written, with no instant beside it',
      () async {
        final Medicine medicine = await addMedicine();
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );

        final List<QueryRow> rows = await database
            .customSelect('SELECT * FROM schedules')
            .get();
        final Map<String, Object?> row = rows.single.data;

        expect(row['time_of_day'], '08:00');
        expect(row['iana_timezone'], 'Asia/Colombo');
        expect(
          row.keys,
          equals(<String>[
            'id',
            'medicine_id',
            'time_of_day',
            'iana_timezone',
            'frequency',
            'days_of_week',
            'interval_days',
            'dosage_amount',
            'reminder_override',
          ]),
          reason: 'the stored row has no second representation of the time',
        );
      },
    );

    test('the frequency is stored by name, not by index', () async {
      final Medicine medicine = await addMedicine();
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyNDays,
        intervalDays: 3,
        dosageAmount: 1,
      );

      final List<QueryRow> rows = await database
          .customSelect('SELECT frequency, interval_days FROM schedules')
          .get();
      expect(
        rows.single.data['frequency'],
        'everyNDays',
        reason:
            'an index would silently reinterpret every stored row the day a '
            'value is inserted into the middle of the enum',
      );
      expect(rows.single.data['interval_days'], 3);
    });

    test('a day set is stored ascending and comes back as a set', () async {
      final Medicine medicine = await addMedicine();
      final Schedule saved = await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.friday, DateTime.monday},
        dosageAmount: 1,
      );

      final List<QueryRow> rows = await database
          .customSelect('SELECT days_of_week FROM schedules')
          .get();
      expect(rows.single.data['days_of_week'], '1,5');

      final List<Schedule> read = await repository.schedulesFor(medicine.id);
      expect(read.single.daysOfWeek, equals(<int>{1, 5}));
      expect(read.single.id, saved.id);
    });

    test(
      'a frequency with no day set stores null, not an empty string',
      () async {
        final Medicine medicine = await addMedicine();
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );

        final List<QueryRow> rows = await database
            .customSelect('SELECT days_of_week, interval_days FROM schedules')
            .get();
        expect(rows.single.data['days_of_week'], isNull);
        expect(rows.single.data['interval_days'], isNull);
        expect(
          (await repository.schedulesFor(medicine.id)).single.daysOfWeek,
          isNull,
        );
      },
    );

    test(
      'a per-occurrence dosage and a reminder override round-trip',
      () async {
        final Medicine medicine = await addMedicine();
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: '20:30',
          ianaTimezone: 'Europe/London',
          frequency: Frequency.weekdays,
          dosageAmount: 0.5,
          reminderOverride: 'PT45M',
        );

        final Schedule read = (await repository.schedulesFor(
          medicine.id,
        )).single;
        expect(read.dosageAmount, 0.5);
        expect(read.reminderOverride, 'PT45M');
        expect(read.ianaTimezone, 'Europe/London');
        expect(read.frequency, Frequency.weekdays);
      },
    );

    test('schedules come back earliest time first', () async {
      final Medicine medicine = await addMedicine();
      for (final String time in <String>['20:00', '08:00', '13:30']) {
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: time,
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );
      }

      expect(
        (await repository.schedulesFor(
          medicine.id,
        )).map((Schedule s) => s.timeOfDay).toList(),
        equals(<String>['08:00', '13:30', '20:00']),
      );
    });

    test('a medicine with no schedules reads as an empty list', () async {
      expect(await repository.schedulesFor((await addMedicine()).id), isEmpty);
      expect(await repository.schedulesFor('no-such-medicine'), isEmpty);
    });
  });

  group('the duplicate-schedule rule', () {
    Future<Schedule> addAt(
      String medicineId,
      String time, {
      Frequency frequency = Frequency.everyDay,
      Set<int>? days,
    }) => repository.addSchedule(
      medicineId: medicineId,
      timeOfDay: time,
      ianaTimezone: 'Asia/Colombo',
      frequency: frequency,
      daysOfWeek: days,
      dosageAmount: 1,
    );

    test('an identical time on overlapping days is rejected by name', () async {
      final Medicine medicine = await addMedicine();
      final Schedule existing = await addAt(medicine.id, '08:00');

      await expectLater(
        addAt(medicine.id, '08:00'),
        throwsA(
          isA<DuplicateScheduleFailure>()
              .having(
                (DuplicateScheduleFailure e) => e.existingScheduleId,
                'existingScheduleId',
                existing.id,
              )
              .having(
                (DuplicateScheduleFailure e) => e.timeOfDay,
                'timeOfDay',
                '08:00',
              )
              .having(
                (DuplicateScheduleFailure e) => e.message,
                'message',
                allOf(
                  contains('08:00'),
                  contains(DuplicateScheduleFailure.everyDayPhrase),
                  // Not a dump of the internal day set. Two everyDay
                  // schedules are the commonest clash there is, and
                  // "on Mon, Tue, Wed, Thu, Fri, Sat, Sun" reads as one --
                  // and it is one, because occupiedDaysOfWeek over-claims
                  // the week for an interval schedule on purpose.
                  isNot(contains('Mon,')),
                  isNot(contains('Sun')),
                ),
              ),
        ),
        reason:
            'the message has to name the clash: the user set a time and a set '
            'of days, and the sentence says which of them already exists',
      );
    });

    test('nothing is written when it is rejected', () async {
      final Medicine medicine = await addMedicine();
      await addAt(medicine.id, '08:00');

      await expectLater(
        addAt(medicine.id, '08:00'),
        throwsA(isA<DuplicateScheduleFailure>()),
      );

      expect(
        await repository.schedulesFor(medicine.id),
        hasLength(1),
        reason: 'a rejected save must not silently create the duplicate',
      );
    });

    test('the same time on disjoint days is accepted', () async {
      final Medicine medicine = await addMedicine();
      await addAt(
        medicine.id,
        '08:00',
        frequency: Frequency.specificDays,
        days: <int>{DateTime.monday},
      );
      await addAt(
        medicine.id,
        '08:00',
        frequency: Frequency.specificDays,
        days: <int>{DateTime.tuesday},
      );

      expect(await repository.schedulesFor(medicine.id), hasLength(2));
    });

    test('the same time on a different medicine is accepted', () async {
      final Medicine first = await addMedicine(name: 'First');
      final Medicine second = await addMedicine(name: 'Second');

      await addAt(first.id, '08:00');
      await addAt(second.id, '08:00');

      expect(await repository.schedulesFor(first.id), hasLength(1));
      expect(await repository.schedulesFor(second.id), hasLength(1));
    });

    test('the reported overlap is the days the two actually share', () async {
      final Medicine medicine = await addMedicine();
      await addAt(medicine.id, '08:00', frequency: Frequency.weekdays);

      try {
        await addAt(
          medicine.id,
          '08:00',
          frequency: Frequency.specificDays,
          days: <int>{DateTime.friday, DateTime.sunday},
        );
        fail('expected a DuplicateScheduleFailure');
      } on DuplicateScheduleFailure catch (failure) {
        expect(failure.overlappingDays, equals(<int>{DateTime.friday}));
        expect(failure.message, contains('Fri'));
        expect(failure.message, isNot(contains('Sun')));
      }
    });

    test(
      'a mispaired frequency is refused with the domain\'s message',
      () async {
        final Medicine medicine = await addMedicine();

        await expectLater(
          addAt(medicine.id, '08:00', frequency: Frequency.specificDays),
          throwsA(
            isA<ScheduleNotValidFailure>().having(
              (ScheduleNotValidFailure e) => e.message,
              'message',
              contains('at least one day'),
            ),
          ),
        );
        expect(await repository.schedulesFor(medicine.id), isEmpty);
      },
    );

    test('an unknown medicine is named, not left to the foreign key', () async {
      await expectLater(
        addAt('no-such-medicine', '08:00'),
        throwsA(isA<MedicineNotFoundFailure>()),
        reason:
            'the spine\'s Errors convention: adapters translate platform '
            'exceptions into typed domain failures at the boundary',
      );
    });

    test('editing a schedule and saving it unchanged succeeds', () async {
      final Medicine medicine = await addMedicine();
      final Schedule existing = await addAt(medicine.id, '08:00');

      await repository.saveSchedule(existing);
      await repository.saveSchedule(existing.copyWith(dosageAmount: 2));

      final Schedule read = (await repository.schedulesFor(medicine.id)).single;
      expect(read.dosageAmount, 2);
    });

    test('editing a schedule onto another one\'s slot is rejected', () async {
      final Medicine medicine = await addMedicine();
      await addAt(medicine.id, '08:00');
      final Schedule evening = await addAt(medicine.id, '20:00');

      await expectLater(
        repository.saveSchedule(evening.copyWith(timeOfDay: '08:00')),
        throwsA(isA<DuplicateScheduleFailure>()),
      );
      expect(
        (await repository.schedulesFor(
          medicine.id,
        )).map((Schedule s) => s.timeOfDay).toList(),
        equals(<String>['08:00', '20:00']),
      );
    });

    test(
      'saving a schedule that is not there fails, and inserts nothing',
      () async {
        final Medicine medicine = await addMedicine();
        final Schedule ghost = Schedule(
          id: 'never-stored',
          medicineId: medicine.id,
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );

        await expectLater(
          repository.saveSchedule(ghost),
          throwsA(isA<ScheduleNotFoundFailure>()),
        );
        expect(await repository.schedulesFor(medicine.id), isEmpty);
      },
    );

    test('deleting a schedule leaves the medicine and its siblings', () async {
      final Medicine medicine = await addMedicine();
      final Schedule morning = await addAt(medicine.id, '08:00');
      await addAt(medicine.id, '20:00');

      await repository.deleteSchedule(morning.id);

      expect(
        (await repository.schedulesFor(
          medicine.id,
        )).map((Schedule s) => s.timeOfDay).toList(),
        equals(<String>['20:00']),
      );
      expect(await repository.findMedicine(medicine.id), isNotNull);
    });

    // D2. The test above -- "an unknown medicine is named, not left to the
    // foreign key" -- calls addSchedule with the medicines table EMPTY, so
    // `count(where: id == …)` returns 0 whether or not the WHERE clause is
    // there. Dropping the clause entirely passed all 324 tests. The guard is
    // only observable when another Medicine exists to be counted.
    test(
      'an unknown medicine is named even when other medicines exist',
      () async {
        await addMedicine(name: 'Metformin');
        await addMedicine(name: 'Candesartan');

        await expectLater(
          addAt('no-such-medicine', '08:00'),
          throwsA(
            isA<MedicineNotFoundFailure>().having(
              (MedicineNotFoundFailure e) => e.medicineId,
              'medicineId',
              'no-such-medicine',
            ),
          ),
        );
      },
    );

    // D3. The port documents three failures for saveSchedule, and this was the
    // unpinned one: deleting its `_requireMedicine` call left 324 tests green.
    test(
      'saving a schedule whose medicine is gone names the medicine',
      () async {
        final Medicine medicine = await addMedicine();
        final Schedule schedule = await addAt(medicine.id, '08:00');
        await repository.deleteMedicine(medicine.id);

        await expectLater(
          repository.saveSchedule(schedule.copyWith(timeOfDay: '09:00')),
          throwsA(isA<MedicineNotFoundFailure>()),
        );
      },
    );

    // D6. Two of the four sentences this port can put in front of a user were
    // unpinned -- replacing both message bodies with 'x' survived the suite,
    // while the other two failure messages were asserted. The base class
    // documents these as showable as they stand, so they are copy, and copy
    // in this product is checked.
    test(
      'the not-found failures carry a sentence, in the product voice',
      () async {
        const MedicineNotFoundFailure medicineGone = MedicineNotFoundFailure(
          'gone',
        );
        const ScheduleNotFoundFailure scheduleGone = ScheduleNotFoundFailure(
          'gone',
        );

        expect(
          medicineGone.message,
          'That medicine is no longer in your list.',
        );
        expect(
          scheduleGone.message,
          'That dose time is no longer on this medicine.',
        );

        for (final MedicineRepositoryFailure failure
            in <MedicineRepositoryFailure>[medicineGone, scheduleGone]) {
          // EXPERIENCE.md's voice: a complete sentence, sentence case, no
          // exclamation, and no blame placed on the person.
          expect(failure.message, endsWith('.'));
          expect(failure.message, isNot(contains('!')));
          expect(failure.message.split(' ').length, greaterThan(3));
          // toString carries the message, so an uncaught failure in a log reads
          // as the sentence rather than as a type name.
          expect(failure.toString(), contains(failure.message));
        }
      },
    );

    test('deleting a schedule twice is not an error', () async {
      final Medicine medicine = await addMedicine();
      final Schedule only = await addAt(medicine.id, '08:00');

      await repository.deleteSchedule(only.id);
      await repository.deleteSchedule(only.id);

      expect(await repository.schedulesFor(medicine.id), isEmpty);
    });
  });

  group('deleting a medicine takes its schedules with it (AD-12)', () {
    test('both schedules go, and in ONE transaction', () async {
      final Medicine medicine = await addMedicine();
      for (final String time in <String>['08:00', '20:00']) {
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: time,
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );
      }

      recorder.clear();
      await repository.deleteMedicine(medicine.id);
      // Snapshotted BEFORE the reads below, which would otherwise append their
      // own SELECTs to the log and make `log.last` the last verification query
      // rather than the COMMIT.
      final List<String> issued = List<String>.of(recorder.log);
      final List<String> deletes = List<String>.of(recorder.deletes);

      expect(await repository.findMedicine(medicine.id), isNull);
      expect(await repository.schedulesFor(medicine.id), isEmpty);

      // The result alone proves nothing about atomicity -- the cascade would
      // produce it too -- so this reads the statements that actually reached
      // SQLite. The two deletes must sit between one BEGIN and one COMMIT: a
      // failure part-way then leaves NEITHER removed, never a Medicine without
      // its Schedules (orphaned reminders) or Schedules without their Medicine.
      expect(
        issued,
        equals(<String>[
          'begin',
          'delete: DELETE FROM "schedules" WHERE "medicine_id" = ?;',
          'delete: DELETE FROM "medicines" WHERE "id" = ?;',
          'commit',
        ]),
        reason:
            'Exactly this, in exactly this order. Schedules first because '
            'with foreign keys on and no cascade, deleting the medicine first '
            'would be rejected by the key; both inside one transaction '
            'because AD-12 promises they go together.',
      );
      expect(deletes, hasLength(2));
    });

    test('another medicine\'s schedules are left alone', () async {
      final Medicine doomed = await addMedicine(name: 'Doomed');
      final Medicine kept = await addMedicine(name: 'Kept');
      for (final Medicine medicine in <Medicine>[doomed, kept]) {
        await repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        );
      }

      await repository.deleteMedicine(doomed.id);

      expect(await repository.schedulesFor(kept.id), hasLength(1));
      expect(await repository.findMedicine(kept.id), isNotNull);
    });

    test('deleting an id that is not stored is not an error', () async {
      await repository.deleteMedicine('no-such-medicine');
      expect(await repository.allMedicines(), isEmpty);
    });
  });

  group('a medicine survives a real restart', () {
    // A real file, closed and reopened. The in-memory tests above cannot show
    // this: `close()` on an in-memory executor followed by a query silently
    // opens a fresh, empty database, so a "reopen" there reads as a valid
    // fresh install rather than as a lost record.
    test('the medicine and both schedules are still there', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_medicine_restart',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/db.sqlite');

      final AppDatabase first = AppDatabase(NativeDatabase(file));
      final MedicineRepository writer = DriftMedicineRepository(first);
      final Medicine saved = await writer.addMedicine(
        name: 'Metformin',
        condition: 'blood sugar',
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 7),
      );
      await writer.addSchedule(
        medicineId: saved.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      await writer.addSchedule(
        medicineId: saved.id,
        timeOfDay: '20:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.monday, DateTime.thursday},
        dosageAmount: 0.5,
      );
      await first.close();

      // The connection is gone. The file is what has to carry the record.
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));

      final AppDatabase second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final MedicineRepository reader = DriftMedicineRepository(second);

      final Medicine? read = await reader.findMedicine(saved.id);
      expect(read, isNotNull, reason: 'the medicine did not survive the close');
      expect(read!.name, 'Metformin');
      expect(read.condition, 'blood sugar');
      expect(read.glyphIndex, 0);
      expect(read.startDate, DateTime(2026, 9, 7));

      final List<Schedule> schedules = await reader.schedulesFor(saved.id);
      expect(schedules, hasLength(2));
      expect(schedules.first.timeOfDay, '08:00');
      expect(schedules.last.timeOfDay, '20:00');
      expect(
        schedules.last.daysOfWeek,
        equals(<int>{DateTime.monday, DateTime.thursday}),
      );
      expect(schedules.last.dosageAmount, 0.5);

      // And the glyph sequence continues from what is on disk rather than
      // starting over -- proof the count was read from the reopened file.
      final Medicine next = await reader.addMedicine(
        name: 'Amlodipine',
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 7),
      );
      expect(next.glyphIndex, 1);
    });
  });

  group('the identities are UUID v4 by default', () {
    test('a repository with no injected generator mints real uuids', () async {
      final MedicineRepository real = DriftMedicineRepository(database);
      final Medicine medicine = await real.addMedicine(
        name: 'Metformin',
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 7),
      );

      expect(
        medicine.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
        reason: 'the spine\'s Identifiers convention: UUID v4 as text',
      );

      final Schedule schedule = await real.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      expect(schedule.id, isNot(medicine.id));
      expect(schedule.id, hasLength(36));
    });
  });

  group('an unreadable frequency fails loudly', () {
    test(
      'a row this build cannot read is not quietly treated as daily',
      () async {
        final Medicine medicine = await addMedicine();
        await database.customStatement(
          'INSERT INTO schedules (id, medicine_id, time_of_day, iana_timezone, '
          'frequency, dosage_amount) '
          "VALUES ('s-bad', ?, '08:00', 'Asia/Colombo', 'fortnightly', 1.0)",
          <Object?>[medicine.id],
        );

        await expectLater(
          repository.schedulesFor(medicine.id),
          throwsA(
            isA<MedicineRecordNotReadableFailure>()
                .having(
                  (MedicineRecordNotReadableFailure e) => e.detail,
                  'detail',
                  contains('s-bad'),
                )
                .having(
                  (MedicineRecordNotReadableFailure e) => e.message,
                  'message',
                  contains('could not be read'),
                ),
          ),
          reason:
              'silently falling back to everyDay would produce reminders the '
              'user never asked for -- and the failure has to be one of the '
              'port\'s own types, not a bare StateError from a layer the '
              'caller is not supposed to know exists',
        );
      },
    );

    test('every failure that escapes is a MedicineRepositoryFailure', () async {
      // The spine's Errors convention, over the rows a raw statement can
      // actually plant. Before the adapter translated them these produced an
      // ArgumentError, two FormatExceptions and a StateError -- four exception
      // types the port never documented, from a layer the caller is not
      // supposed to know exists.
      //
      // `time_of_day` is absent from this list on purpose: its GLOB check
      // rejects '99:99' on an UPDATE as well as an INSERT, so that row cannot
      // be planted at all. `test/db_schema_test.dart` covers it where it is
      // actually enforced.
      //
      // Each case is a COMPLETE column list rather than a template with one
      // value substituted. The template version named the target column twice
      // -- once in the fixed list and once as the override -- and SQLite
      // quietly kept the first value, so two of the four rows were written
      // well-formed and the test passed on two rejections it never triggered.
      final Medicine medicine = await addMedicine();
      final String id = medicine.id;

      final List<(String, String)> plants = <(String, String)>[
        (
          'an abbreviation is not a zone',
          "('s-zone', '$id', '08:00', 'IST', 'everyDay', 1.0, NULL, NULL)",
        ),
        (
          'an empty element in the day list',
          "('s-days', '$id', '08:00', 'Asia/Colombo', 'specificDays', 1.0, "
              "'1,,5', NULL)",
        ),
        (
          'a day outside 1..7',
          "('s-day9', '$id', '08:00', 'Asia/Colombo', 'specificDays', 1.0, "
              "'9', NULL)",
        ),
        (
          'a frequency this build does not know',
          "('s-freq', '$id', '08:00', 'Asia/Colombo', 'fortnightly', 1.0, "
              'NULL, NULL)',
        ),
        (
          'everyNDays with no interval',
          "('s-pair', '$id', '08:00', 'Asia/Colombo', 'everyNDays', 1.0, "
              'NULL, NULL)',
        ),
      ];

      for (final (String, String) plant in plants) {
        final (String why, String values) = plant;
        await database.customStatement(
          'INSERT INTO schedules (id, medicine_id, time_of_day, '
          'iana_timezone, frequency, dosage_amount, days_of_week, '
          'interval_days) VALUES $values',
        );

        await expectLater(
          repository.schedulesFor(id),
          throwsA(isA<MedicineRepositoryFailure>()),
          reason: '$why must not escape as an untyped exception',
        );

        await database.customStatement(
          'DELETE FROM schedules WHERE medicine_id = ?',
          <Object?>[id],
        );
      }

      // And with all five gone, the read works again -- so the failures above
      // were about the planted rows and not about the query.
      expect(await repository.schedulesFor(id), isEmpty);
    });

    test('the pairing rule is what refuses an unpairable row', () async {
      // `frequency`, `days_of_week` and `interval_days` are independently
      // nullable -- three of the four frequencies leave each one empty -- so
      // no CHECK can express "everyNDays needs an interval". Without a check
      // on the way out, such a row reaches a caller that has no legal way to
      // interpret it, and dose generation either skips it silently or throws
      // somewhere far from the row that caused it.
      final Medicine medicine = await addMedicine();
      await database.customStatement(
        'INSERT INTO schedules (id, medicine_id, time_of_day, iana_timezone, '
        'frequency, dosage_amount) '
        "VALUES ('s-unpaired', ?, '08:00', 'Asia/Colombo', 'everyNDays', 1.0)",
        <Object?>[medicine.id],
      );

      await expectLater(
        repository.schedulesFor(medicine.id),
        throwsA(
          isA<MedicineRecordNotReadableFailure>().having(
            (MedicineRecordNotReadableFailure e) => e.detail,
            'detail',
            allOf(contains('everyNDays'), contains('interval_days=null')),
          ),
        ),
      );
    });

    test('an unreadable date is translated, not rolled over', () async {
      // '2026-13-25' passes the schema's GLOB -- month `13` matches
      // `[0-1][0-9]` -- and `DateTime(2026, 13, 25)` does not throw: Dart
      // rolls it to 2027-01-25. A start date moved thirteen months with
      // nothing anywhere reporting it is exactly the class of bug that has no
      // symptom until doses stop being generated.
      await database.customStatement(_rawMedicine('m-bad', '2026-13-25'));

      await expectLater(
        repository.findMedicine('m-bad'),
        throwsA(
          isA<MedicineRecordNotReadableFailure>().having(
            (MedicineRecordNotReadableFailure e) => e.detail,
            'detail',
            contains('m-bad'),
          ),
        ),
      );
      await expectLater(
        repository.allMedicines(),
        throwsA(isA<MedicineRecordNotReadableFailure>()),
        reason: 'the list read has to refuse it as well, not just the lookup',
      );
    });

    test('31 February is refused rather than rolled into March', () async {
      // The case a month/day range check alone still lets through.
      await database.customStatement(_rawMedicine('m-feb', '2026-02-31'));

      await expectLater(
        repository.findMedicine('m-feb'),
        throwsA(isA<MedicineRecordNotReadableFailure>()),
      );
    });

    test('a well-formed record still reads — the positive control', () async {
      // Four rejections above prove nothing if the read path is simply broken.
      final Medicine medicine = await addMedicine();
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyNDays,
        intervalDays: 3,
        dosageAmount: 1,
      );

      expect(await repository.findMedicine(medicine.id), isNotNull);
      expect(await repository.schedulesFor(medicine.id), hasLength(1));
    });
  });

  group('an unknown medicine is refused with the table NOT empty', () {
    // D2. The one test that named this behaviour called `addSchedule` with an
    // unknown id while `medicines` was EMPTY, so `count(*) WHERE id = ?` and
    // `count(*)` both answered 0 and the WHERE clause could be deleted with
    // the suite still green. Every case below has a Medicine in the table
    // that is not the one being named.

    test('addSchedule names the missing medicine', () async {
      final Medicine other = await addMedicine(name: 'Something else');
      expect(await repository.allMedicines(), hasLength(1));

      await expectLater(
        repository.addSchedule(
          medicineId: 'no-such-medicine',
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        ),
        throwsA(
          isA<MedicineNotFoundFailure>().having(
            (MedicineNotFoundFailure e) => e.medicineId,
            'medicineId',
            'no-such-medicine',
          ),
        ),
      );

      // Nothing was written, and the Medicine that does exist is untouched.
      expect(await repository.schedulesFor(other.id), isEmpty);
      final List<QueryRow> all = await database
          .customSelect('SELECT id FROM schedules')
          .get();
      expect(all, isEmpty);
    });

    test('saveSchedule names the missing medicine', () async {
      // D3. Deleting `_requireMedicine` from `saveSchedule` entirely left the
      // whole suite green: the port documented the failure and nothing
      // reached it.
      await addMedicine(name: 'Something else');
      final Schedule orphan = Schedule(
        id: 'some-schedule',
        medicineId: 'no-such-medicine',
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );

      await expectLater(
        repository.saveSchedule(orphan),
        throwsA(
          isA<MedicineNotFoundFailure>().having(
            (MedicineNotFoundFailure e) => e.medicineId,
            'medicineId',
            'no-such-medicine',
          ),
        ),
      );
    });

    test(
      'saveMedicine names the missing medicine, with others present',
      () async {
        await addMedicine(name: 'Something else');
        final Medicine ghost = Medicine(
          id: 'never-stored',
          name: 'Ghost',
          glyphIndex: 0,
          form: 'tablet',
          dosageAmount: 1,
          dosageUnit: 'tablet',
          startDate: DateTime(2026, 9, 7),
        );

        await expectLater(
          repository.saveMedicine(ghost),
          throwsA(isA<MedicineNotFoundFailure>()),
        );
        expect(
          await repository.allMedicines(),
          hasLength(1),
          reason: 'and it did not insert the ghost beside the real one',
        );
      },
    );
  });

  group('a Schedule cannot be moved to another Medicine', () {
    // P11. `Schedule.copyWith` offers no `medicineId`, but `saveSchedule`
    // accepts any hand-constructed Schedule and `replace` matches on the
    // primary key alone. Without a check, the row moves -- and the clash test
    // then runs against the NEW parent only, so a duplicate can be left
    // standing on the old one and the Medicine being edited silently loses a
    // dose time.

    test('the move is rejected and the row stays where it was', () async {
      final Medicine from = await addMedicine(name: 'From');
      final Medicine to = await addMedicine(name: 'To');
      final Schedule schedule = await repository.addSchedule(
        medicineId: from.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );

      final Schedule moved = Schedule(
        id: schedule.id,
        medicineId: to.id,
        timeOfDay: schedule.timeOfDay,
        ianaTimezone: schedule.ianaTimezone,
        frequency: schedule.frequency,
        dosageAmount: schedule.dosageAmount,
      );

      await expectLater(
        repository.saveSchedule(moved),
        throwsA(
          isA<ScheduleNotFoundFailure>().having(
            (ScheduleNotFoundFailure e) => e.scheduleId,
            'scheduleId',
            schedule.id,
          ),
        ),
        reason:
            'from the caller\'s side this Medicine has no Schedule with that '
            'id, which is what "not found" means',
      );

      expect(await repository.schedulesFor(from.id), hasLength(1));
      expect(await repository.schedulesFor(to.id), isEmpty);
    });

    test('a legitimate edit on the right parent still succeeds', () async {
      // The positive control for the check above.
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );

      await repository.saveSchedule(schedule.copyWith(timeOfDay: '09:00'));

      expect(
        (await repository.schedulesFor(medicine.id)).single.timeOfDay,
        '09:00',
      );
    });
  });

  group('a Medicine that FR-1 refuses is never written', () {
    // P12. `Medicine.violation` is the rule; this is the repository refusing
    // to store one that has a violation, on both write paths.

    test('addMedicine refuses a blank name and writes nothing', () async {
      await expectLater(
        repository.addMedicine(
          name: '   ',
          form: 'tablet',
          dosageAmount: 1,
          dosageUnit: 'tablet',
          startDate: DateTime(2026, 9, 7),
        ),
        throwsA(
          isA<MedicineNotValidFailure>().having(
            (MedicineNotValidFailure e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
      expect(await repository.allMedicines(), isEmpty);
    });

    test('addMedicine refuses a dosage of zero or less', () async {
      for (final double amount in <double>[0, -1]) {
        await expectLater(
          repository.addMedicine(
            name: 'Metformin',
            form: 'tablet',
            dosageAmount: amount,
            dosageUnit: 'tablet',
            startDate: DateTime(2026, 9, 7),
          ),
          throwsA(isA<MedicineNotValidFailure>()),
        );
      }
      expect(await repository.allMedicines(), isEmpty);
    });

    test('addMedicine refuses an end date before the start date', () async {
      await expectLater(
        repository.addMedicine(
          name: 'Metformin',
          form: 'tablet',
          dosageAmount: 1,
          dosageUnit: 'tablet',
          startDate: DateTime(2026, 9, 7),
          endDate: DateTime(2026, 9, 6),
        ),
        throwsA(isA<MedicineNotValidFailure>()),
      );
      expect(await repository.allMedicines(), isEmpty);
    });

    test('the rejected add does not consume a glyph', () async {
      // The count is read inside the same transaction as the insert, so a
      // rejected add has to roll the whole thing back -- otherwise the next
      // medicine would be handed glyph 1 with nothing wearing glyph 0.
      await expectLater(
        repository.addMedicine(
          name: '',
          form: 'tablet',
          dosageAmount: 1,
          dosageUnit: 'tablet',
          startDate: DateTime(2026, 9, 7),
        ),
        throwsA(isA<MedicineNotValidFailure>()),
      );

      expect((await addMedicine()).glyphIndex, 0);
    });

    test(
      'saveMedicine refuses one too, and leaves the stored row alone',
      () async {
        final Medicine medicine = await addMedicine();

        await expectLater(
          repository.saveMedicine(medicine.copyWith(name: ' ')),
          throwsA(isA<MedicineNotValidFailure>()),
        );

        expect(
          (await repository.findMedicine(medicine.id))!.name,
          'Metformin',
          reason: 'the edit was refused, so the stored name is the old one',
        );
      },
    );
  });

  group('every failure carries a sentence a user could read', () {
    // D6. Two of the five messages were asserted and three were not, so
    // replacing them with 'x' survived the suite -- on a base class whose
    // whole documented purpose is that the sentence can be shown as it
    // stands.

    test('MedicineNotFoundFailure', () {
      const MedicineNotFoundFailure failure = MedicineNotFoundFailure('m1');

      expect(failure.message, 'That medicine is no longer in your list.');
      expect(failure.message, isNot(contains('m1')), reason: 'no ids in copy');
    });

    test('ScheduleNotFoundFailure', () {
      const ScheduleNotFoundFailure failure = ScheduleNotFoundFailure('s1');

      expect(failure.message, 'That dose time is no longer on this medicine.');
      expect(failure.message, isNot(contains('s1')));
    });

    test('MedicineRecordNotReadableFailure says nothing was changed', () {
      final MedicineRecordNotReadableFailure failure =
          MedicineRecordNotReadableFailure(
            detail: 'schedule s1 stores frequency "fortnightly"',
            cause: StateError('unknown frequency'),
          );

      expect(
        failure.message,
        'Part of this medicine\'s record could not be read. Nothing has been '
        'changed.',
      );
      expect(
        failure.message,
        isNot(contains('fortnightly')),
        reason: 'the engineering detail belongs in the log, not on screen',
      );
      // ...and the log DOES get it.
      expect(failure.toString(), contains('fortnightly'));
    });

    test('every message is in the product\'s voice', () {
      final List<MedicineRepositoryFailure>
      failures = <MedicineRepositoryFailure>[
        const MedicineNotFoundFailure('m1'),
        const ScheduleNotFoundFailure('s1'),
        const MedicineNotValidFailure('Enter the name of the medicine.'),
        const ScheduleNotValidFailure('Choose at least one day of the week.'),
        const DuplicateScheduleFailure(
          existingScheduleId: 's1',
          timeOfDay: '08:00',
          overlappingDays: <int>{1},
        ),
        MedicineRecordNotReadableFailure(detail: 'x', cause: StateError('x')),
      ];

      for (final MedicineRepositoryFailure failure in failures) {
        expect(failure.message, isNotEmpty);
        expect(
          failure.message,
          isNot(contains('!')),
          reason: 'EXPERIENCE.md: no exclamation marks',
        );
        expect(
          failure.message.endsWith('.'),
          isTrue,
          reason: 'complete sentences: ${failure.message}',
        );
        expect(
          failure.message[0],
          failure.message[0].toUpperCase(),
          reason: 'sentence case: ${failure.message}',
        );
        // And a failure is a DomainFailure, so one `catch` reaches all of them.
        expect(failure, isA<DomainFailure>());
      }
    });

    test('toString names the type and the sentence', () {
      // The base class implements it once for every subclass, and the local
      // log is the only reader -- so it has to carry both.
      const MedicineNotFoundFailure failure = MedicineNotFoundFailure('m1');

      expect(
        failure.toString(),
        'MedicineNotFoundFailure: That medicine is no longer in your list.',
      );
    });

    test('the duplicate message names an interval clash by its days', () {
      // An everyNDays schedule over-claims the whole week by design, so a
      // clash against one collapses to "every day" rather than listing seven
      // day names the user never chose.
      const DuplicateScheduleFailure wholeWeek = DuplicateScheduleFailure(
        existingScheduleId: 's1',
        timeOfDay: '08:00',
        overlappingDays: <int>{1, 2, 3, 4, 5, 6, 7},
      );
      expect(
        wholeWeek.message,
        'This medicine already has a dose at 08:00 on every day.',
      );

      const DuplicateScheduleFailure someDays = DuplicateScheduleFailure(
        existingScheduleId: 's1',
        timeOfDay: '08:00',
        overlappingDays: <int>{5, 1},
      );
      expect(
        someDays.message,
        'This medicine already has a dose at 08:00 on Mon, Fri.',
        reason: 'ascending, and named -- not the set\'s iteration order',
      );
    });
  });

  group('the schedule checks and their writes share one transaction', () {
    // D4. `addMedicine`'s transaction was pinned and the other two were not,
    // so the wrapper could be replaced by a bare `Future(() async {...})`
    // with the suite green. It matters for the same reason: the clash check
    // READS the Medicine's other Schedules and then writes, so two saves of
    // the same time could both read a clash-free list and both insert -- the
    // "two reminders at the same minute" failure FR-4 exists to prevent,
    // invisible afterwards because the rule held at the moment each one
    // checked.

    test('addSchedule: begin, the checks, the insert, commit', () async {
      final Medicine medicine = await addMedicine();
      recorder.clear();

      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      final List<String> issued = List<String>.of(recorder.log);

      expect(issued.first, 'begin', reason: issued.toString());
      expect(issued.last, 'commit', reason: issued.toString());
      expect(issued.where((String e) => e == 'begin'), hasLength(1));
      expect(issued.where((String e) => e == 'commit'), hasLength(1));

      final int check = issued.indexWhere(
        (String e) => e.startsWith('select:') && e.contains('schedules'),
      );
      final int insert = issued.indexWhere(
        (String e) => e.startsWith('insert:'),
      );
      expect(check, greaterThan(0), reason: issued.toString());
      expect(
        insert,
        greaterThan(check),
        reason: 'the clash check has to precede the insert it guards',
      );
      expect(issued.indexOf('commit'), greaterThan(insert));
    });

    test('saveSchedule: begin, the checks, the update, commit', () async {
      final Medicine medicine = await addMedicine();
      final Schedule schedule = await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      recorder.clear();

      await repository.saveSchedule(schedule.copyWith(dosageAmount: 2));
      final List<String> issued = List<String>.of(recorder.log);

      expect(issued.first, 'begin', reason: issued.toString());
      expect(issued.last, 'commit', reason: issued.toString());
      expect(issued.where((String e) => e == 'begin'), hasLength(1));

      final int update = issued.indexWhere(
        (String e) => e.startsWith('update:'),
      );
      expect(update, greaterThan(0), reason: issued.toString());
      expect(issued.indexOf('commit'), greaterThan(update));
    });

    test('a rejected addSchedule rolls back rather than committing', () async {
      final Medicine medicine = await addMedicine();
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
      );
      recorder.clear();

      await expectLater(
        repository.addSchedule(
          medicineId: medicine.id,
          timeOfDay: '08:00',
          ianaTimezone: 'Asia/Colombo',
          frequency: Frequency.everyDay,
          dosageAmount: 1,
        ),
        throwsA(isA<DuplicateScheduleFailure>()),
      );
      final List<String> issued = List<String>.of(recorder.log);

      expect(issued, contains('rollback'), reason: issued.toString());
      expect(issued, isNot(contains('commit')));
      expect(recorder.inserts, isEmpty);
    });

    test('addMedicine: begin, the count, the insert, commit', () async {
      recorder.clear();
      await addMedicine();
      final List<String> issued = List<String>.of(recorder.log);

      final int begin = issued.indexOf('begin');
      final int commit = issued.indexOf('commit');
      final int count = issued.indexWhere(
        (String entry) =>
            entry.startsWith('select:') &&
            entry.toUpperCase().contains('COUNT('),
      );
      final int insert = issued.indexWhere(
        (String entry) => entry.startsWith('insert:'),
      );

      expect(begin, isNonNegative, reason: issued.toString());
      expect(count, greaterThan(begin));
      expect(insert, greaterThan(count));
      expect(
        commit,
        greaterThan(insert),
        reason:
            'a count read outside the transaction is a read-modify-write: two '
            'medicines added in the same moment would read the same count and '
            'be handed the same glyph',
      );
    });
  });

  group('schedulesFor breaks a tie the same way every time', () {
    // D7. The order test used three distinct times, so the secondary
    // `OrderingTerm` on `id` never ran and could be deleted with the suite
    // green. Two Schedules at the same time on disjoint days are a legitimate
    // pair -- the PRD's own example -- so the tie is reachable.

    test('two schedules at the same time come back in id order', () async {
      final Medicine medicine = await addMedicine();
      // Ids are minted in call order, so 'id-3' is created before 'id-2' here
      // only if the calls are made in that order -- instead, name them
      // explicitly by driving the generator.
      nextId = 8; // the next mint is 'id-9'
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.monday},
        dosageAmount: 1,
      );
      nextId = 1; // the next mint is 'id-2'
      await repository.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.tuesday},
        dosageAmount: 1,
      );

      expect(
        (await repository.schedulesFor(
          medicine.id,
        )).map((Schedule s) => s.id).toList(),
        equals(<String>['id-2', 'id-9']),
        reason:
            'inserted 9 then 2; without the id tie-break the order is '
            'whatever the query planner chose this run',
      );
    });

    test('the tie-break is ASKED for, not assumed', () async {
      // Same reasoning as the insertion-order test above: SQLite happens to
      // return insertion order for tied rows today, so the only observable
      // difference is the statement.
      final Medicine medicine = await addMedicine();
      recorder.clear();
      await repository.schedulesFor(medicine.id);

      expect(
        recorder.log.single,
        contains('ORDER BY "time_of_day" ASC, "id" ASC'),
        reason:
            'the time first, then the id -- a tie has to resolve to something '
            'stable or two reads of the same data can disagree',
      );
    });
  });
}

/// A raw `medicines` insert, used to plant a row the repository would refuse.
///
/// The schema's `CHECK` constraints stop most malformed values at the door, so
/// a test about what happens when a bad row EXISTS has to write a good one and
/// then update the column -- which is also the only way a bad row could arrive
/// in production: a raw statement, or a file touched outside the app.
String _rawMedicine(String id, String startDate) =>
    'INSERT INTO medicines (id, name, glyph_index, form, dosage_amount, '
    'dosage_unit, start_date) '
    "VALUES ('$id', 'Metformin', 0, 'tablet', 1.0, 'tablet', '$startDate')";
