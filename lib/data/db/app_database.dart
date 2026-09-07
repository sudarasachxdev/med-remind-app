// The application database, at schema version 1.
//
// AD-3 — one process opens the database. One `AppDatabase` is constructed, in
// `lib/main.dart`, and handed to the adapters that need it. Nothing else calls
// this constructor at runtime; tests construct their own over an in-memory
// executor.
//
// AD-15 — every schema change ships a migration and a schema test. Version 1 is
// creation rather than change, so [MigrationStrategy.onCreate] is the whole of
// it; `test/db_schema_test.dart` pins the shape it creates, so Story 1.4's move
// to version 2 has something to migrate *from* that is asserted rather than
// assumed. There is deliberately no `deleteOnFailure`-style recovery: the spine
// prohibits it, and a health record with no cloud copy must never be discarded
// because it failed to open once.
//
// This story owns exactly one table. Medicine, Schedule and Dose belong to
// Stories 1.4 and 1.7.

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

/// The Drift database. Schema version 1: one table, [AppSettings].
@DriftDatabase(tables: [AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database, or [executor] when one is supplied.
  ///
  /// [executor] exists for tests, which pass `NativeDatabase.memory()`. It is
  /// not a second production path: `lib/main.dart` calls this with no argument.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: appDatabaseName));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    // Drift calls onUpgrade for ANY version mismatch, downgrades included, and
    // its default implementation throws "you didn't provide a strategy" --
    // which is true of a forward step and misleading about a backward one. A
    // downgraded build would hit that message on every open, for ever, with
    // nothing naming the actual situation. So both directions are named here.
    //
    // Neither is recoverable in this story, and neither pretends to be: the
    // failure travels up through the startup read, which logs it, reports it
    // and shows onboarding rather than hanging. Story 4.7 owns the recovery
    // surface (AD-18); this owns saying what went wrong.
    onUpgrade: (Migrator m, int from, int to) async {
      throw AppDatabaseVersionMismatch(storedVersion: from, appVersion: to);
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite defaults foreign-key enforcement to OFF, per connection. Story
      // 1.4's `schedules` table is the first with a foreign key, and AD-12's
      // "deleting a Medicine cascades to its Schedules and its Doses in one
      // transaction" is a promise the database keeps only while this is on.
      // Set here rather than in 1.4 because this is the file that opens with
      // an AD-15 policy statement, and a connection pragma set in one place
      // cannot be half-applied.
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
