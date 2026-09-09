// The Escalation Window formula (AD-16, AD-20): clamp(interval / 4, 1h, 6h),
// where the interval is measured to the next Dose of the *same Medicine*,
// across all of that Medicine's Schedules.
//
// AD-1: pure Dart, no imports -- this file does no zone arithmetic of its
// own; it only compares and subtracts the instants a caller hands it.
//
// AD-20 exists because the formula alone admits three defensible readings --
// next dose of the same Schedule, of the same Medicine, or of any medicine --
// and only one of them reproduces the PRD's own worked example (twice-daily
// -> 3h). This file resolves the ambiguity once so it cannot be re-decided
// per call site.

import 'dose_resolution_policy.dart';

/// One candidate to consider when measuring the interval to the next dose
/// (AD-20).
///
/// Deliberately lighter than a full `Dose`: this formula runs at generation
/// time, over occurrences a `Schedule` can produce, before some of them are
/// necessarily materialised as `Dose` rows. All it needs is which Medicine an
/// occurrence belongs to and when it falls.
typedef DoseOccurrence = ({String medicineId, DateTime scheduledAt});

/// [interval] passed through AD-20's clamp: no less than
/// [escalationWindowMinimum], no more than [escalationWindowMaximum].
Duration clampEscalationWindow(Duration interval) {
  if (interval < escalationWindowMinimum) return escalationWindowMinimum;
  if (interval > escalationWindowMaximum) return escalationWindowMaximum;
  return interval;
}

/// The Escalation Window for a dose of [current]'s Medicine scheduled at
/// [current]'s time, given every other known occurrence in [candidates].
///
/// AD-20: only candidates sharing [current]'s `medicineId` are considered --
/// a nearer dose belonging to a different Medicine is ignored -- and only
/// those strictly after [current]'s `scheduledAt`. Among those, the earliest
/// is "the next dose"; its distance from [current], quartered and clamped, is
/// the answer. This is Schedule-blind by design: a next dose on a *different*
/// Schedule of the same Medicine counts exactly the same as one on the same
/// Schedule, which is what makes the PRD's twice-daily example (two Schedules,
/// 12h apart -> 3h) come out right.
///
/// [candidates] should include the Medicine's own occurrences on later
/// covered days, not only today's -- when nothing later remains today, the
/// next covered day's first dose is what "the next dose" means, and this
/// function does not special-case "today" at all: it simply picks the
/// earliest same-Medicine candidate after [current], wherever it falls.
///
/// Throws [ArgumentError] when no candidate qualifies. A dose generated for an
/// active Medicine always has a later occurrence of that Medicine within the
/// generation horizon (AD-10); a caller reaching this with none has asked the
/// question about a Medicine that is ending, which the formula was never
/// meant to answer.
Duration escalationWindowFor({
  required DoseOccurrence current,
  required Iterable<DoseOccurrence> candidates,
}) {
  DateTime? nextDoseAt;
  for (final DoseOccurrence candidate in candidates) {
    if (candidate.medicineId != current.medicineId) continue;
    if (!candidate.scheduledAt.isAfter(current.scheduledAt)) continue;
    if (nextDoseAt == null || candidate.scheduledAt.isBefore(nextDoseAt)) {
      nextDoseAt = candidate.scheduledAt;
    }
  }

  if (nextDoseAt == null) {
    throw ArgumentError.value(
      candidates,
      'candidates',
      'no later occurrence of medicine ${current.medicineId} was supplied; '
          'the Escalation Window formula (AD-20) needs one to measure an '
          'interval from',
    );
  }

  final Duration interval = nextDoseAt.difference(current.scheduledAt);
  final Duration quarter = Duration(microseconds: interval.inMicroseconds ~/ 4);
  return clampEscalationWindow(quarter);
}
