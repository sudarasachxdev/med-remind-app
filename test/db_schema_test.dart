// The schema of version 1, pinned (AD-15).
//
// AD-15 requires every schema change to bump `schemaVersion`, ship a migration
// and ship a schema test. Version 1 is creation rather than change, so there is
// no migration yet -- but there is a schema, and Story 1.4's move to version 2
// has to migrate FROM something. This is that something, asserted rather than
// assumed: the table set, every column, its type, its nullability, its default
// and its constraints, read back out of SQLite after `createAll` rather than
// out of the Dart that generated it.
//
// It is not drift's generated fixture verifier (`drift_dev schema dump` /
// `schema generate`). That machinery compares a live database against a dumped
// snapshot of an OLD version, which is what makes it worth having the moment a
// second version exists -- Story 1.4 should add it with the first real
// migration. With one version there is nothing to compare against, and a
// snapshot of the only schema there is would be a copy of the file above it.
//
// This also pins the story's scope: `app_settings` is the ONLY table. Medicine,
// Schedule and Dose belong to Stories 1.4 and 1.7, and a test that names the
// whole table set fails the day one of them arrives early.

import 'dart:io';

import 'package:drift/drift.dart';
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

  group('AppDatabase at schema version 1', () {
    test('declares version 1', () {
      expect(database.schemaVersion, 1);
    });

    test('creates exactly one table, and it is the settings table', () async {
      final List<String> tables = await _tableNames(database);

      expect(
        tables,
        equals(<String>['app_settings']),
        reason:
            'Story 1.3 owns one table. Medicine, Schedule and Dose belong to '
            'Stories 1.4 and 1.7; if one of them is here, scope has leaked.',
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
          throwsA(isA<Object>()),
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

        expect(rows.single.data['user_version'], 1);
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
      expect(production.schemaVersion, 1);
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

      // A file written by a future build: schema version 2.
      final AppDatabase future = AppDatabase(NativeDatabase(file));
      await future.customSelect('SELECT 1').get();
      await future.customStatement('PRAGMA user_version = 2');
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
                2,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.appVersion,
                'appVersion',
                1,
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
        storedVersion: 2,
        appVersion: 1,
      );
      expect(downgrade.isDowngrade, isTrue);
      expect(
        downgrade.toString(),
        contains(AppDatabaseVersionMismatch.downgradeAdvice),
      );

      const missingMigration = AppDatabaseVersionMismatch(
        storedVersion: 1,
        appVersion: 2,
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
      await future.customStatement('PRAGMA user_version = 2');
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
        1,
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
