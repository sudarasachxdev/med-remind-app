// AD-2 — Dose State is derived, never stored. The one function.
//
// AD-1: pure Dart, `package:meta/` and `package:timezone/` only, transitively
// through `logical_day_policy.dart`.
//
// This is a transcription of AD-2's pseudocode, in its exact branch order --
// the spine's Code Map says to transcribe it, not re-derive it:
//
//   d.skippedAt != null                          -> Skipped
//   d.takenAt   != null                          -> Taken
//                                                    (loggedLate = ...)
//   d.snoozedUntil != null && now < snoozedUntil -> Snoozed
//   now < d.scheduledAt                          -> Scheduled
//   now < d.scheduledAt + d.window               -> Due
//   logicalDay(now, d.tz) == logicalDay(d.scheduledAt, d.tz) -> Overdue
//   otherwise                                    -> Missed
//
// Order is the rule, not an implementation detail (AD-2): a user action
// always wins over elapsed time -- Skipped is checked even when Taken is also
// true, and Taken is checked before a live Snooze -- and an expired Snooze
// falls through to the time-driven branches on its own rather than being
// special-cased.
//
// `now` is a plain parameter, not the `Clock` port: a pure function that
// reads a port is not pure, and AD-19's whole point is that this rule is
// provable with no clock at all. Callers hold the port; `resolve()` holds
// none.
//
// `d.window` -- AD-2's `p.window` -- comes from `dose.window`, itself read
// from `dose.escalationWindowMinutes`, which was frozen onto the Dose at
// generation (AD-16). There is deliberately no second `EscalationPolicy`
// parameter here: reading the window from live `ReminderSettings` instead
// would let a Settings change retroactively rewrite whether a past Dose was
// late.

import '../model/dose.dart';
import '../model/dose_state.dart';
import 'logical_day_policy.dart';

/// Derives [dose]'s current [DoseResolution] as of [now], applying AD-2's
/// branches in their exact order.
DoseResolution resolve(Dose dose, DateTime now) {
  if (dose.skippedAt != null) {
    return DoseResolution(DoseState.skipped);
  }

  final DateTime? takenAt = dose.takenAt;
  if (takenAt != null) {
    final bool loggedLate = takenAt.isAfter(dose.scheduledAt.add(dose.window));
    return DoseResolution(DoseState.taken, loggedLate: loggedLate);
  }

  final DateTime? snoozedUntil = dose.snoozedUntil;
  if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
    return DoseResolution(DoseState.snoozed);
  }

  if (now.isBefore(dose.scheduledAt)) {
    return DoseResolution(DoseState.scheduled);
  }

  if (now.isBefore(dose.scheduledAt.add(dose.window))) {
    return DoseResolution(DoseState.due);
  }

  final bool sameLogicalDay =
      logicalDay(now, dose.ianaTimezone) ==
      logicalDay(dose.scheduledAt, dose.ianaTimezone);
  if (sameLogicalDay) {
    return DoseResolution(DoseState.overdue);
  }

  return DoseResolution(DoseState.missed);
}
