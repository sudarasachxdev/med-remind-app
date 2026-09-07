// The Drift adapter behind `OnboardingStateStore`.
//
// Named for the technology, as the spine's naming rule asks: the port is
// `OnboardingStateStore`, the adapter is `DriftOnboardingStateStore`. This is
// the only code that knows the flag is a column.

import 'package:drift/drift.dart';

import '../../domain/port/onboarding_state_store.dart';
import '../db/app_database.dart';

/// Reads and writes the onboarding flag in [AppDatabase]'s single settings row.
final class DriftOnboardingStateStore implements OnboardingStateStore {
  /// Wraps [database]. The instance is owned by the composition root (AD-3);
  /// this adapter neither opens nor closes it.
  const DriftOnboardingStateStore(this._database);

  final AppDatabase _database;

  @override
  Future<bool> isOnboardingComplete() async {
    // Deliberately not wrapped in a try/catch. A store that cannot be read has
    // to say so: swallowing the failure here and returning `false` would look
    // identical to a fresh install, and returning `true` would hide onboarding
    // from a first-time user. The caller decides what to do with the throw --
    // see `lib/main.dart`, which logs it and shows onboarding.
    final row =
        await (_database.select(_database.appSettings)
              ..where((AppSettings t) => t.id.equals(appSettingsRowId)))
            .getSingleOrNull();

    // No row is a genuine "not completed", not an error: nothing has written
    // settings yet.
    return row?.onboardingCompleted ?? false;
  }

  @override
  Future<void> markOnboardingComplete() async {
    // An upsert, because the row may or may not exist yet and the difference is
    // not interesting to the caller. But a TARGETED one: the `DoUpdate` writes
    // `onboardingCompleted` and nothing else.
    //
    // `insertOnConflictUpdate` was the obvious call and is the wrong one. It
    // updates every column of the row from a fully-populated companion, so the
    // day `AppSettings` gains the escalation window, the snooze length and the
    // reminder offsets it promises, this method would silently reset all three
    // to their constructor defaults -- and the port documents itself as safe to
    // call again from a future Settings surface, which is exactly where those
    // values would already be set. "Idempotent by construction" held only while
    // the table had one useful column.
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            id: const Value<int>(appSettingsRowId),
            onboardingCompleted: const Value<bool>(true),
          ),
          onConflict: DoUpdate<$AppSettingsTable, AppSetting>(
            (_) => const AppSettingsCompanion(
              onboardingCompleted: Value<bool>(true),
            ),
          ),
        );
  }
}
