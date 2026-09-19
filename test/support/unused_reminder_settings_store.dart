// A ReminderSettingsStore that exists to be bound, not called.
//
// Mirrors `unused_reconciliation_state_store.dart`/`unused_dose_repository.dart`
// /`unused_medicine_repository.dart`/`unused_permission_gateway.dart`: the
// startup tests assert that the composition root BINDS a store -- dropping
// that override is invisible until `DoseGenerator`/`DoseRecorder` reaches it,
// and then it throws in front of the user. They assert nothing about what it
// answers.
//
// So every method throws, deliberately. A fake that quietly answered the
// fresh-install default would let a test pass while silently exercising a
// store that backs no real settings row.

import 'package:med_remind_app/domain/model/reminder_settings.dart';
import 'package:med_remind_app/domain/port/reminder_settings_store.dart';

/// A [ReminderSettingsStore] whose every method throws [UnsupportedError].
final class UnusedReminderSettingsStore implements ReminderSettingsStore {
  /// Creates the stand-in.
  const UnusedReminderSettingsStore();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedReminderSettingsStore.$method was called. This stand-in exists to '
    'be bound by a startup test, not to answer. Use DriftReminderSettingsStore '
    'over an in-memory database, or FakeReminderSettingsStore, if the test '
    'needs real storage.',
  );

  @override
  Future<ReminderSettings> load() => _unused('load');

  @override
  Future<void> save(ReminderSettings settings) => _unused('save');
}
