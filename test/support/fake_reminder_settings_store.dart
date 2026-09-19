// A scriptable `ReminderSettingsStore` for tests that need a real answer to
// let `DoseGenerator`/`DoseRecorder` complete, but have no `AppDatabase` of
// their own in scope to build a `DriftReminderSettingsStore` over --
// mirroring `fake_onboarding_state_store.dart`'s own reasoning.
//
// Not a mock framework: one mutable field covers every test that needs to
// change the live settings mid-test, and [save] enforces the same
// `validationError` refusal `DriftReminderSettingsStore` does, so a test
// exercising the failure path sees the same behaviour it would against real
// storage.

import 'package:med_remind_app/domain/model/reminder_settings.dart';
import 'package:med_remind_app/domain/port/reminder_settings_store.dart';

/// An in-memory [ReminderSettingsStore], starting at
/// [ReminderSettings.freshInstallDefault] unless told otherwise.
final class FakeReminderSettingsStore implements ReminderSettingsStore {
  FakeReminderSettingsStore({
    this.settings = ReminderSettings.freshInstallDefault,
  });

  /// The current settings [load] answers. Mutable so a test can read it back
  /// after a write without going through [load], which would count as a
  /// read.
  ReminderSettings settings;

  @override
  Future<ReminderSettings> load() async => settings;

  @override
  Future<void> save(ReminderSettings settings) async {
    final String? error = settings.validationError;
    if (error != null) {
      throw ReminderSettingsNotValidFailure(error);
    }
    this.settings = settings;
  }
}
