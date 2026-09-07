// The migration half of AD-15: version 1 becomes version 2 without losing a
// row, and both ways of arriving at version 2 agree.
//
// `test/db_schema_test.dart` pins what the schema IS. This file pins how an
// installed app gets there. The two questions are different, and only this one
// can be answered against a real v1 snapshot: the fixtures under
// `drift_schemas/` were dumped by `drift_dev schema dump` from the code as it
// stood, v1 from the version Story 1.3 shipped and v2 from this story's, so the
// v1 database these tests start from is the one on a user's phone rather than
// the one today's Dart would create. A fixture regenerated from current code
// would make every test below vacuous -- it would compare the new schema with
// itself -- which is why `the v1 fixture is still Story 1.3's` reads the JSON
// and asserts its contents.
//
// Two paths reach version 2 and both must exist (the spec's "Both paths
// agree"): `onCreate` for a fresh install and `onUpgrade` for an existing one.
// Rewriting `onCreate` to include the new tables INSTEAD of migrating would
// pass a naive schema test and hard-fail every phone that already has the app.
//
// ---------------------------------------------------------------------------
// REGENERATING THE FIXTURES -- read before you do.
//
//   1. Dump the schema of the version you are ADDING, and only that one:
//        dart run drift_dev schema dump lib/data/db/app_database.dart \
//            drift_schemas/
//      It writes `drift_schema_v<schemaVersion>.json`. Never re-dump an older
//      version -- see `the v1 fixture is still Story 1.3's` below for what
//      that silently does to every test in this file.
//
//   2. Patch the dumped `default_dart` for `app_settings.id` from
//      `const Constant(appSettingsRowId)` to `const Constant(1)`. Measured
//      against drift_dev 2.34.6 on 2026-09-07: `AppDatabase` imports
//      `drift_flutter`, which reaches `dart:ui`, so the dump cannot run the
//      database code and falls back to static analysis. In that path drift
//      emits a `default_dart` expression verbatim, WITHOUT the import prefix
//      it attaches to a `check` expression -- so step 3 generates
//      `const Constant(appSettingsRowId)` into a file that does not import
//      that constant, and the fixture will not compile. The two forms are the
//      same schema: `appSettingsRowId` is 1, and `test/db_schema_test.dart`
//      pins that the column's default equals the named constant.
//
//   3. Generate the helpers the tests import:
//        dart run drift_dev schema generate drift_schemas/ \
//            test/generated_migrations/
//
//   4. Any constant a table's `check` or default refers to must be PUBLIC --
//      `isoDateLength`, `timeOfDayLength`, `appSettingsRowId`. The generated
//      fixture references them through an import prefix, and a private one is
//      not visible there.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

/// This build, but claiming a schema version no migration step reaches.
///
/// The missing-migration branch of `AppDatabaseVersionMismatch` was
/// unreachable in Story 1.3, and at version 2 it is *still* unreachable
/// through the ordinary constructor: the only gap below 2 is 1 -> 2, which is
/// the step this story added, and 0 means "no database yet" and routes to
/// `onCreate`. Naming a third version is what makes the branch observable
/// without waiting for Story 1.7 to add one -- and it exercises the real
/// `migration` getter, not a copy of its logic.
final class _AppDatabaseClaimingVersion3 extends AppDatabase {
  _AppDatabaseClaimingVersion3(super.executor);

  @override
  int get schemaVersion => 3;
}

void main() {
  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('the generated fixtures', () {
    test('the v1 fixture is still Story 1.3\'s, not a copy of today\'s', () {
      // The manual check the spec asks for, as a test. If someone re-dumps v1
      // from current code the file gains `medicines` and `schedules`, every
      // migration test below starts from the schema it is trying to prove the
      // migration produces, and all of them pass while proving nothing.
      final File fixture = File('drift_schemas/drift_schema_v1.json');
      expect(
        fixture.existsSync(),
        isTrue,
        reason:
            'Regenerate with: dart run drift_dev schema dump '
            'lib/data/db/app_database.dart drift_schemas/ -- from the v1 '
            'sources, not from these.',
      );

      final Map<String, Object?> json =
          jsonDecode(fixture.readAsStringSync()) as Map<String, Object?>;
      final List<String> tables = (json['entities']! as List<Object?>)
          .map(
            (Object? entity) =>
                ((entity! as Map<String, Object?>)['data']!
                        as Map<String, Object?>)['name']!
                    as String,
          )
          .toList();

      expect(
        tables,
        equals(<String>['app_settings']),
        reason:
            'Version 1 had exactly one table. A v1 fixture holding medicines '
            'or schedules was dumped from this story\'s code and makes every '
            'migration test in this file vacuous.',
      );
    });

    test('both versions are known to the helper', () {
      expect(GeneratedHelper.versions, equals(<int>[1, 2]));
    });
  });

  group('1 -> 2 (the spec\'s "Migrate" row)', () {
    test('migrating a real v1 database yields the v2 schema', () async {
      // The heart of AD-15. `migrateAndValidate` opens the database, runs the
      // real `migration` strategy, then reads `sqlite_schema` back and
      // compares it against the v2 fixture -- so this asserts the migration
      // produced the schema, rather than asserting that it ran.
      final DatabaseConnection connection = await verifier.startAt(1);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        2,
        // Strict: a table, view or trigger left behind by the migration fails
        // too, not only a missing one. Off by default, and this story is the
        // one that decides whether migration discipline is real.
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('the onboarding flag survives (never recreate the file)', () async {
      // The data-loss test. An installed app is carrying a completed
      // onboarding flag in `app_settings`; a migration that dropped and
      // recreated the database -- or an `onCreate` pressed into service as an
      // upgrade -- would lose it, on the story whose whole subject is not
      // losing data.
      final InitializedSchema schema = await verifier.schemaAt(1);
      addTearDown(schema.close);

      final v1.DatabaseAtV1 old = v1.DatabaseAtV1(schema.newConnection());
      await old.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 1)',
      );
      await old.close();

      final AppDatabase migrated = AppDatabase(schema.newConnection());
      addTearDown(migrated.close);

      final List<QueryRow> flag = await migrated
          .customSelect('SELECT onboarding_completed FROM app_settings')
          .get();
      expect(
        flag.single.data['onboarding_completed'],
        1,
        reason:
            'The user completed onboarding before the update. Showing it '
            'again would be the mildest form of this bug; the same mistake '
            'loses the medicine list from Story 1.5 onwards.',
      );

      // And the migration actually happened, rather than the read succeeding
      // against an untouched v1 file.
      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 2);

      for (final String table in <String>['medicines', 'schedules']) {
        final List<QueryRow> rows = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              'AND name = ?',
              variables: <Variable<Object>>[Variable<String>(table)],
            )
            .get();
        expect(rows, hasLength(1), reason: '$table should exist after 1 -> 2');
      }
    });

    test('the migrated schema is identical to a fresh one', () async {
      // The spec's "Both paths agree" row, asserted directly rather than
      // through the fixture: the CREATE statements SQLite itself holds for a
      // database born at 2 and for one that walked 1 -> 2, compared as text.
      //
      // `migrateAndValidate` above compares each path against the fixture,
      // which is the stronger check of the two in one direction and says
      // nothing in the other -- it never opens a fresh database at all. This
      // one would catch a divergence that the fixture happened to tolerate.
      final DatabaseConnection connection = await verifier.startAt(1);
      final AppDatabase migrated = AppDatabase(connection);
      addTearDown(migrated.close);
      final List<String> migratedSchema = await _schemaSql(migrated);

      final AppDatabase fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      final List<String> freshSchema = await _schemaSql(fresh);

      expect(
        migratedSchema,
        equals(freshSchema),
        reason:
            'A phone that upgraded and a phone that installed today must be '
            'running the same schema. If these differ, one of onCreate and '
            'onUpgrade was changed without the other.',
      );
      // Guards the comparison itself: two empty lists are equal.
      expect(freshSchema, hasLength(3));
    });
  });

  group('a gap with no migration step (the spec\'s "Version gap" row)', () {
    test('names the missing migration and changes nothing', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'meditracker_missing_migration',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/db.sqlite');

      // A genuine v1 file on disk, built from the v1 fixture rather than from
      // today's tables.
      final v1.DatabaseAtV1 old = v1.DatabaseAtV1(NativeDatabase(file));
      await old.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 1)',
      );
      await old.close();
      final int sizeBefore = file.lengthSync();

      final AppDatabase build = _AppDatabaseClaimingVersion3(
        NativeDatabase(file),
      );
      addTearDown(build.close);

      await expectLater(
        build.customSelect('SELECT 1').get(),
        throwsA(
          isA<AppDatabaseVersionMismatch>()
              .having(
                (AppDatabaseVersionMismatch e) => e.storedVersion,
                'storedVersion',
                1,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.appVersion,
                'appVersion',
                3,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.isDowngrade,
                'isDowngrade',
                isFalse,
              )
              .having(
                (AppDatabaseVersionMismatch e) => e.toString(),
                'toString',
                contains(AppDatabaseVersionMismatch.missingMigrationAdvice),
              ),
        ),
        reason:
            'AD-15 makes the migration step mandatory, so a gap is a '
            'development error. It must fail loudly rather than run the new '
            'code against the old schema.',
      );

      // Fail loudly is not the same as fail destructively (AD-15, AD-18).
      expect(file.existsSync(), isTrue);
      expect(
        file.lengthSync(),
        sizeBefore,
        reason: 'a health record with no cloud copy is never discarded',
      );
    });

    test('the covered step is the ONLY one that does not throw', () async {
      // The migration is written as `if (from == 1 && to == 2)`. A reviewer
      // widening that to `if (from < to)` would make every future gap a silent
      // no-op -- the app would then run against whatever schema it found. This
      // asserts the negative for every other pair in range.
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final Migrator migrator = database.createMigrator();

      for (final (int, int) gap in const <(int, int)>[
        (1, 3),
        (2, 3),
        (2, 1),
        (3, 2),
        (5, 9),
      ]) {
        await expectLater(
          database.migration.onUpgrade(migrator, gap.$1, gap.$2),
          throwsA(isA<AppDatabaseVersionMismatch>()),
          reason: '${gap.$1} -> ${gap.$2} has no migration step',
        );
      }
    });
  });
}

/// Every `CREATE` statement SQLite holds for [database], in a stable order.
///
/// Read out of `sqlite_master` rather than assembled from drift's Dart, so the
/// comparison is between two real databases.
Future<List<String>> _schemaSql(AppDatabase database) async {
  final List<QueryRow> rows = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' "
        'ORDER BY type, name',
      )
      .get();
  return rows.map((QueryRow row) => row.read<String>('sql')).toList();
}
