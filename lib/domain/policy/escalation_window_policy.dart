// The Escalation Window formula (AD-16, AD-20): clamp(interval / 4, 1h, 6h),
// where the interval is measured to the next Dose of the *same Medicine*,
// across all of that Medicine's Schedules -- and, since Story 1.7b,
// [effectiveEscalationWindow], the one function AD-16 says resolves the
// effective policy for a Schedule "in a fixed order".
//
// AD-1: pure Dart. The only imports are the sibling `dose_resolution_policy`
// and `Schedule` -- this file does no zone arithmetic of its own; it only
// compares and subtracts the instants a caller hands it, and reads
// `Schedule.reminderOverride` as plain text.
//
// AD-20 exists because the formula alone admits three defensible readings --
// next dose of the same Schedule, of the same Medicine, or of any medicine --
// and only one of them reproduces the PRD's own worked example (twice-daily
// -> 3h). This file resolves the ambiguity once so it cannot be re-decided
// per call site.
//
// AD-16's full order is per-Schedule override -> app-wide override -> this
// formula. `app_settings` holds only `onboardingCompleted` (no `ReminderSettings`
// storage exists until FR-14's own story), so the middle rung has nowhere to
// live yet -- `effectiveEscalationWindow` implements the first and third rungs
// and leaves the middle named and unreachable, per spec-1-7b's own Boundaries
// and `deferred-work.md`, rather than inventing a home for it.

import '../model/schedule.dart';
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

/// The ISO-8601 time-duration subset `Schedule.reminderOverride` is written
/// in -- `PT` followed by any of an hour, minute and second component, each
/// a non-negative whole number, in that order. `PT45M` and `PT1H30M` match;
/// a bare `PT`, a date component (`P1D`) or a fractional value do not.
final RegExp _reminderOverridePattern = RegExp(
  r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
);

/// [raw] parsed as an Escalation Window override, or `null` when there is
/// none to apply.
///
/// `null` covers three cases alike, deliberately: [raw] itself is `null` (no
/// override was ever set), [raw] does not match the ISO-8601 shape above (a
/// row this build cannot read), or it parses to a non-positive duration
/// (`PT0M` names no window at all). None of the three is treated as a
/// generation-stopping error -- `reminderOverride` has no writer yet (FR-14's
/// settings surface is a later story), so every value seen in production
/// today is `null`, and a value this lenient a parse cannot make sense of is
/// safer read as "no override" than as a reason to abort an entire sweep
/// over one Schedule's stray text.
Duration? parseReminderOverride(String? raw) {
  if (raw == null) return null;
  final RegExpMatch? match = _reminderOverridePattern.firstMatch(raw);
  if (match == null) return null;

  final String? hours = match.group(1);
  final String? minutes = match.group(2);
  final String? seconds = match.group(3);
  if (hours == null && minutes == null && seconds == null) {
    return null; // `PT` alone names no duration.
  }

  final Duration parsed = Duration(
    hours: hours == null ? 0 : int.parse(hours),
    minutes: minutes == null ? 0 : int.parse(minutes),
    seconds: seconds == null ? 0 : int.parse(seconds),
  );
  return parsed > Duration.zero ? parsed : null;
}

/// Resolves the effective Escalation Window for a Dose of [schedule] due at
/// [current], per AD-16's fixed order -- the "one domain function" the
/// architecture names, and the file comment above for why only two of its
/// three rungs are reachable today:
///
///   1. [schedule]'s own [Schedule.reminderOverride], parsed by
///      [parseReminderOverride] -- used exactly as written, with no further
///      clamping. [clampEscalationWindow] belongs to the FORMULA (rung 3);
///      an explicit override is a deliberate value a person set, once
///      FR-14 ships a surface to set it, and silently narrowing it would
///      overrule their stated choice rather than compute one for them.
///   2. An app-wide override -- deliberately unreachable; see the file
///      comment.
///   3. [escalationWindowFor]'s formula, or [escalationWindowMaximum] when
///      [current] is its Medicine's genuinely last-ever occurrence and
///      [candidates] holds nothing later of the same Medicine -- this
///      spec's own completion of AD-20: there is no future dose left to
///      protect by escalating faster, so the ceiling is the defensible
///      default rather than a thrown error.
Duration effectiveEscalationWindow({
  required Schedule schedule,
  required DoseOccurrence current,
  required Iterable<DoseOccurrence> candidates,
}) {
  final Duration? override = parseReminderOverride(schedule.reminderOverride);
  if (override != null) return override;

  final bool hasLater = candidates.any(
    (DoseOccurrence candidate) =>
        candidate.medicineId == current.medicineId &&
        candidate.scheduledAt.isAfter(current.scheduledAt),
  );
  return hasLater
      ? escalationWindowFor(current: current, candidates: candidates)
      : escalationWindowMaximum;
}
