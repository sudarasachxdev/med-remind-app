// The application database, at schema version 2.
//
// AD-3 — one process opens the database. One `AppDatabase` is constructed, in
// `lib/main.dart`, and handed to the adapters that need it. Nothing else calls
// this constructor at runtime; tests construct their own over an in-memory
// executor.
//
// AD-15 — every schema change ships a migration and a schema test. Version 2
// adds [Medicines] and [Schedules], and it adds them by MIGRATING: an installed
// app already holds a v1 file carrying the user's onboarding flag, and
// recreating it would be a data-loss bug on the very story whose subject is not
// losing data. So both paths exist and both must agree — `onCreate` builds all
// three tables for a fresh install, `onUpgrade` creates the two new ones on an
// existing one, and `test/db_migration_test.dart` compares the two resulting
// schemas against drift's generated fixtures rather than asserting they match.
//
// There is deliberately no `deleteOnFailure`-style recovery: the spine
// prohibits it (AD-15, AD-18), and a health record with no cloud copy must
// never be discarded because it failed to open once.
//
// This story owns two tables. `doses` belongs to Story 1.7, which needs the
// escalation policy Story 1.6 has not written yet.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The file name (without extension) of the on-device database.
///
/// `drift_flutter` opens `$appDatabaseName.sqlite` in the application documents
/// directory. **Changing this string orphans every existing install**: the app
/// opens a different, empty file, the onboarding flag reads unset, and from
/// Story 1.4 the user's entire medicine and dose history becomes invisible.
/// There is no cloud copy by design, so there is nothing to fall back on.
/// `test/db_schema_test.dart` pins both the constant and the file it produces.
const String appDatabaseName = 'meditracker';

/// The primary key of the one row [AppSettings] is allowed to hold.
const int appSettingsRowId = 1;

/// App-wide settings, as a single row.
///
/// A settings *table* rather than a key/value store because every setting this
/// product has is typed and known at compile time — the escalation window, the
/// snooze length, the reminder offsets — so a `TEXT` value column would throw
/// away the type and the migration story with it.
///
/// One row, enforced in the schema by a `CHECK (id = 1)` rather than by
/// convention in the repository: a second row is then impossible rather than
/// merely unwritten, and the two readers cannot disagree about which row is
/// the settings.
class AppSettings extends Table {
  /// Always [appSettingsRowId]. The check constraint is what makes this table
  /// single-row.
  ///
  /// The self-reference below is drift's documented way to attach a `CHECK` to
  /// a column -- the constraint has to name the column it constrains -- so the
  /// `recursive_getters` warning is a false positive: drift reads the
  /// expression once at build time and emits it into the `CREATE TABLE`. The
  /// getter is never called at runtime, so nothing recurses.
  IntColumn get id => integer()
      // ignore: recursive_getters
      .check(id.equals(appSettingsRowId))
      .withDefault(const Constant(appSettingsRowId))();

  /// Whether the user has reached Home through the onboarding panels.
  ///
  /// Defaults to `false` so that a row inserted for some other setting does not
  /// silently claim onboarding was seen.
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The SQLite `GLOB` pattern a `YYYY-MM-DD` calendar date must match.
///
/// A shape check in the schema, not a length check. `LENGTH(start_date) = 10`
/// was the first version of this and it was not enough: `'2026-13-45'` is ten
/// characters, and `DateTime(2026, 13, 45)` does not throw -- Dart rolls it
/// over to 2027-02-14, so a start date moved five months with nothing anywhere
/// reporting it. The pattern is what stops the value at the boundary; the
/// adapter's parser range-checks the parts as well, because `GLOB` character
/// classes cannot express "month 01..12" (`[0-1][0-9]` still admits 00 and 19).
///
/// `GLOB` rather than `LIKE`: `LIKE` has no character classes, and `GLOB` is
/// case-sensitive and always available in SQLite with no extension.
///
/// The columns below spell this pattern out as a literal rather than
/// interpolating this constant, because drift's schema dump serialises a
/// `check` expression lexeme by lexeme and an interpolated constant does not
/// survive that round trip. `test/db_schema_test.dart` asserts that the
/// `CREATE TABLE` SQLite ends up holding contains this exact pattern, so the
/// two cannot drift apart unnoticed.
const String isoDateGlob = '[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]';

/// The SQLite `GLOB` pattern a 24-hour `HH:mm` wall-clock time must match.
///
/// See [isoDateGlob]. Coarse in the same way -- `[0-2][0-9]` admits 29 -- and
/// backed by the same two further checks: `Schedule.isValidTimeOfDay` on the
/// way in, and the adapter translating an unreadable row into a typed failure
/// on the way out. What it buys is that `'99:99'` and `'8:00'` cannot be
/// written by a raw statement, which is the path a future migration takes.
const String timeOfDayGlob = '[0-2][0-9]:[0-5][0-9]';

/// One medicine the user takes — the aggregate root (AD-12).
///
/// `@DataClassName('MedicineRow')`: drift would otherwise name the generated
/// row class `Medicine`, which is the domain model's name. Two different
/// `Medicine` types would force every file that touched both to alias one of
/// them, and the first mistake would be a row class crossing into the domain
/// under the right name. The row is a `Row`; the model is the `Medicine`.
///
/// Dates are `YYYY-MM-DD` **text**, not drift's `dateTime()`. A `dateTime()`
/// column stores Unix seconds by default, which is a UTC instant, and a
/// calendar date is not an instant: "started on the 1st" must not become
/// "started on the 31st" because the phone was in Asia/Colombo when it was
/// written and in UTC when it was read. Storing the date the user meant, as the
/// user's own reckoning of it, removes the conversion entirely.
@DataClassName('MedicineRow')
class Medicines extends Table {
  /// UUID v4, as text (the spine's Identifiers convention).
  TextColumn get id => text()();

  /// What the user calls it (FR-1).
  TextColumn get name => text()();

  /// What it is for, in the user's own words. Free text, displayed and never
  /// interpreted — the PRD forbids validating it or looking it up — hence no
  /// length or format constraint here beyond nullability.
  TextColumn get condition => text().nullable()();

  /// Which of the design system's four glyphs represents this Medicine.
  ///
  /// AD-22: assigned once at creation as `count(existing medicines) mod 4`,
  /// persisted here, and never recomputed. Deliberately carries no `CHECK`
  /// against the glyph count: the count is a design decision that may grow, and
  /// a schema constraint would turn growing it into a third migration for no
  /// safety a test does not already give.
  IntColumn get glyphIndex => integer()();

  /// Tablet, capsule, drops (FR-1).
  TextColumn get form => text()();

  /// How much is taken per dose by default (FR-1). Real, because half a tablet
  /// and 2.5 ml are both ordinary.
  RealColumn get dosageAmount => real()();

  /// The unit [dosageAmount] is counted in (FR-1).
  TextColumn get dosageUnit => text()();

  /// Anything else the user wants to remember. Not captured by the Story 1.5
  /// add flow, deliberately; the column exists so editing can gain it without
  /// a migration.
  TextColumn get instructions => text().nullable()();

  /// The calendar day the regimen begins, as `YYYY-MM-DD`.
  ///
  /// The self-reference in the `check` is drift's documented way to attach a
  /// `CHECK` to a column -- the constraint has to name the column it
  /// constrains -- so the `recursive_getters` warning is a false positive:
  /// drift reads the expression once at build time and emits it into the
  /// `CREATE TABLE`. The getter is never called at runtime.
  TextColumn get startDate => text().check(
    const CustomExpression<bool>(
      '"start_date" GLOB \'[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]\'',
    ),
  )();

  /// The calendar day it ends, inclusive, or null for open-ended.
  TextColumn get endDate => text()
      .check(
        const CustomExpression<bool>(
          '"end_date" GLOB \'[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]\'',
        ),
      )
      .nullable()();

  /// Whether the medicine is currently being taken.
  ///
  /// Separate from deletion: stopping a medicine must not erase the history of
  /// having taken it. Defaults to true — a medicine is added in order to take
  /// it.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One recurring time at which a [Medicines] row is taken (FR-4).
///
/// AD-6 is the whole shape of this table: [timeOfDay] is a local wall clock and
/// [ianaTimezone] is the zone it is read in, and **there is no UTC instant
/// column**. "Every day at 8:00" survives a DST transition only if 8:00 is
/// what was stored; a precomputed instant would drift by an hour twice a year,
/// which is the failure class the PRD found in competitor app-store reviews.
/// The product's only UTC value is the ordering column on a generated Dose,
/// which Story 1.7 owns — nothing here.
@DataClassName('ScheduleRow')
class Schedules extends Table {
  /// UUID v4, as text.
  TextColumn get id => text()();

  /// The [Medicines] row this Schedule belongs to.
  ///
  /// `ON DELETE CASCADE` states AD-12's ownership in the schema: a Schedule has
  /// no life without its Medicine, and an orphan would be a reminder for a
  /// medicine the user cannot see. It is enforced rather than declared because
  /// `beforeOpen` turns `PRAGMA foreign_keys` on — SQLite ignores every foreign
  /// key without it. `DriftMedicineRepository.deleteMedicine` still deletes the
  /// Schedules explicitly, in the same transaction: the cascade is the
  /// database's guarantee for any path, and the explicit delete is the one this
  /// story's tests can watch.
  TextColumn get medicineId =>
      text().references(Medicines, #id, onDelete: KeyAction.cascade)();

  /// The local wall-clock time, as 24-hour `HH:mm` (AD-6).
  TextColumn get timeOfDay => text().check(
    const CustomExpression<bool>(
      '"time_of_day" GLOB \'[0-2][0-9]:[0-5][0-9]\'',
    ),
  )();

  /// The IANA zone [timeOfDay] is read in — `Asia/Colombo` (AD-6).
  ///
  /// Per Schedule rather than read from the device, so a Schedule keeps its
  /// meaning when the user travels.
  TextColumn get ianaTimezone => text()();

  /// One of `Frequency`'s four names (FR-4), as text.
  ///
  /// The enum's `name` rather than its `index`: an index would silently
  /// reinterpret every stored row the day a value is inserted into the middle
  /// of the enum, and there is no migration that could detect it.
  TextColumn get frequency => text()();

  /// The days `Frequency.specificDays` names, as ascending `1`..`7` joined by
  /// commas — `1` is Monday, matching `DateTime.monday`.
  ///
  /// Null for every other frequency. Nullable rather than empty-string because
  /// "this frequency has no day set" and "this frequency has an empty day set"
  /// are different, and only the first is legal.
  TextColumn get daysOfWeek => text().nullable()();

  /// The interval `Frequency.everyNDays` counts in days. Null otherwise.
  ///
  /// Nullable, with no `CHECK` for the minimum of 2: the frequency/companion
  /// pairing is the domain's rule to enforce, not the schema's — three of the
  /// four frequencies leave this empty, so nothing in SQLite can tell whether
  /// a null here is correct.
  IntColumn get intervalDays => integer().nullable()();

  /// How much is taken at this occurrence, defaulting at creation to the
  /// Medicine's amount. Stored per Schedule so "two in the morning, one at
  /// night" needs no second Medicine.
  RealColumn get dosageAmount => real()();

  /// A per-Schedule escalation-window override, or null to inherit (AD-16).
  ///
  /// Opaque text until Story 1.6 gives the policy a type, so that the column
  /// exists before the policy does and the schema needs no further migration
  /// to gain it.
  TextColumn get reminderOverride => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The Drift database. Schema version 2: [AppSettings], [Medicines] and
/// [Schedules].
@DriftDatabase(tables: [AppSettings, Medicines, Schedules])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database, or [executor] when one is supplied.
  ///
  /// [executor] exists for tests, which pass `NativeDatabase.memory()`. It is
  /// not a second production path: `lib/main.dart` calls this with no argument.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: appDatabaseName));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // A fresh install builds all three tables at once. This is the second of
    // the two paths that must agree with each other -- see `onUpgrade` -- and
    // `test/db_migration_test.dart` is what holds them in step. It is NOT a
    // substitute for the migration: rewriting `onCreate` to include the new
    // tables and leaving `onUpgrade` throwing would give every existing install
    // a hard failure on the update that added them.
    onCreate: (Migrator m) => m.createAll(),
    // Drift calls onUpgrade for ANY version mismatch, downgrades included, and
    // its default implementation throws "you didn't provide a strategy" --
    // which is true of an uncovered forward step and misleading about a
    // backward one. A downgraded build would hit that message on every open,
    // for ever, with nothing naming the actual situation. So every case is
    // named here: the one step this build knows how to take, and a throw for
    // everything else.
    //
    // Neither remaining case is recoverable in this story, and neither pretends
    // to be: the failure travels up through the startup read, which logs it,
    // reports it and shows onboarding rather than hanging. Story 4.7 owns the
    // recovery surface (AD-18); this owns saying what went wrong.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1 && to == 2) {
        // The whole of 1 -> 2: two new tables, nothing altered. `app_settings`
        // is not touched, so the onboarding flag an installed app is carrying
        // survives untouched -- which is the point of migrating rather than
        // recreating.
        //
        // ONE TRANSACTION, and it has to be explicit. Drift calls this
        // callback directly from `beforeOpen` and writes `user_version` only
        // after it returns, so a failure between two statements here would
        // leave a half-migrated file still stamped version 1 -- and the next
        // launch would run the same step again against a database that already
        // has half of it. Today that second run happens to survive, because
        // `Migrator.createTable` emits `CREATE TABLE IF NOT EXISTS`; that is an
        // implementation detail of drift, it is recorded nowhere else, and it
        // would not save an `ALTER TABLE` or a data copy. Wrapping the step is
        // what makes the recovery a property of this code. `transaction` inside
        // `onUpgrade` is drift's own documented pattern for exactly this (see
        // the `runMigrationSteps` example in its `Migrator` docs).
        //
        // Note that `PRAGMA foreign_keys` is OFF in here: the `beforeOpen`
        // callback below runs AFTER this one, and SQLite refuses to change the
        // pragma inside a transaction anyway. Harmless for a step that only
        // creates tables, and the reason a future step that MOVES rows between
        // tables must either enable foreign keys before opening its own
        // transaction or finish with `PRAGMA foreign_key_check`.
        //
        // Order: `medicines` before `schedules`, so that the file is never left
        // holding a `schedules` table whose parent is missing if a future
        // change makes this step non-atomic again. It is not a SQLite
        // requirement -- SQLite resolves a foreign key's parent lazily, at the
        // first insert, so creating `schedules` first would work and creating
        // it against a parent that never arrives would fail only on write. An
        // earlier version of this comment claimed SQLite refuses the CREATE;
        // measured, it does not.
        await transaction(() async {
          await m.createTable(medicines);
          await m.createTable(schedules);
        });
        return;
      }

      // Any other gap is a development error -- AD-15 makes the migration step
      // mandatory -- or a downgrade. Both must fail loudly rather than run the
      // app against a schema that does not match the code. This is the branch
      // Story 1.3 could not reach with only one version in existence.
      throw AppDatabaseVersionMismatch(storedVersion: from, appVersion: to);
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite defaults foreign-key enforcement to OFF, per connection.
      // [Schedules.medicineId] is the schema's first foreign key, and AD-12's
      // "deleting a Medicine cascades to its Schedules and its Doses in one
      // transaction" is a promise the database keeps only while this is on.
      // Set by Story 1.3, one version before the first foreign key existed,
      // because a connection pragma set in one place cannot be half-applied.
      //
      // This runs AFTER `onCreate`/`onUpgrade`, not before: drift's
      // `beforeOpen` is "before the database is handed to the app", not
      // "before the migration". A migration step that needs foreign keys
      // enforced has to say so itself.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Thrown when the stored schema version is not the version this build expects.
///
/// Two distinguishable situations, both fatal to opening the database:
///
///   * **A downgrade** -- the file was written by a newer build. Its schema may
///     hold columns and tables this build has never heard of, so opening it
///     read-write risks writing rows the newer build cannot read back. Never
///     "recovered" by recreating the file: that is a health record with no
///     cloud copy.
///   * **A missing migration** -- the file is older than this build and no
///     migration step covers the gap. That is a development error (AD-15 makes
///     the step mandatory), and it must fail loudly rather than run against a
///     schema that does not match the code.
final class AppDatabaseVersionMismatch implements Exception {
  const AppDatabaseVersionMismatch({
    required this.storedVersion,
    required this.appVersion,
  });

  /// The `user_version` found in the file.
  final int storedVersion;

  /// The [AppDatabase.schemaVersion] this build was compiled with.
  final int appVersion;

  /// Whether the file was written by a newer build than this one.
  bool get isDowngrade => storedVersion > appVersion;

  /// The clause [toString] uses when the file is newer than the build.
  ///
  /// Public so the test asserts the sentence the user's log will actually
  /// carry, rather than a second copy of it written next to the assertion.
  /// `package:meta` is not a declared dependency of this project, so there is
  /// no `@visibleForTesting` to mark it with.
  static const String downgradeAdvice =
      'was written by a newer version of MediTracker';

  /// The clause [toString] uses when a migration step is missing. See
  /// [downgradeAdvice] for why it is public.
  static const String missingMigrationAdvice =
      'no migration step covers this upgrade';

  @override
  String toString() {
    final String cause = isDowngrade ? downgradeAdvice : missingMigrationAdvice;
    return 'AppDatabaseVersionMismatch: the database on this phone is at '
        'schema version $storedVersion and this build expects $appVersion -- '
        '$cause. No data has been changed.';
  }
}
