// Named constants for the parts of dose resolution and the escalation policy
// that are numbers rather than rules (AD-16, AD-19, AD-20).
//
// AD-1: pure Dart, no imports.
//
// The spine's Constants convention: "escalation defaults (+15 / +30 / +60),
// snooze length, the 04:00 boundary, the 14-day resolve window, and the
// notification budget are named constants in `domain/policy/`, overridable by
// `ReminderSettings`. No magic numbers in features or adapters." The 04:00
// boundary lives beside `logicalDay()` in `logical_day_policy.dart`; the rest
// of this story's numbers live here, beside `escalation_window_policy.dart`,
// which uses [escalationWindowMinimum] and [escalationWindowMaximum] to clamp.

/// How many days after its scheduled time a `Missed` Dose may still be
/// resolved by a user action, before `DoseRecorder` refuses one (AD-4).
///
/// This story only exposes the number and `Dose.isResolvable`; the refusal
/// itself belongs to `DoseRecorder`, which does not exist yet -- AD-4 puts the
/// enforcement there so that History and the Home day strip share one rule
/// instead of each carrying its own copy of this window.
const int doseResolveWindowDays = 14;

/// The default follow-up offsets, in minutes after a Dose's primary
/// reminder, that make up its escalation chain (AD-8, AD-16): +15, +30, +60.
///
/// Frozen onto a Dose at generation as `followUpOffsetsMinutes`, per AD-16 --
/// never re-read from `ReminderSettings` afterwards, so that widening this
/// list later cannot rewrite what a past Dose's chain looked like.
const List<int> defaultFollowUpOffsetsMinutes = <int>[15, 30, 60];

/// The floor the Escalation Window formula clamps to (AD-20): an interval to
/// the next dose small enough to divide to under an hour still gets a full
/// hour of grace before the chain starts.
const Duration escalationWindowMinimum = Duration(hours: 1);

/// The ceiling the Escalation Window formula clamps to (AD-20): a distant next
/// dose does not stretch the window past six hours, so a once-daily medicine
/// still escalates on a human timescale.
const Duration escalationWindowMaximum = Duration(hours: 6);
