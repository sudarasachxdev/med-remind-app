// AD-8: the nearest [fullChainDoseCount] not-yet-acted Doses get the full
// escalation chain (primary, follow-up, final); the rest, up to
// [budgetedDoseCount], get the primary reminder only; anything beyond that
// gets nothing, until an earlier Dose resolves and the ranking shifts. AD-8
// forbids relying on the platform to trim an over-scheduled batch down to its
// own [notificationBudget] cap -- this file is what schedules deliberately
// within it instead.
//
// AD-1: pure Dart, no imports beyond `Dose` and `NotificationTier` -- a
// policy, not a service. No live caller yet: Story 3.5's `Reconciler` is the
// first, the same position `ReminderScheduler.schedulePrimary` and
// `DoseNotifier.schedule` were each in until their own callers arrived.

import '../model/dose.dart';
import 'notification_id_policy.dart';

/// How many of the nearest not-yet-acted Doses get the full escalation chain
/// (primary, follow-up, final) rather than the primary alone (AD-8).
const int fullChainDoseCount = 10;

/// The platform's own cap on pending notification requests (AD-8, iOS's
/// cited 64), which this product schedules deliberately within rather than
/// over-scheduling and relying on the OS to trim the excess down to the
/// soonest-firing requests.
const int notificationBudget = 64;

/// How many notifications one full chain spends: primary, follow-up and
/// final -- **not** four. `NotificationTier.snooze` is scheduled on demand
/// only when a Dose is actually snoozed, never as part of this ambient
/// chain, and is out of this policy's scope.
const int notificationChainLength = 3;

/// The total count of Doses that get any notification scheduled at all:
/// [fullChainDoseCount] Doses spend [notificationChainLength] slots each, and
/// every remaining slot in [notificationBudget] buys one more Dose a primary
/// reminder.
///
/// `10 + (64 - 10 * 3)` = `10 + 34` = **44**. Anything beyond the 44th
/// nearest Dose gets nothing, until an earlier one resolves and the ranking
/// shifts.
const int budgetedDoseCount =
    fullChainDoseCount +
    (notificationBudget - fullChainDoseCount * notificationChainLength);

/// Whether [dose] still needs its ambient primary/follow-up/final chain
/// scheduled, as of [now].
///
/// A new, stricter predicate than `dose_generator.dart`'s
/// `_isActedOnOrSnoozed` -- see this story's own Design Notes for why that
/// predicate's "any non-null `snoozedUntil` disqualifies" shape is wrong here:
/// an EXPIRED snooze answers this question the same way an unsnoozed Due dose
/// would (`dose_resolver.dart`'s own Snoozed-liveness check, `now <
/// snoozedUntil`), so this predicate only excludes a snooze that is still
/// live.
///
/// The final clause -- `now.isBefore(dose.scheduledAt)` -- excludes a Dose
/// already at or past its own scheduled time: it is Due, Overdue or Missed,
/// not Scheduled, so its primary has already fired (or should have) and it is
/// not a candidate for having one scheduled going forward.
bool needsChainConsidered(Dose dose, DateTime now) =>
    dose.takenAt == null &&
    dose.skippedAt == null &&
    !(dose.snoozedUntil != null && now.isBefore(dose.snoozedUntil!)) &&
    now.isBefore(dose.scheduledAt);

/// The notification tiers a Dose at [rank] (0-indexed, ascending by
/// `scheduledAt` among candidates already filtered by [needsChainConsidered])
/// should have scheduled.
///
/// The nearest [fullChainDoseCount] ranks (`0` through `9`) get the full
/// chain; the next ranks, through [budgetedDoseCount] exclusive (`10` through
/// `43`), get the primary alone; every rank from [budgetedDoseCount] onward
/// (`44` and beyond) gets nothing -- beyond budget.
List<NotificationTier> tiersForRank(int rank) {
  if (rank < 0) {
    throw ArgumentError.value(rank, 'rank', 'must not be negative');
  }
  if (rank < fullChainDoseCount) {
    return const <NotificationTier>[
      NotificationTier.primary,
      NotificationTier.followUp,
      NotificationTier.finalFollowUp,
    ];
  }
  if (rank < budgetedDoseCount) {
    return const <NotificationTier>[NotificationTier.primary];
  }
  return const <NotificationTier>[];
}

/// One candidate Dose, paired with the tiers [planBudget] assigned it. An
/// empty [tiers] means "beyond budget, nothing scheduled."
final class ScheduledTiers {
  /// Creates a pairing of [dose] with its assigned [tiers].
  const ScheduledTiers(this.dose, this.tiers);

  /// The candidate Dose.
  final Dose dose;

  /// The tiers assigned to [dose] by its rank in the list [planBudget] was
  /// called with. Empty when [dose] fell beyond [budgetedDoseCount].
  final List<NotificationTier> tiers;
}

/// Assigns [tiersForRank] to each of [candidates] by its index.
///
/// [candidates] is assumed already filtered by [needsChainConsidered] and
/// sorted ascending by `scheduledAt` -- this function does not re-filter or
/// re-sort it. No live caller yet (see this file's own header comment):
/// Story 3.5's `Reconciler` is the first.
List<ScheduledTiers> planBudget(List<Dose> candidates) => <ScheduledTiers>[
  for (int rank = 0; rank < candidates.length; rank++)
    ScheduledTiers(candidates[rank], tiersForRank(rank)),
];
