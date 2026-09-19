// The binding between the `ReminderSettings` port and whatever implements it.
//
// Declared with no implementation on purpose, matching
// `reconciliationStateStoreProvider`'s own reasoning: `lib/main.dart`
// overrides it with the Drift adapter over the single `AppDatabase` this
// process opens (AD-3); tests override it with a fake or a second Drift
// instance over their own in-memory database. A default that quietly
// constructed a real database would open a second connection from inside a
// test the moment something read this provider, which is the failure AD-3
// exists to prevent.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/reminder_settings_store.dart';

/// The [ReminderSettingsStore] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read -- never a plausible default
/// that silently reports the fresh-install defaults forever, which would make
/// a real saved Settings change invisible to `DoseGenerator`/`DoseRecorder`.
final Provider<ReminderSettingsStore> reminderSettingsStoreProvider =
    Provider<ReminderSettingsStore>((ref) {
      throw UnimplementedError(
        'reminderSettingsStoreProvider must be overridden at the composition '
        'root. lib/main.dart binds it to DriftReminderSettingsStore over the '
        'one AppDatabase this process opens (AD-3).',
      );
    });
