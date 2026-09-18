// The Drift adapter behind `ReconciliationStateStore`.
//
// Named for the technology, as the spine's naming rule asks: the port is
// `ReconciliationStateStore`, the adapter is `DriftReconciliationStateStore`.
// This is the only code that knows the zone is a column -- and that it is the
// same `app_settings` row `DriftOnboardingStateStore` reads and writes its own
// column on.

import 'package:drift/drift.dart';

import '../../domain/port/reconciliation_state_store.dart';
import '../db/app_database.dart';

/// Reads and writes the last-known zone in [AppDatabase]'s single settings
/// row.
final class DriftReconciliationStateStore implements ReconciliationStateStore {
  /// Wraps [database]. The instance is owned by the composition root (AD-3);
  /// this adapter neither opens nor closes it.
  const DriftReconciliationStateStore(this._database);

  final AppDatabase _database;

  @override
  Future<String?> lastKnownIanaTimezone() async {
    final row =
        await (_database.select(_database.appSettings)
              ..where((AppSettings t) => t.id.equals(appSettingsRowId)))
            .getSingleOrNull();

    // No row is a genuine "nothing recorded yet", not an error -- the same
    // reading `DriftOnboardingStateStore.isOnboardingComplete` gives its own
    // absent row.
    return row?.lastKnownIanaTimezone;
  }

  @override
  Future<void> saveLastKnownIanaTimezone(String zone) async {
    // An upsert, because the row may or may not exist yet. But a TARGETED
    // one: the `DoUpdate` writes `lastKnownIanaTimezone` and nothing else.
    //
    // `insertOnConflictUpdate` was the obvious call and is the wrong one, for
    // exactly the reason `DriftOnboardingStateStore.markOnboardingComplete`'s
    // own doc comment gives: it updates every column of the row from a
    // fully-populated companion, so this write would silently reset
    // `onboardingCompleted` back to its constructor default the moment a
    // fresh install's onboarding flag and its first-ever zone recording raced
    // each other. A targeted upsert makes that impossible rather than
    // merely unlikely.
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            id: const Value<int>(appSettingsRowId),
            lastKnownIanaTimezone: Value<String?>(zone),
          ),
          onConflict: DoUpdate<$AppSettingsTable, AppSetting>(
            (_) => AppSettingsCompanion(
              lastKnownIanaTimezone: Value<String?>(zone),
            ),
          ),
        );
  }
}
