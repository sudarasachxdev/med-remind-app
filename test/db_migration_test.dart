// The migration half of AD-15: an installed database, at whatever version it
// was last opened at, becomes version 6 without losing a row, and every way of
// arriving at a given version agrees with every other.
//
// `test/db_schema_test.dart` pins what the schema IS. This file pins how an
// installed app gets there. The two questions are different, and only this one
// can be answered against real historical snapshots: the fixtures under
// `drift_schemas/` were dumped by `drift_dev schema dump` from the code as it
// stood at the time -- v1 from the version Story 1.3 shipped, v2 from Story
// 1.4's, v3 from Story 1.7a's, v4 from Story 3.3's (adding
// `Schedules.remindersEnabled`), v5 from Story 3.5's (adding
// `AppSettings.lastKnownIanaTimezone`), v6 from this story's (Story 3.9,
// adding `AppSettings`' five `ReminderSettings` columns) -- so the v1..v5
// databases these tests start from are the ones on a user's phone rather than
// the ones today's Dart would create. A fixture regenerated from current code
// would make every test below vacuous -- it would compare the new schema with
// itself -- which is why `the v1 fixture is still Story 1.3's` (and its v2..v5
// siblings) reads the JSON and asserts its contents.
//
// Five paths reach v6 and all must exist for EVERY prior version, not just the
// most recent one (the spec's "Both paths agree"): `onCreate` for a fresh
// install, and `onUpgrade` for an existing one -- and `onUpgrade` is called
// EXACTLY ONCE per open, with the full (storedVersion, schemaVersion) span
// (see `app_database.dart`'s `onUpgrade` for where this was measured), so a
// real v1 install reaches v6 in one step, not via an intermediate v2..v5
// nobody's `onUpgrade` call ever sees. Rewriting `onCreate` to include the new
// columns INSTEAD of migrating would pass a naive schema test and hard-fail
// every phone that already has the app.
//
// `app_settings` HAS EXISTED SINCE V1, UNLIKE `schedules`. That is why every
// branch below -- not only `5 -> 6` -- calls `addColumn` for all five of this
// story's new columns: a v1, v2, v3 or v4 install migrating straight to v6
// still needs them added onto its pre-existing `app_settings` row, exactly the
// same shape Story 3.5's `lastKnownIanaTimezone` needed across the pre-v5
// branches that predated it. A naive port of "one new pair, `5 -> 6`" would
// pass a schema-fixture comparison for that one pair while silently breaking
// every other real upgrade path -- exactly the class of bug AD-15's fixture
// comparison exists to catch, which is why each pre-existing-row test below
// reads the five new columns back rather than only comparing table shapes.
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

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;

/// This build, but claiming a schema version no migration step reaches.
///
/// The missing-migration branch of `AppDatabaseVersionMismatch` was
/// unreachable in Story 1.3, and at version 2 it was *still* unreachable
/// through the ordinary constructor: the only gaps below 2 were 1 -> 2, which
/// Story 1.4 added, and 0, which means "no database yet" and routes to
/// `onCreate`. Naming a version beyond the current `schemaVersion` is what
/// makes the branch observable without waiting for some future story to add
/// one -- and it exercises the real `migration` getter, not a copy of its
/// logic. Story 1.7a's own comment above `_AppDatabaseClaimingVersion3`
/// foresaw this and its own successors predicted a further one -- the class
/// now claims 7, one past the 6 this story made real, exactly as expected.
final class _AppDatabaseClaimingVersion7 extends AppDatabase {
  _AppDatabaseClaimingVersion7(super.executor);

  @override
  int get schemaVersion => 7;
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

    test('the v2 fixture is still Story 1.4\'s, not a copy of today\'s', () {
      // The same manual check as the v1 test above, for the same reason: v2
      // gained `doses` if it was re-dumped from this story's code, and every
      // "2 -> 3" test below would then start from the schema it is trying to
      // prove the migration produces.
      final File fixture = File('drift_schemas/drift_schema_v2.json');
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
        equals(<String>['app_settings', 'medicines', 'schedules']),
        reason:
            'Version 2 had exactly these three tables, no `doses` among '
            'them. A v2 fixture holding `doses` was dumped from this '
            'story\'s code and makes every "2 -> 3" migration test vacuous.',
      );
    });

    test('the v3 fixture is still Story 1.7a\'s, not a copy of today\'s', () {
      // The same manual check again, for Story 3.3's own column: `schedules`
      // must NOT carry `reminders_enabled` in the v3 fixture, or every
      // "3 -> 6" test below starts from the schema it is trying to prove the
      // migration produces.
      final File fixture = File('drift_schemas/drift_schema_v3.json');
      final Map<String, Object?> json =
          jsonDecode(fixture.readAsStringSync()) as Map<String, Object?>;
      final Map<String, Object?> schedulesData =
          (json['entities']! as List<Object?>)
              .map(
                (Object? entity) =>
                    (entity! as Map<String, Object?>)['data']!
                        as Map<String, Object?>,
              )
              .singleWhere(
                (Map<String, Object?> data) => data['name'] == 'schedules',
              );
      final List<String> columnNames =
          (schedulesData['columns']! as List<Object?>)
              .map(
                (Object? column) =>
                    (column! as Map<String, Object?>)['name']! as String,
              )
              .toList();

      expect(
        columnNames,
        isNot(contains('reminders_enabled')),
        reason:
            'A v3 fixture already carrying `reminders_enabled` was dumped '
            'from this story\'s code and makes every "3 -> 6" migration '
            'test in this file vacuous.',
      );
    });

    test('the v4 fixture is still Story 3.3\'s, not a copy of today\'s', () {
      // The same manual check again, for Story 3.5's own column:
      // `app_settings` must NOT carry `last_known_iana_timezone` in the v4
      // fixture, or the "4 -> 6" test below starts from the schema it is
      // trying to prove the migration produces.
      final File fixture = File('drift_schemas/drift_schema_v4.json');
      final Map<String, Object?> json =
          jsonDecode(fixture.readAsStringSync()) as Map<String, Object?>;
      final Map<String, Object?> appSettingsData =
          (json['entities']! as List<Object?>)
              .map(
                (Object? entity) =>
                    (entity! as Map<String, Object?>)['data']!
                        as Map<String, Object?>,
              )
              .singleWhere(
                (Map<String, Object?> data) => data['name'] == 'app_settings',
              );
      final List<String> columnNames =
          (appSettingsData['columns']! as List<Object?>)
              .map(
                (Object? column) =>
                    (column! as Map<String, Object?>)['name']! as String,
              )
              .toList();

      expect(
        columnNames,
        isNot(contains('last_known_iana_timezone')),
        reason:
            'A v4 fixture already carrying `last_known_iana_timezone` was '
            'dumped from this story\'s code and makes every "4 -> 6" '
            'migration test in this file vacuous.',
      );
    });

    test('the v5 fixture is still Story 3.5\'s, not a copy of today\'s', () {
      // The same manual check again, for THIS story's own five columns:
      // `app_settings` must NOT carry any of them in the v5 fixture, or the
      // "5 -> 6" test below starts from the schema it is trying to prove the
      // migration produces.
      final File fixture = File('drift_schemas/drift_schema_v5.json');
      final Map<String, Object?> json =
          jsonDecode(fixture.readAsStringSync()) as Map<String, Object?>;
      final Map<String, Object?> appSettingsData =
          (json['entities']! as List<Object?>)
              .map(
                (Object? entity) =>
                    (entity! as Map<String, Object?>)['data']!
                        as Map<String, Object?>,
              )
              .singleWhere(
                (Map<String, Object?> data) => data['name'] == 'app_settings',
              );
      final List<String> columnNames =
          (appSettingsData['columns']! as List<Object?>)
              .map(
                (Object? column) =>
                    (column! as Map<String, Object?>)['name']! as String,
              )
              .toList();

      expect(
        columnNames,
        isNot(
          anyOf(
            contains('reminders_enabled_default'),
            contains('follow_up_offset_minutes1'),
            contains('follow_up_offset_minutes2'),
            contains('escalation_window_override_minutes'),
            contains('snooze_interval_minutes'),
          ),
        ),
        reason:
            'A v5 fixture already carrying one of this story\'s five columns '
            'was dumped from this story\'s code and makes every "5 -> 6" '
            'migration test in this file vacuous.',
      );
    });

    test('all six versions are known to the helper', () {
      expect(GeneratedHelper.versions, equals(<int>[1, 2, 3, 4, 5, 6]));
    });
  });

  group('1 -> 6 (a v1 install updating straight to this build)', () {
    test('migrating a real v1 database yields the v6 schema', () async {
      // The heart of AD-15. `migrateAndValidate` opens the database, runs the
      // real `migration` strategy, then reads `sqlite_schema` back and
      // compares it against the v6 fixture -- so this asserts the migration
      // produced the schema, rather than asserting that it ran.
      final DatabaseConnection connection = await verifier.startAt(1);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        6,
        // Strict: a table, view or trigger left behind by the migration fails
        // too, not only a missing one. Off by default, and Story 1.4 was the
        // one that decided whether migration discipline is real.
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('the onboarding flag survives (never recreate the file), and every '
        'Story 3.5/3.9 column reads back at its documented default on the '
        'pre-existing row', () async {
      // The data-loss test. An installed app is carrying a completed
      // onboarding flag in `app_settings`; a migration that dropped and
      // recreated the database -- or an `onCreate` pressed into service as an
      // upgrade -- would lose it, on the part of this codebase whose whole
      // subject is not losing data.
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
            'loses the medicine and dose history from Story 1.4 onwards.',
      );

      // Story 3.5's own column, added onto this same pre-existing row via
      // `addColumn` in the `1 -> 6` branch (`app_settings` existed at v1,
      // unlike `schedules`, so this is not free the way `createTable` makes
      // it for a brand-new table).
      final List<QueryRow> settings = await migrated
          .customSelect('SELECT * FROM app_settings')
          .get();
      expect(
        settings.single.data['last_known_iana_timezone'],
        isNull,
        reason:
            'Nothing has run Reconciler yet on this row, so there is no '
            'last-known zone -- and this must read back null rather than '
            'throwing on a column the addColumn call failed to add.',
      );

      // This story's own five columns, added onto the same pre-existing
      // row -- each must read back at the documented default, matching
      // `ReminderSettings.freshInstallDefault`.
      expect(settings.single.data['reminders_enabled_default'], 1);
      expect(settings.single.data['follow_up_offset_minutes1'], 15);
      expect(settings.single.data['follow_up_offset_minutes2'], 30);
      expect(
        settings.single.data['escalation_window_override_minutes'],
        isNull,
      );
      expect(settings.single.data['snooze_interval_minutes'], 15);

      // And the migration actually happened, rather than the read succeeding
      // against an untouched v1 file.
      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 6);

      for (final String table in <String>['medicines', 'schedules', 'doses']) {
        final List<QueryRow> rows = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              'AND name = ?',
              variables: <Variable<Object>>[Variable<String>(table)],
            )
            .get();
        expect(rows, hasLength(1), reason: '$table should exist after 1 -> 6');
      }
    });

    test('a fresh row (from this build\'s onCreate path) has remindersEnabled '
        'true, and 1 -> 6 gives the same schema `createTable(schedules)` builds '
        'on this path', () async {
      // `createTable(schedules)` in the 1 -> 6 branch builds from TODAY's
      // `Schedules` definition, which already carries `remindersEnabled` --
      // no separate `addColumn` call exists for it in that branch (see
      // `app_database.dart`'s own comment). This proves the column is
      // really there and really defaults to `true`, not merely that the
      // fixture comparison above happened to tolerate its absence.
      final DatabaseConnection connection = await verifier.startAt(1);
      final AppDatabase migrated = AppDatabase(connection);
      addTearDown(migrated.close);

      await migrated.customStatement(
        "INSERT INTO medicines (id, name, glyph_index, form, "
        "dosage_amount, dosage_unit, start_date) VALUES ('m1', "
        "'Metformin', 0, 'tablet', 1.0, 'tablet', '2026-09-07')",
      );
      await migrated.customStatement(
        "INSERT INTO schedules (id, medicine_id, time_of_day, "
        "iana_timezone, frequency, dosage_amount) VALUES ('s1', 'm1', "
        "'08:00', 'Asia/Colombo', 'everyDay', 1.0)",
      );

      final List<QueryRow> rows = await migrated
          .customSelect(
            'SELECT reminders_enabled FROM schedules WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('s1')],
          )
          .get();
      expect(rows.single.data['reminders_enabled'], 1);
    });

    test('the migrated schema is identical to a fresh one', () async {
      // The spec's "Both paths agree" row, asserted directly rather than
      // through the fixture: the CREATE statements SQLite itself holds for a
      // database born at 6 and for one that walked 1 -> 6, compared as text.
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
      expect(freshSchema, hasLength(4));
    });
  });

  group('2 -> 6 (a v2 install updating straight to this build)', () {
    test('migrating a real v2 database yields the v6 schema', () async {
      final DatabaseConnection connection = await verifier.startAt(2);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        6,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('a Medicine and Schedule written under v2 are still readable, the '
        'reminders column defaults to true on the pre-existing row, and '
        'every Story 3.5/3.9 column reads back at its documented default on '
        'it too', () async {
      // The spec's own wording for this row. Distinct from the fixture
      // comparison above: that proves the SHAPE survives, this proves a
      // REAL ROW written before the migration reads back unchanged after it
      // -- schema equality alone would not catch a migration that happened
      // to recreate `medicines` empty on its way to adding `doses`.
      final InitializedSchema schema = await verifier.schemaAt(2);
      addTearDown(schema.close);

      final v2.DatabaseAtV2 old = v2.DatabaseAtV2(schema.newConnection());
      await old.customStatement(
        "INSERT INTO medicines (id, name, glyph_index, form, "
        "dosage_amount, dosage_unit, start_date) VALUES ('m1', "
        "'Metformin', 0, 'tablet', 1.0, 'tablet', '2026-09-07')",
      );
      await old.customStatement(
        "INSERT INTO schedules (id, medicine_id, time_of_day, "
        "iana_timezone, frequency, dosage_amount) VALUES ('s1', 'm1', "
        "'08:00', 'Asia/Colombo', 'everyDay', 1.0)",
      );
      await old.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 1)',
      );
      await old.close();

      final AppDatabase migrated = AppDatabase(schema.newConnection());
      addTearDown(migrated.close);

      final List<QueryRow> medicines = await migrated
          .customSelect(
            'SELECT * FROM medicines WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('m1')],
          )
          .get();
      expect(medicines.single.data['name'], 'Metformin');

      final List<QueryRow> schedules = await migrated
          .customSelect(
            'SELECT * FROM schedules WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('s1')],
          )
          .get();
      expect(schedules.single.data['time_of_day'], '08:00');
      expect(schedules.single.data['medicine_id'], 'm1');
      expect(
        schedules.single.data['reminders_enabled'],
        1,
        reason:
            'a pre-existing v2 row gained the column via addColumn, which '
            'must carry the same true default a fresh install would',
      );

      final List<QueryRow> settings = await migrated
          .customSelect('SELECT * FROM app_settings')
          .get();
      expect(
        settings.single.data['last_known_iana_timezone'],
        isNull,
        reason:
            'Story 3.5\'s column, added onto the pre-existing app_settings '
            'row via addColumn -- must read back null, not fail or resurrect '
            'a value nobody wrote.',
      );
      expect(settings.single.data['reminders_enabled_default'], 1);
      expect(settings.single.data['follow_up_offset_minutes1'], 15);
      expect(settings.single.data['follow_up_offset_minutes2'], 30);
      expect(
        settings.single.data['escalation_window_override_minutes'],
        isNull,
      );
      expect(settings.single.data['snooze_interval_minutes'], 15);

      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 6);
    });
  });

  group('3 -> 6 (the earlier "Migration v3 -> v4" row, retargeted to v6)', () {
    test('migrating a real v3 database yields the v6 schema', () async {
      final DatabaseConnection connection = await verifier.startAt(3);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        6,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('a Schedule written under v3 (no reminders_enabled column yet) reads '
        'back with the column defaulted to true, and every Story 3.5/3.9 '
        'column reads back at its documented default', () async {
      final InitializedSchema schema = await verifier.schemaAt(3);
      addTearDown(schema.close);

      final v3.DatabaseAtV3 old = v3.DatabaseAtV3(schema.newConnection());
      await old.customStatement(
        "INSERT INTO medicines (id, name, glyph_index, form, "
        "dosage_amount, dosage_unit, start_date) VALUES ('m1', "
        "'Metformin', 0, 'tablet', 1.0, 'tablet', '2026-09-07')",
      );
      await old.customStatement(
        "INSERT INTO schedules (id, medicine_id, time_of_day, "
        "iana_timezone, frequency, dosage_amount) VALUES ('s1', 'm1', "
        "'08:00', 'Asia/Colombo', 'everyDay', 1.0)",
      );
      await old.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 0)',
      );
      await old.close();

      final AppDatabase migrated = AppDatabase(schema.newConnection());
      addTearDown(migrated.close);

      final List<QueryRow> schedules = await migrated
          .customSelect(
            'SELECT * FROM schedules WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('s1')],
          )
          .get();
      expect(schedules.single.data['time_of_day'], '08:00');
      expect(
        schedules.single.data['reminders_enabled'],
        1,
        reason:
            'FR-11: a Schedule saved before Story 3.3 shipped meant '
            '"reminders on" -- the migration must not silently opt it out',
      );

      final List<QueryRow> settings = await migrated
          .customSelect('SELECT * FROM app_settings')
          .get();
      expect(settings.single.data['last_known_iana_timezone'], isNull);
      expect(settings.single.data['reminders_enabled_default'], 1);
      expect(settings.single.data['follow_up_offset_minutes1'], 15);
      expect(settings.single.data['follow_up_offset_minutes2'], 30);
      expect(
        settings.single.data['escalation_window_override_minutes'],
        isNull,
      );
      expect(settings.single.data['snooze_interval_minutes'], 15);

      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 6);
    });
  });

  group('4 -> 6 (the earlier "this story\'s own migration" row, retargeted '
      'to v6)', () {
    test('migrating a real v4 database yields the v6 schema', () async {
      final DatabaseConnection connection = await verifier.startAt(4);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        6,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('a Schedule written under v4 (reminders_enabled already exists) is '
        'unaffected, and every Story 3.5/3.9 column reads back at its '
        'documented default on the pre-existing app_settings row', () async {
      // Every table already exists at v4; Story 3.5's column and this
      // story's five columns all land on a row shape every other table in
      // this test is proof-of-life for.
      final InitializedSchema schema = await verifier.schemaAt(4);
      addTearDown(schema.close);

      final v4.DatabaseAtV4 old = v4.DatabaseAtV4(schema.newConnection());
      await old.customStatement(
        "INSERT INTO medicines (id, name, glyph_index, form, "
        "dosage_amount, dosage_unit, start_date) VALUES ('m1', "
        "'Metformin', 0, 'tablet', 1.0, 'tablet', '2026-09-07')",
      );
      await old.customStatement(
        "INSERT INTO schedules (id, medicine_id, time_of_day, "
        "iana_timezone, frequency, dosage_amount, reminders_enabled) VALUES "
        "('s1', 'm1', '08:00', 'Asia/Colombo', 'everyDay', 1.0, 0)",
      );
      await old.customStatement(
        'INSERT INTO app_settings (id, onboarding_completed) VALUES (1, 1)',
      );
      await old.close();

      final AppDatabase migrated = AppDatabase(schema.newConnection());
      addTearDown(migrated.close);

      final List<QueryRow> schedules = await migrated
          .customSelect(
            'SELECT * FROM schedules WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('s1')],
          )
          .get();
      expect(
        schedules.single.data['reminders_enabled'],
        0,
        reason:
            'this story touches app_settings alone -- a real v4 value on an '
            'unrelated column must not be disturbed by adding new ones',
      );

      final List<QueryRow> settings = await migrated
          .customSelect('SELECT * FROM app_settings')
          .get();
      expect(settings.single.data['onboarding_completed'], 1);
      expect(
        settings.single.data['last_known_iana_timezone'],
        isNull,
        reason:
            'Nothing has run Reconciler yet on this row, so there is no '
            'last-known zone -- and the addColumn in the 4 -> 6 branch must '
            'produce exactly that, reading back null rather than failing.',
      );
      expect(settings.single.data['reminders_enabled_default'], 1);
      expect(settings.single.data['follow_up_offset_minutes1'], 15);
      expect(settings.single.data['follow_up_offset_minutes2'], 30);
      expect(
        settings.single.data['escalation_window_override_minutes'],
        isNull,
      );
      expect(settings.single.data['snooze_interval_minutes'], 15);

      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 6);
    });
  });

  group('5 -> 6 (this story\'s own migration)', () {
    test('migrating a real v5 database yields the v6 schema', () async {
      final DatabaseConnection connection = await verifier.startAt(5);
      final AppDatabase database = AppDatabase(connection);
      addTearDown(database.close);

      await verifier.migrateAndValidate(
        database,
        6,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('a v5 app_settings row (lastKnownIanaTimezone already exists) is '
        'unaffected, and this story\'s five new columns read back at their '
        'documented defaults on the pre-existing row', () async {
      // The spec's own row for this story: every table and every column
      // through `lastKnownIanaTimezone` already exists at v5; this story's
      // one schema change is its five new columns.
      final InitializedSchema schema = await verifier.schemaAt(5);
      addTearDown(schema.close);

      final v5.DatabaseAtV5 old = v5.DatabaseAtV5(schema.newConnection());
      await old.customStatement(
        "INSERT INTO app_settings (id, onboarding_completed, "
        "last_known_iana_timezone) VALUES (1, 1, 'Asia/Colombo')",
      );
      await old.close();

      final AppDatabase migrated = AppDatabase(schema.newConnection());
      addTearDown(migrated.close);

      final List<QueryRow> settings = await migrated
          .customSelect('SELECT * FROM app_settings')
          .get();
      expect(
        settings.single.data['onboarding_completed'],
        1,
        reason: 'this story touches none of the pre-existing columns',
      );
      expect(
        settings.single.data['last_known_iana_timezone'],
        'Asia/Colombo',
        reason:
            'a real Story 3.5 value on an unrelated column must not be '
            'disturbed by adding five new ones',
      );
      expect(settings.single.data['reminders_enabled_default'], 1);
      expect(settings.single.data['follow_up_offset_minutes1'], 15);
      expect(settings.single.data['follow_up_offset_minutes2'], 30);
      expect(
        settings.single.data['escalation_window_override_minutes'],
        isNull,
        reason:
            'null means Automatic -- the addColumn in the 5 -> 6 branch must '
            'produce exactly that, reading back null rather than failing.',
      );
      expect(settings.single.data['snooze_interval_minutes'], 15);

      final List<QueryRow> version = await migrated
          .customSelect('PRAGMA user_version')
          .get();
      expect(version.single.data['user_version'], 6);
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

      final AppDatabase build = _AppDatabaseClaimingVersion7(
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
                7,
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
      // The migration is written as exact `if (from == x && to == y)` pairs.
      // A reviewer widening one to `if (from < to)` would make every future
      // gap a silent no-op -- the app would then run against whatever schema
      // it found. This asserts the negative for every pair this build does
      // NOT cover, now that `1 -> 6`, `2 -> 6`, `3 -> 6`, `4 -> 6` and
      // `5 -> 6` are the five that it does.
      //
      // Every other pair among versions 1..6 is in this list on purpose: each
      // was either a covered step through some earlier range of stories, or
      // is a backward/lateral pair that was never valid. This story retired
      // the previous five-pair set (every `x -> 5`) rather than adding to it,
      // because `onUpgrade`'s `to` can now only ever be 6 (see the header
      // comment). A gap this build will never actually be asked for is still
      // worth naming here, so a future reviewer re-widening the migration to
      // accept it again fails a test rather than shipping silently.
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final Migrator migrator = database.createMigrator();

      for (final (int, int) gap in const <(int, int)>[
        (1, 2),
        (1, 3),
        (1, 4),
        (1, 5),
        (2, 1),
        (2, 3),
        (2, 4),
        (2, 5),
        (3, 1),
        (3, 2),
        (3, 4),
        (3, 5),
        (4, 1),
        (4, 2),
        (4, 3),
        (4, 5),
        (5, 1),
        (5, 2),
        (5, 3),
        (5, 4),
        (6, 1),
        (6, 2),
        (6, 3),
        (6, 4),
        (6, 5),
        (7, 10),
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
