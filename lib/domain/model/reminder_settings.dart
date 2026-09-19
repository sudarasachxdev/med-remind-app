// App-wide reminder defaults (FR-14): what a Schedule with no explicit
// override falls back to, and the app-wide rung `effectiveEscalationWindow`
// was built (Story 1.7b) with a parameter for but nothing to fill it with,
// until this story.
//
// AD-1: pure Dart, no imports.
//
// AD-16's full resolution order is per-Schedule override -> app-wide override
// -> the AD-20 formula. This class is the middle rung's own value, and the
// only new type this story adds to `domain/model/` -- everything else it
// touches (`Schedule`, `Dose`, `escalation_window_policy.dart`) already
// existed with a named, deliberately-unreachable gap waiting for it.
//
// [followUpOffsetsMinutes] is a clean 2-entry list, distinct from
// `Dose.followUpOffsetsMinutes`'s own frozen 3-entry shape (`dose.dart`'s own
// doc comment, `dose_resolution_policy.dart`'s `defaultFollowUpOffsetsMinutes`).
// The third entry on a Dose has never been a real notification offset --
// Story 3.2's own established finding -- so it is not a setting anyone should
// be able to configure, and giving THIS model only two entries keeps that
// vestigial slot from ever being mistaken for a third configurable value.
// `DoseGenerator._upsert` still builds the 3-entry `Dose` shape existing code
// expects, splicing the untouched constant's own third entry back in.
//
// [escalationWindowOverrideMinutes] is `int?` minutes, not
// `Schedule.reminderOverride`'s own `PT#H#M#S` text. Both name "a duration,
// possibly absent" for one resolution chain, but they do not need one shared
// encoding to stay consistent: `Schedule.reminderOverride` is opaque text
// because Story 1.6 gave it a type before the policy that reads it existed
// (`schedule.dart`'s own doc comment) -- a constraint that does not apply
// here, since this field and `parseReminderOverride` both post-date each
// other by nothing. Storing plain minutes lets `validationError`'s own
// ordering rule compare it against `followUpOffsetsMinutes` (also minutes)
// directly, with no parse step on every check, and lets
// `DriftReminderSettingsStore` write and read a plain `IntColumn` with no
// format to get wrong. `DoseGenerator` converts it to the `Duration?`
// `effectiveEscalationWindow.appWideOverride` expects with one multiplication,
// not a call to `parseReminderOverride`.

/// The app-wide reminder defaults FR-14 names: whether reminders are on by
/// default, the two follow-up offsets, the app-wide Escalation Window
/// override (or Automatic), and the snooze length.
final class ReminderSettings {
  /// Creates a ReminderSettings. [followUpOffsetsMinutes] must hold exactly
  /// two entries -- the caller's responsibility, matching `Schedule`'s own
  /// constructor-time checks; nothing here defends against a malformed list,
  /// because every caller in this codebase builds one from a literal or from
  /// [freshInstallDefault].
  const ReminderSettings({
    required this.remindersEnabledDefault,
    required this.followUpOffsetsMinutes,
    required this.escalationWindowOverrideMinutes,
    required this.snoozeIntervalMinutes,
  });

  /// Whether a newly-created Schedule reminds by default (FR-14).
  final bool remindersEnabledDefault;

  /// The two follow-up offsets, in minutes after a Dose's primary reminder,
  /// in chain order -- `[0]` the nearer one, `[1]` the final one. Exactly two
  /// entries; see this file's own header comment for why not three.
  final List<int> followUpOffsetsMinutes;

  /// The app-wide Escalation Window override, in minutes, or `null` for
  /// Automatic (AD-20's formula) -- AD-16's own middle resolution rung.
  final int? escalationWindowOverrideMinutes;

  /// The app-wide snooze length, in minutes (`DoseRecorder.snooze`'s own live
  /// read, replacing the hardcoded `defaultSnoozeInterval`).
  final int snoozeIntervalMinutes;

  /// The values a fresh install carries before anyone has changed a Settings
  /// toggle -- this story's own acceptance criterion: reminders on, +15/+30
  /// follow-ups, Automatic escalation window, a 15-minute snooze. Equal to
  /// `defaultFollowUpOffsetsMinutes`'s first two entries and
  /// `defaultSnoozeInterval`, by design: nothing behaves differently the
  /// instant this story ships, only once a user actually changes a value.
  static const ReminderSettings freshInstallDefault = ReminderSettings(
    remindersEnabledDefault: true,
    followUpOffsetsMinutes: <int>[15, 30],
    escalationWindowOverrideMinutes: null,
    snoozeIntervalMinutes: 15,
  );

  /// Why this ReminderSettings' timing values are out of order, or `null`
  /// when they are not.
  ///
  /// Mirrors `Schedule.pairingViolation()`'s own shape: a nullable-string
  /// check returned as a message rather than thrown, so a future Settings
  /// screen can show why a combination is unavailable rather than merely
  /// refusing it (this story's own acceptance criterion). The ordering rule:
  /// the nearer follow-up must come before the final one, and when a fixed
  /// escalation window is set, the final follow-up must come before it too --
  /// "a follow-up at or after the final, or an overdue before the final" is
  /// invalid.
  String? get validationError {
    final int first = followUpOffsetsMinutes[0];
    final int second = followUpOffsetsMinutes[1];
    if (first >= second) {
      return 'The first follow-up must come before the final follow-up.';
    }

    final int? window = escalationWindowOverrideMinutes;
    if (window != null && second >= window) {
      return 'The final follow-up must come before the escalation window.';
    }

    return null;
  }

  /// A copy with the given fields replaced.
  ///
  /// [escalationWindowOverrideMinutes] cannot be cleared back to `null`
  /// (Automatic) through this method -- `null` means "not supplied", matching
  /// `Schedule.copyWith`/`Dose.copyWith`'s own rule. A caller returning to
  /// Automatic constructs a `ReminderSettings` directly, the same way an
  /// edit that drops `Schedule.daysOfWeek` does.
  ReminderSettings copyWith({
    bool? remindersEnabledDefault,
    List<int>? followUpOffsetsMinutes,
    int? escalationWindowOverrideMinutes,
    int? snoozeIntervalMinutes,
  }) => ReminderSettings(
    remindersEnabledDefault:
        remindersEnabledDefault ?? this.remindersEnabledDefault,
    followUpOffsetsMinutes:
        followUpOffsetsMinutes ?? this.followUpOffsetsMinutes,
    escalationWindowOverrideMinutes:
        escalationWindowOverrideMinutes ?? this.escalationWindowOverrideMinutes,
    snoozeIntervalMinutes: snoozeIntervalMinutes ?? this.snoozeIntervalMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.remindersEnabledDefault == remindersEnabledDefault &&
      _sameOffsets(other.followUpOffsetsMinutes, followUpOffsetsMinutes) &&
      other.escalationWindowOverrideMinutes ==
          escalationWindowOverrideMinutes &&
      other.snoozeIntervalMinutes == snoozeIntervalMinutes;

  @override
  int get hashCode => Object.hash(
    remindersEnabledDefault,
    Object.hashAll(followUpOffsetsMinutes),
    escalationWindowOverrideMinutes,
    snoozeIntervalMinutes,
  );

  static bool _sameOffsets(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ReminderSettings(remindersEnabledDefault: $remindersEnabledDefault, '
      'followUpOffsetsMinutes: $followUpOffsetsMinutes, '
      'escalationWindowOverrideMinutes: $escalationWindowOverrideMinutes, '
      'snoozeIntervalMinutes: $snoozeIntervalMinutes)';
}
