// The Drift adapter behind `ReminderSettingsStore`.
//
// Named for the technology, as the spine's naming rule asks: the port is
// `ReminderSettingsStore`, the adapter is `DriftReminderSettingsStore`. This
// is the only code that knows the five `ReminderSettings` fields are columns
// on the same `app_settings` row `DriftOnboardingStateStore` and
// `DriftReconciliationStateStore` each read and write their own columns on.

import 'package:drift/drift.dart';

import '../../domain/model/reminder_settings.dart';
import '../../domain/port/reminder_settings_store.dart';
import '../db/app_database.dart';

/// Reads and writes the five `ReminderSettings` columns in [AppDatabase]'s
/// single settings row.
final class DriftReminderSettingsStore implements ReminderSettingsStore {
  /// Wraps [database]. The instance is owned by the composition root (AD-3);
  /// this adapter neither opens nor closes it.
  const DriftReminderSettingsStore(this._database);

  final AppDatabase _database;

  @override
  Future<ReminderSettings> load() async {
    final AppSetting? row =
        await (_database.select(_database.appSettings)
              ..where((AppSettings t) => t.id.equals(appSettingsRowId)))
            .getSingleOrNull();

    // No row is a genuine "nothing stored yet", not an error -- the same
    // reading `DriftOnboardingStateStore.isOnboardingComplete` and
    // `DriftReconciliationStateStore.lastKnownIanaTimezone` give their own
    // absent row.
    if (row == null) return ReminderSettings.freshInstallDefault;

    return ReminderSettings(
      remindersEnabledDefault: row.remindersEnabledDefault,
      followUpOffsetsMinutes: <int>[
        row.followUpOffsetMinutes1,
        row.followUpOffsetMinutes2,
      ],
      escalationWindowOverrideMinutes: row.escalationWindowOverrideMinutes,
      snoozeIntervalMinutes: row.snoozeIntervalMinutes,
    );
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    final String? error = settings.validationError;
    if (error != null) {
      throw ReminderSettingsNotValidFailure(error);
    }

    // An upsert, because the row may or may not exist yet. But a TARGETED
    // one: the `DoUpdate` writes exactly these five columns and nothing else
    // -- `insertOnConflictUpdate` would replace the whole row from a
    // fully-populated companion, silently resetting `onboardingCompleted` and
    // `lastKnownIanaTimezone` back to their constructor defaults, for exactly
    // the reason `DriftReconciliationStateStore.saveLastKnownIanaTimezone`'s
    // own doc comment gives.
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            id: const Value<int>(appSettingsRowId),
            remindersEnabledDefault: Value<bool>(
              settings.remindersEnabledDefault,
            ),
            followUpOffsetMinutes1: Value<int>(
              settings.followUpOffsetsMinutes[0],
            ),
            followUpOffsetMinutes2: Value<int>(
              settings.followUpOffsetsMinutes[1],
            ),
            escalationWindowOverrideMinutes: Value<int?>(
              settings.escalationWindowOverrideMinutes,
            ),
            snoozeIntervalMinutes: Value<int>(settings.snoozeIntervalMinutes),
          ),
          onConflict: DoUpdate<$AppSettingsTable, AppSetting>(
            (_) => AppSettingsCompanion(
              remindersEnabledDefault: Value<bool>(
                settings.remindersEnabledDefault,
              ),
              followUpOffsetMinutes1: Value<int>(
                settings.followUpOffsetsMinutes[0],
              ),
              followUpOffsetMinutes2: Value<int>(
                settings.followUpOffsetsMinutes[1],
              ),
              escalationWindowOverrideMinutes: Value<int?>(
                settings.escalationWindowOverrideMinutes,
              ),
              snoozeIntervalMinutes: Value<int>(settings.snoozeIntervalMinutes),
            ),
          ),
        );
  }
}
