// The port through which the app reads and writes the app-wide
// `ReminderSettings` FR-14 names (Story 3.9).
//
// AD-1: pure Dart. This file imports the sibling `ReminderSettings` model and
// `DomainFailure` and nothing else -- not Drift, not Flutter -- because the
// domain must not know the settings live in a SQLite row any more than
// `OnboardingStateStore` knows there is an onboarding screen.
// `lib/data/repository/drift_reminder_settings_store.dart` is the adapter;
// `test/architecture_test.dart` fails the build if a `package:` import other
// than `package:meta/` appears anywhere under `lib/domain/`.
//
// Named for the role, not the technology (the spine's naming rule): a *store*
// of settings, matching `OnboardingStateStore`/`ReconciliationStateStore`'s
// own reasoning -- these five fields are one app-wide singleton fact, not an
// aggregate with an identity and a lifecycle of its own, so calling this a
// repository would claim a shape it does not have.

import '../model/domain_failure.dart';
import '../model/reminder_settings.dart';

/// Reads and writes the app-wide `ReminderSettings`.
abstract interface class ReminderSettingsStore {
  /// The stored settings, or [ReminderSettings.freshInstallDefault] when
  /// nothing has been saved yet.
  ///
  /// Never throws for "nothing stored yet" -- matching
  /// `DriftOnboardingStateStore.isOnboardingComplete`'s own absent-row
  /// handling: a fresh install and a row inserted for some other setting both
  /// answer the documented fresh-install default, not an exception.
  Future<ReminderSettings> load();

  /// Writes [settings] over whatever is stored.
  ///
  /// Throws [ReminderSettingsNotValidFailure] when
  /// `settings.validationError` is non-null, and writes nothing -- mirrors
  /// `MedicineRepository.addSchedule`'s own `ScheduleNotValidFailure` shape.
  Future<void> save(ReminderSettings settings);
}

/// The base type of every failure [ReminderSettingsStore] throws.
///
/// Sealed and grouped under [DomainFailure], matching
/// `MedicineRepositoryFailure`/`DoseRecorderFailure`: a single member today,
/// but the family root is what lets a caller write `on
/// ReminderSettingsStoreFailure` and mean it, rather than naming the one
/// concrete failure directly.
sealed class ReminderSettingsStoreFailure extends DomainFailure {
  const ReminderSettingsStoreFailure();
}

/// [ReminderSettingsStore.save] refused because `ReminderSettings
/// .validationError` reported one.
///
/// Carries that message, which is written to be shown as it stands -- see
/// `ReminderSettings.validationError`'s own doc comment.
final class ReminderSettingsNotValidFailure
    extends ReminderSettingsStoreFailure {
  const ReminderSettingsNotValidFailure(this.message);

  @override
  final String message;
}
