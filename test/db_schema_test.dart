// The schema of version 2, pinned (AD-15).
//
// AD-15 requires every schema change to bump `schemaVersion`, ship a migration
// and ship a schema test. This file is the schema half: the table set, every
// column, its type, its nullability, its default and its constraints, read back
// out of SQLite after the database opens rather than out of the Dart that
// generated it. `test/db_migration_test.dart` is the migration half -- it runs
// drift's generated fixture verifier, which Story 1.3 could not add because
// one version has nothing to compare against.
//
// The two files answer different questions and both are needed. The verifier
// proves the migrated and the freshly-created schema AGREE; it says nothing
// about whether the shape they agree on is the right one. That is what the
// assertions below are for -- in particular AD-6, which is a claim about a
// column that must NOT exist, and which no comparison of two schemas to each
// other could ever catch.
//
// This also pins the story's scope: `app_settings`, `medicines` and `schedules`
// are the ONLY tables. `doses` belongs to Story 1.7, and the table-set test
// fails the day it arrives early.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
// `SqliteException` comes through drift's own native export rather than from
// `package:sqlite3` directly: sqlite3 is a transitive dependency here, not a
// declared one, and importing it directly would be reaching past the
// dependency this project actually pins.
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';

void main() {
  // `_mockApplicationDocumentsDirectory` needs the binding, and so does any
  // test that touches a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase at schema version 2', () {
    test('declares version 2', () {
      expect(
        database.schemaVersion,
        2,
        reason:
            'AD-15: adding medicines and schedules is a schema change, so the '
            'version bumps. Leaving it at 1 would mean an installed app never '
            'calls onUpgrade and runs the new code against the old schema.',
      );
    });

    test('creates exactly three tables and no fourth', () async {
      final List<String> tables = await _tableNames(database);

      expect(
        tables,
        equals(<String>['app_settings', 'medicines', 'schedules']),
        reason:
            'Story 1.4 owns medicines and schedules. `doses` belongs to Story '
            '1.7, which needs the escalation policy Story 1.6 has not written '
            'yet; if it is here, scope has leaked.',
      );
    });

    test('app_settings holds exactly id and onboarding_completed', () async {
      final List<Map<String, Object?>> columns = await _tableInfo(
        database,
        'app_settings',
      );

      expect(
        columns.map((Map<String, Object?> c) => c['name']).toList(),
        equals(<String>['id', 'onboarding_completed']),
      );

      final Map<String, Object?> id = columns.first;
      expect(id['type'], 'INTEGER');
      expect(id['notnull'], 1, reason: 'the settings row must have an id');
      expect(id['pk'], 1, reason: 'id is the primary key');
      expect(
        id['dflt_value'],
        '$appSettingsRowId',
        reason: 'a row inserted without an id is the settings row',
      );

      final Map<String, Object?> flag = columns.last;
      expect(
        flag['type'],
        'INTEGER',
        reason: 'SQLite has no boolean; drift stores it as 0/1',
      );
      expect(flag['notnull'], 1);
      expect(
        flag['dflt_value'],
        '0',
        reason:
            'a settings row written for some other setting must not claim '
            'onboarding was seen',
      );
    });

    test(
      'the single-row rule is in the schema, not just in the code',
      () async {
        final String sql = await _createStatement(database, 'app_settings');

        expect(
          sql,
          contains('CHECK("id" = $appSettingsRowId)'),
          reason:
              'One row is enforced by the schema so a second one is impossible '
              'rather than merely unwritten.',
        );

        // And it bites: a second row is rejected by SQLite, not by a convention
        // two readers could disagree about.
        await expectLater(
          database.customStatement(
            'INSERT INTO app_settings (id, onboarding_completed) VALUES (2, 0)',
          ),
          throwsA(_aCheckConstraintFailure),
          reason:
              'named rather than `isA<Object>()`, which would also pass if the '
              'CHECK were gone and this statement merely had a typo',
        );
      },
    );

    test('the boolean column only admits 0 and 1', () async {
      final String sql = await _createStatement(database, 'app_settings');
      expect(sql, contains('CHECK ("onboarding_completed" IN (0, 1))'));
    });

    test('a fresh database is empty, not pre-seeded as completed', () async {
      final List<QueryRow> rows = await database
          .customSelect('SELECT * FROM app_settings')
          .get();

      expect(
        rows,
        isEmpty,
        reason:
            'No row at all is the fresh-install state. The adapter reads that '
            'as "not completed"; nothing seeds a row that could say otherwise.',
      );
    });

    test(
      'the version is written into the file, not just held in memory',
      () async {
        // Drift records the version in SQLite's own `user_version` pragma. If it
        // is not written, `onUpgrade` never fires and Story 1.4's migration
        // silently does not run.
        final List<QueryRow> rows = await database
            .customSelect('PRAGMA user_version')
            .get();

        expect(rows.single.data['user_version'], 2);
      },
    );

    test('foreign keys are enforced on the connection', () async {
      // SQLite defaults this to OFF, per connection. Story 1.4's `schedules`
      // table is the first with a foreign key, and AD-12's cascade-in-one-
      // transaction promise is only kept by the database while this is on.
      final List<QueryRow> rows = await database
          .customSelect('PRAGMA foreign_keys')
          .get();

      expect(rows.single.data['foreign_keys'], 1);
    });
  });

  group('the on-device file', () {
    // The in-memory tests above say nothing about WHERE the app looks, and a
    // review pass renamed `appDatabaseName` to 'meditracker_renamed' with the
    // whole suite still green. On an upgraded install that opens a different,
    // empty file: the onboarding flag reads unset, and from Story 1.4 the
    // user's entire medicine and dose history becomes invisible. There is no
    // cloud copy by design, so there is nothing to fall back on.

    test('is named meditracker', () {
      expect(
        appDatabaseName,
        'meditracker',
        reason:
            'Renaming this orphans every existing install: the app opens an '
            'empty file and the user\'s whole history becomes invisible, with '
            'no cloud copy to restore from. If it must change, it changes '
            'together with a migration that moves the old file.',
      );
    });

    test('is what the no-argument constructor opens', () async {
      // The production path, exercised. `drift_flutter` joins
      // `$appDatabaseName.sqlite` onto the application documents directory, so
      // pointing path_provider at a temp directory makes the real filename
      // observable.
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_db_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      _mockApplicationDocumentsDirectory(directory.path);

      final AppDatabase production = AppDatabase();
      addTearDown(production.close);
      // Nothing is opened until the first query.
      await production.customSelect('SELECT 1').get();

      expect(
        File('${directory.path}/$appDatabaseName.sqlite').existsSync(),
        isTrue,
        reason:
            'The file the app actually creates must be the one a previous '
            'install left behind. Found: '
            '${directory.listSync().map((FileSystemEntity e) => e.uri.pathSegments.last).toList()}',
      );
      expect(production.schemaVersion, 2);
    });
  });

  group('a version mismatch is named, not left to drift', () {
    // Drift calls `onUpgrade` for ANY mismatch, and its default implementation
    // throws "you didn't provide a strategy for schema updates" -- true of a
    // forward step, misleading about a backward one. A downgraded build would
    // meet that message on every open, for ever, with nothing naming the
    // actual situation.

    test('a file from a newer build is reported as a downgrade', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_downgrade',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/db.sqlite');

      // A file written by a future build: schema version 3. It has to be
      // ABOVE this build's version, and this build is now at 2 -- a test that
      // kept writing 2 here would silently stop testing a downgrade the moment
      // the app reached that version, which is what happened to this line in
      // this very story.
      final AppDatabase future = AppDatabase(NativeDatabase(file));
      await future.customSelect('SELECT 1').get();
      await future.customStatement('PRAGMA user_version = 3');
      await future.close();

      final AppDatabase current = AppDatabase(NativeDatabase(file));
      addTearDown(current.close);

      await expectLater(
        current.customSelect('SELECT 1').get(),
        throwsA(
          isA<AppDatabaseVersionMismatch>()
              .having(
                (AppDatabaseVersionMismatch e) => e.storedVersion,
                'storedVersion',
                3,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.appVersion,
                'appVersion',
                2,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.isDowngrade,
                'isDowngrade',
                isTrue,
              ),
        ),
      );
    });

    test('the two directions read differently', () {
      const downgrade = AppDatabaseVersionMismatch(
        storedVersion: 3,
        appVersion: 2,
      );
      expect(downgrade.isDowngrade, isTrue);
      expect(
        downgrade.toString(),
        contains(AppDatabaseVersionMismatch.downgradeAdvice),
      );

      const missingMigration = AppDatabaseVersionMismatch(
        storedVersion: 1,
        appVersion: 3,
      );
      expect(missingMigration.isDowngrade, isFalse);
      expect(
        missingMigration.toString(),
        contains(AppDatabaseVersionMismatch.missingMigrationAdvice),
      );
    });

    test('the message names both versions and says nothing was changed', () {
      const mismatch = AppDatabaseVersionMismatch(
        storedVersion: 7,
        appVersion: 3,
      );

      expect(mismatch.toString(), contains('7'));
      expect(mismatch.toString(), contains('3'));
      expect(
        mismatch.toString(),
        contains('No data has been changed'),
        reason:
            'The first question anyone reading this asks is whether their '
            'record survived. Answer it in the message.',
      );
    });

    test('a downgrade is never recovered by recreating the file', () async {
      // "deleteOnFailure"-style recovery is prohibited by the spine. The file
      // must still be there, untouched, after a failed open.
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_no_delete',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/db.sqlite');

      final AppDatabase future = AppDatabase(NativeDatabase(file));
      await future.customSelect('SELECT 1').get();
      await future.customStatement(
        'CREATE TABLE a_table_from_the_future (x INTEGER)',
      );
      await future.customStatement('PRAGMA user_version = 3');
      await future.close();
      final int sizeBefore = file.lengthSync();

      final AppDatabase current = AppDatabase(NativeDatabase(file));
      addTearDown(current.close);
      await expectLater(
        current.customSelect('SELECT 1').get(),
        throwsA(isA<AppDatabaseVersionMismatch>()),
      );

      expect(file.existsSync(), isTrue);
      expect(
        file.lengthSync(),
        sizeBefore,
        reason: 'a health record with no cloud copy is never discarded',
      );
    });
  });

  group('medicines — the aggregate root (AD-12)', () {
    test('holds exactly the ERD\'s eleven columns', () async {
      expect(
        await _columnShapes(database, 'medicines'),
        equals(<String>[
          'id TEXT notnull',
          'name TEXT notnull',
          'condition TEXT nullable',
          'glyph_index INTEGER notnull',
          'form TEXT notnull',
          'dosage_amount REAL notnull',
          'dosage_unit TEXT notnull',
          'instructions TEXT nullable',
          'start_date TEXT notnull',
          'end_date TEXT nullable',
          'active INTEGER notnull',
        ]),
        reason:
            'The spine\'s ERD is the contract. A column added here without a '
            'schema bump would be invisible to an installed app, and a column '
            'missing here is a field Story 1.5 cannot save.',
      );
    });

    test('id is the primary key and nothing else is', () async {
      final List<Map<String, Object?>> columns = await _tableInfo(
        database,
        'medicines',
      );
      final Iterable<String> keys = columns
          .where((Map<String, Object?> c) => (c['pk'] as int) > 0)
          .map((Map<String, Object?> c) => c['name'] as String);

      expect(keys, equals(<String>['id']));
    });

    test('active defaults to true', () async {
      final Map<String, Object?> active = (await _tableInfo(
        database,
        'medicines',
      )).last;

      expect(active['name'], 'active');
      expect(
        active['dflt_value'],
        '1',
        reason: 'a medicine is added in order to take it',
      );
    });

    test('a date is shape-checked in the schema, not just in the code', () async {
      // A `dateTime()` column would store Unix seconds -- a UTC instant -- and
      // "started on the 1st" would read as the 31st for every user east of UTC
      // whose row was written after 18:30 local. So the column is text, and
      // this is what makes `YYYY-MM-DD` a rule rather than a convention.
      //
      // A LENGTH check was the first version of this and was not enough:
      // '2026-13-45' is ten characters, and `DateTime(2026, 13, 45)` rolls
      // over to 2027-02-14 without complaint, so a start date moved five
      // months with nothing anywhere reporting it.
      final String sql = await _createStatement(database, 'medicines');

      expect(sql, contains("GLOB '$isoDateGlob'"));
      expect(
        RegExp("GLOB '${RegExp.escape(isoDateGlob)}'").allMatches(sql).length,
        2,
        reason: 'both start_date and end_date carry it, not just the first',
      );
      expect(sql, contains('"end_date" TEXT NULL CHECK'));
    });

    test('a well-formed date is accepted — the positive control', () async {
      // Without this, every rejection below is equally green with the
      // constraint absent and a typo in the test's own SQL.
      await database.customStatement(_insertMedicine);

      final List<QueryRow> rows = await database
          .customSelect('SELECT start_date FROM medicines')
          .get();
      expect(rows.single.data['start_date'], '2026-09-07');
    });

    test('a malformed date is rejected by SQLite itself', () async {
      // `isA<SqliteException>()` with the constraint named, not
      // `isA<Object>()`: a matcher that accepts any thrown object is green
      // when the CHECK is gone and the statement below merely has a typo,
      // which is the failure mode this narrowing exists to remove.
      for (final String date in <String>[
        '2026-9-7',
        '2026-13-45',
        '07-09-2026',
        '2026/09/07',
        'not-a-date',
        '',
      ]) {
        await expectLater(
          database.customStatement(
            _insertMedicine.replaceFirst('2026-09-07', date),
          ),
          throwsA(_aCheckConstraintFailure),
          reason: '"$date" is not a calendar date',
        );
      }
    });

    test('an end date is checked the same way as a start date', () async {
      await expectLater(
        database.customStatement(
          _insertMedicine
              .replaceFirst(', start_date)', ', start_date, end_date)')
              .replaceFirst("'2026-09-07')", "'2026-09-07', '2026-13-45')"),
        ),
        throwsA(_aCheckConstraintFailure),
      );
    });
  });

  group('schedules — wall clock plus a zone, and no instant (AD-6)', () {
    test('holds exactly the ERD\'s nine columns', () async {
      expect(
        await _columnShapes(database, 'schedules'),
        equals(<String>[
          'id TEXT notnull',
          'medicine_id TEXT notnull',
          'time_of_day TEXT notnull',
          'iana_timezone TEXT notnull',
          'frequency TEXT notnull',
          'days_of_week TEXT nullable',
          'interval_days INTEGER nullable',
          'dosage_amount REAL notnull',
          'reminder_override TEXT nullable',
        ]),
        reason:
            'Nine columns, and the list is exhaustive on purpose: a tenth '
            'holding the same time in another form is the AD-6 violation this '
            'test exists to catch.',
      );
    });

    test('a time is shape-checked in the schema', () async {
      final String sql = await _createStatement(database, 'schedules');
      expect(sql, contains("GLOB '$timeOfDayGlob'"));
    });

    test('a well-formed time is accepted, a malformed one is not', () async {
      await database.customStatement(_insertMedicine);
      await database.customStatement(_insertSchedule);

      final List<QueryRow> rows = await database
          .customSelect('SELECT time_of_day FROM schedules')
          .get();
      expect(
        rows.single.data['time_of_day'],
        '08:00',
        reason: 'the positive control: 08:00 has to be storable',
      );

      for (final String time in <String>['8:00', '99:99', '0800', '08:0', '']) {
        await expectLater(
          database.customStatement(
            _insertSchedule
                .replaceFirst("'s1'", "'s-$time'")
                .replaceFirst("'08:00'", "'$time'"),
          ),
          throwsA(_aCheckConstraintFailure),
          reason: '"$time" is not a 24-hour wall clock',
        );
      }
    });

    test('no table anywhere holds a UTC instant (AD-6)', () async {
      // The decision is about a column that must NOT exist, so the test has to
      // look at the whole schema rather than at a list of expected columns --
      // a `scheduled_utc` added to a fourth table would satisfy every
      // assertion above. "Every day at 8:00" survives a DST transition only
      // while 8:00 is what was stored; an instant computed once at creation
      // drifts by an hour twice a year, which is the failure class the PRD
      // found in competitor app-store reviews.
      //
      // Story 1.7's `doses` table is the one place a UTC instant is allowed,
      // as a denormalised ordering column. When it arrives, this test moves to
      // exempting that one column by name -- it does not get deleted.
      const List<String> instantish = <String>[
        'utc',
        'epoch',
        'instant',
        'millis',
        'micros',
        'unix',
        'timestamp',
      ];

      // Names that mean "a moment", however they are spelled. The first
      // version of this test banned only the list above and required TEXT of
      // any name containing `time` or `date` -- which an INTEGER column called
      // `scheduled_at`, `fires_at` or `next_at` satisfies completely, and
      // those are the names a denormalised instant actually arrives under.
      final RegExp momentish = RegExp(
        r'(^|_)(at|when|moment|clock|due|fires|next|since|until)($|_)'
        r'|time|date|schedul',
      );

      for (final String table in await _tableNames(database)) {
        for (final Map<String, Object?> column in await _tableInfo(
          database,
          table,
        )) {
          final String name = (column['name'] as String).toLowerCase();
          for (final String banned in instantish) {
            expect(
              name,
              isNot(contains(banned)),
              reason:
                  '$table.$name looks like a UTC instant. AD-6: a Schedule '
                  'stores a wall clock and an IANA zone, and the product\'s '
                  'only UTC value is Story 1.7\'s Dose ordering column.',
            );
          }

          // And nothing that names a moment may be numeric: an INTEGER
          // `time_of_day`, `fires_at` or `next_due` is an epoch or an offset
          // however it was spelled. TEXT is not proof that a column holds a
          // wall clock, but a number is proof that it does not.
          if (momentish.hasMatch(name)) {
            expect(
              column['type'],
              'TEXT',
              reason:
                  '$table.$name names a moment and is ${column['type']}. A '
                  'number here is an instant or an offset, not a wall clock. '
                  'Story 1.7\'s doses.scheduled_utc is the single exception '
                  'the product allows, and this is not that table.',
            );
          }
        }
      }
    });

    test('the medicine reference is a foreign key that bites', () async {
      final String sql = await _createStatement(database, 'schedules');
      expect(
        sql,
        contains('REFERENCES medicines'),
        reason: 'AD-12: a Schedule has no life without its Medicine',
      );
      expect(
        sql,
        contains('ON DELETE CASCADE'),
        reason:
            'the database\'s own guarantee for any write path, including a '
            'raw statement that bypasses the repository',
      );

      // Declared is not enforced: SQLite ignores every foreign key unless the
      // connection has `PRAGMA foreign_keys = ON`, which `beforeOpen` sets.
      await expectLater(
        database.customStatement(
          _insertSchedule.replaceFirst("'m1'", "'no-such-medicine'"),
        ),
        throwsA(
          isA<SqliteException>().having(
            (SqliteException e) => e.message,
            'message',
            contains('FOREIGN KEY constraint failed'),
          ),
        ),
        reason:
            'An orphan Schedule is a reminder for a medicine the user cannot '
            'see. Rejected by the key, not by a convention in the repository '
            '-- and the message has to name the key rather than merely being '
            'some thrown object, or a typo in the statement above would look '
            'the same.',
      );

      // The positive control. The same statement against a Medicine that
      // exists must succeed, or the rejection proves only that the statement
      // was broken.
      await database.customStatement(_insertMedicine);
      await database.customStatement(_insertSchedule);
      final List<QueryRow> accepted = await database
          .customSelect('SELECT id FROM schedules')
          .get();
      expect(accepted.single.data['id'], 's1');
    });

    test('the cascade removes the schedules when the medicine goes', () async {
      await database.customStatement(_insertMedicine);
      await database.customStatement(_insertSchedule);

      await database.customStatement("DELETE FROM medicines WHERE id = 'm1'");

      final List<QueryRow> left = await database
          .customSelect('SELECT id FROM schedules')
          .get();
      expect(left, isEmpty);
    });
  });

  group('completion survives a real reopen', () {
    test('a flag written to a file is read back after closing it', () async {
      // The in-memory tests cannot show this: they hold one connection for the
      // whole test, so "reopen" would be a second read of a live handle. Story
      // 1.4's `onUpgrade` depends on the persistence this claims to prove, and
      // so does every relaunch of the app.
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_reopen',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/db.sqlite');

      final AppDatabase first = AppDatabase(NativeDatabase(file));
      await first.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 1)',
      );
      await first.close();

      expect(file.existsSync(), isTrue);

      final AppDatabase second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);

      final List<QueryRow> rows = await second
          .customSelect('SELECT onboarding_completed FROM app_settings')
          .get();
      expect(rows.single.data['onboarding_completed'], 1);

      final List<QueryRow> version = await second
          .customSelect('PRAGMA user_version')
          .get();
      expect(
        version.single.data['user_version'],
        2,
        reason:
            'the version has to come back off disk, or onUpgrade never fires',
      );
    });
  });
}

/// Points `path_provider` at [path] for the rest of the test.
///
/// `drift_flutter` reaches `getApplicationDocumentsDirectory()` to place the
/// database file. Mocking the channel is what makes the real production path --
/// `AppDatabase()` with no argument -- runnable off a device.
void _mockApplicationDocumentsDirectory(String path) {
  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async => path);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

Future<List<String>> _tableNames(AppDatabase database) async {
  final List<QueryRow> rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return rows.map((QueryRow row) => row.read<String>('name')).toList();
}

Future<List<Map<String, Object?>>> _tableInfo(
  AppDatabase database,
  String table,
) async {
  final List<QueryRow> rows = await database
      .customSelect('PRAGMA table_info($table)')
      .get();
  return rows.map((QueryRow row) => row.data).toList();
}

Future<String> _createStatement(AppDatabase database, String table) async {
  final List<QueryRow> rows = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: <Variable<Object>>[Variable<String>(table)],
      )
      .get();
  return rows.single.read<String>('sql');
}

/// Every column of [table] as `name TYPE notnull|nullable`, in schema order.
///
/// One string per column rather than a map so a single `equals` names the
/// column set, the declared types and the nullability at once, and the failure
/// message shows the whole shape rather than the first difference.
Future<List<String>> _columnShapes(AppDatabase database, String table) async {
  final List<Map<String, Object?>> columns = await _tableInfo(database, table);
  return columns
      .map(
        (Map<String, Object?> c) =>
            '${c['name']} ${c['type']} '
            '${c['notnull'] == 1 ? 'notnull' : 'nullable'}',
      )
      .toList();
}

/// One well-formed `medicines` row, as raw SQL.
///
/// Shared, so that each rejection test is the SAME statement as the acceptance
/// test with one value swapped. That is what makes a rejection evidence about
/// the constraint rather than about a typo in the test.
const String _insertMedicine =
    'INSERT INTO medicines (id, name, glyph_index, form, dosage_amount, '
    'dosage_unit, start_date) '
    "VALUES ('m1', 'Metformin', 0, 'tablet', 1.0, 'tablet', '2026-09-07')";

/// One well-formed `schedules` row on `m1`. See [_insertMedicine].
const String _insertSchedule =
    'INSERT INTO schedules (id, medicine_id, time_of_day, iana_timezone, '
    'frequency, dosage_amount) '
    "VALUES ('s1', 'm1', '08:00', 'Asia/Colombo', 'everyDay', 1.0)";

/// SQLite refused the statement because a `CHECK` constraint failed.
///
/// Narrower than `isA<Object>()` on purpose: a matcher that accepts anything
/// thrown is green when the constraint has been removed and the statement is
/// merely malformed, so it proves nothing about the schema.
final Matcher _aCheckConstraintFailure = isA<SqliteException>().having(
  (SqliteException e) => e.message,
  'message',
  contains('CHECK constraint failed'),
);
