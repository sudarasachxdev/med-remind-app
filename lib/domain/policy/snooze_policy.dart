// The snooze length `DoseRecorder` applies (AD-4).
//
// AD-1: pure Dart, no imports.
//
// The spine's Constants convention: "escalation defaults (+15 / +30 / +60),
// snooze length, the 04:00 boundary, the 14-day resolve window, and the
// notification budget are named constants in `domain/policy/`, overridable by
// `ReminderSettings`. No magic numbers in features or adapters." The 04:00
// boundary lives beside `logicalDay()` in `logical_day_policy.dart`, and the
// escalation/resolve-window numbers already live in
// `dose_resolution_policy.dart`; this is the snooze length's own home, added
// once `DoseRecorder` exists to need it (Story 2.1).

/// How long a snooze lasts, measured from the instant it is recorded (AD-4).
///
/// Resolved 2026-09-10: 15 minutes, matching the escalation chain's own first
/// follow-up offset in `defaultFollowUpOffsetsMinutes`. A named constant here
/// rather than a literal inside `DoseRecorder`, per the spine's Constants
/// convention -- and, unlike `escalationWindowMinutes`, never frozen onto a
/// `Dose`: every snooze reads this same current value, so widening it later
/// changes the next snooze, not a past one.
const Duration defaultSnoozeInterval = Duration(minutes: 15);
