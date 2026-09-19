// AD-4 -- the one caller permitted to record a Dose action.
//
// AD-1: pure Dart, `package:meta/` and `package:timezone/` only, transitively
// through `Dose`. This file's own imports are `Clock`, `DoseRepository`,
// `DoseNotifier`, `ReminderSettingsStore`, `Dose` and `DomainFailure` -- ports
// and sibling domain types, nothing platform-bound.
//
// This is a domain SERVICE, not a policy, matching `DoseGenerator`'s own
// reasoning: it orchestrates four ports (`Clock`, `DoseRepository`,
// `DoseNotifier`, `ReminderSettingsStore`) rather than computing a pure answer
// from arguments alone. It never computes a `DoseState` itself -- it writes
// facts and lets `dose_resolver.dart`'s `resolve()` report them, exactly as
// this story's Code Map requires.
//
// STORY 3.9 adds [_reminderSettings]: [snooze] now reads
// `ReminderSettings.snoozeIntervalMinutes` fresh on every call instead of the
// hardcoded `defaultSnoozeInterval` -- matching `snooze_policy.dart`'s own
// doc comment that every snooze reads the current value, so widening it later
// changes the next snooze, not a past one. `defaultSnoozeInterval` itself is
// not deleted: it remains a valid fresh-install/test-fixture default, equal
// to `ReminderSettings.freshInstallDefault.snoozeIntervalMinutes`.
//
// `test/architecture_test.dart`'s AD-4 rule is this story's permanent guard:
// no other hand-written file under `lib/` may name `takenAt:`, `skippedAt:`,
// `snoozedUntil:` or `snoozeCount:` in a `Dose(...)` or `.copyWith(...)` call.
// Two narrow, pre-existing exceptions predate this rule -- see that test
// file's own doc comment on `_doseWriteAllowlist` for
// `lib/data/repository/drift_dose_repository.dart` (reconstructing a stored
// row is not a new action) and `lib/domain/service/dose_generator.dart`
// (carrying an existing `snoozeCount` forward across regeneration).

import '../model/dose.dart';
import '../model/domain_failure.dart';
import '../port/clock.dart';
import '../port/dose_notifier.dart';
import '../port/dose_repository.dart';
import '../port/reminder_settings_store.dart';

/// Records a user's action against a `Dose` -- the only type permitted to
/// write `takenAt`, `skippedAt`, `snoozedUntil` or `snoozeCount` (AD-4).
///
/// Every action -- [take], [skip], [snooze] -- is one logical unit from the
/// caller's perspective (PRD §9): validate, write through [DoseRepository],
/// then cancel through [DoseNotifier], with both the write and the
/// cancellation awaited before the returned `Future` completes. A failure at
/// either step reports failure and confirms nothing: a repository failure
/// propagates before the notifier is ever called, and a notifier failure
/// still fails the whole action even though the write already landed --
/// there is no partial success reported to the caller either way.
final class DoseRecorder {
  /// Creates a recorder over [_clock], [_doses], [_notifier] and
  /// [_reminderSettings]. All four are ports (AD-1): this class never sees a
  /// Drift adapter or `flutter_local_notifications`, only what each port
  /// promises.
  DoseRecorder(
    this._clock,
    this._doses,
    this._notifier,
    this._reminderSettings,
  );

  final Clock _clock;
  final DoseRepository _doses;
  final DoseNotifier _notifier;
  final ReminderSettingsStore _reminderSettings;

  /// Records [dose] as taken at the current instant.
  ///
  /// Resolves Taken; `loggedLate` becomes `true` once `now` is past
  /// `dose.scheduledAt + dose.window` -- `resolve()`'s own computation, not
  /// repeated here. Refuses with [DoseNotYetDueFailure] when [dose] is
  /// scheduled in the future, and with [DoseNotResolvableFailure] once
  /// `Dose.isResolvable` reports the 14-day late-resolve window has closed.
  ///
  /// Re-reads the stored Dose rather than trusting a possibly-stale [dose]
  /// argument, and no-ops when it is already recorded taken -- so calling
  /// this twice in immediate succession, the double-tap this spec's own
  /// acceptance criteria names, writes once and cancels the notification
  /// once, not twice.
  Future<void> take(Dose dose) async {
    final DateTime now = _clock.now();
    final Dose current = await _doses.findDose(dose.id) ?? dose;
    if (current.takenAt != null) return;

    _checkActionable(current, now);

    await _doses.saveDose(current.copyWith(takenAt: now));
    await _notifier.cancelPending(current.id);
  }

  /// Records [dose] as skipped at the current instant.
  ///
  /// Resolves Skipped, permanently distinct from Missed -- `skippedAt` wins
  /// over every other fact once set (AD-2). Refused under the same two
  /// conditions as [take], and a Dose already recorded skipped is left
  /// exactly as it is, the same way [take] no-ops on a repeat call.
  Future<void> skip(Dose dose) async {
    final DateTime now = _clock.now();
    final Dose current = await _doses.findDose(dose.id) ?? dose;
    if (current.skippedAt != null) return;

    _checkActionable(current, now);

    await _doses.saveDose(current.copyWith(skippedAt: now));
    await _notifier.cancelPending(current.id);
  }

  /// Snoozes [dose] for the live `ReminderSettings.snoozeIntervalMinutes`
  /// from the current instant, incrementing `snoozeCount` (FR-8: no cap).
  ///
  /// Refuses with [SnoozeWindowExceededFailure] when `now + snoozeInterval`
  /// would fall at or past `dose.scheduledAt + dose.window` -- the PRD's own
  /// unconditional rule, enforced with the one comparison that already covers
  /// both a Due Dose about to cross into Overdue and one already there (this
  /// spec's Design Notes): if `now` is already past the boundary, `now +
  /// snoozeInterval` trivially is too, so there is no separate "already
  /// Overdue" branch.
  ///
  /// Also refused under [take]'s two conditions -- a Dose still in the future
  /// is never actionable, and the boundary check alone cannot tell "not due
  /// yet" from "safely inside the window", since both leave `now + interval`
  /// well before `scheduledAt + window`.
  ///
  /// Unlike [take] and [skip], a Dose already snoozed once is never a no-op:
  /// repeating a snooze is valid and increments the count again.
  Future<void> snooze(Dose dose) async {
    final DateTime now = _clock.now();
    final Dose current = await _doses.findDose(dose.id) ?? dose;

    _checkActionable(current, now);

    final int snoozeIntervalMinutes =
        (await _reminderSettings.load()).snoozeIntervalMinutes;
    final DateTime snoozedUntil = now.add(
      Duration(minutes: snoozeIntervalMinutes),
    );
    final DateTime overdueBoundary = current.scheduledAt.add(current.window);
    if (!snoozedUntil.isBefore(overdueBoundary)) {
      throw SnoozeWindowExceededFailure(current.id);
    }

    await _doses.saveDose(
      current.copyWith(
        snoozedUntil: snoozedUntil,
        snoozeCount: current.snoozeCount + 1,
      ),
    );
    await _notifier.cancelPending(current.id);
  }

  /// The two refusals every action shares (this story's frozen Boundaries):
  /// no action on a Dose still in the future, and none past the 14-day
  /// late-resolve window `Dose.isResolvable` already answers -- reusing it
  /// rather than reimplementing the day count.
  void _checkActionable(Dose dose, DateTime now) {
    if (now.isBefore(dose.scheduledAt)) {
      throw DoseNotYetDueFailure(dose.id);
    }
    if (!dose.isResolvable(now)) {
      throw DoseNotResolvableFailure(dose.id);
    }
  }
}

/// The base type of every failure [DoseRecorder] throws.
///
/// Sealed and grouped under [DomainFailure], matching
/// `MedicineRepositoryFailure` and `DoseRepositoryFailure`: a caller
/// switching over it is told by the compiler when a new refusal is added, and
/// `on DomainFailure` still catches every port's failures together.
sealed class DoseRecorderFailure extends DomainFailure {
  const DoseRecorderFailure();
}

/// [DoseRecorder] refused because the Dose's `scheduledAt` is still in the
/// future.
///
/// Not a row of its own in the spec's I/O matrix for [DoseRecorder.skip] or
/// [DoseRecorder.snooze], but the frozen Boundaries state the no-action-on-a-
/// future-Dose rule for every action, not [DoseRecorder.take] alone -- a Dose
/// that has not happened yet is no more skippable or snoozeable than it is
/// takeable.
final class DoseNotYetDueFailure extends DoseRecorderFailure {
  const DoseNotYetDueFailure(this.doseId);

  /// The Dose that was refused.
  final String doseId;

  @override
  String get message => 'This dose has not been reached yet.';
}

/// [DoseRecorder] refused because `Dose.isResolvable` reports the 14-day
/// late-resolve window has closed.
final class DoseNotResolvableFailure extends DoseRecorderFailure {
  const DoseNotResolvableFailure(this.doseId);

  /// The Dose that was refused.
  final String doseId;

  @override
  String get message =>
      'This dose is more than 14 days old and can no longer be updated.';
}

/// [DoseRecorder.snooze] refused because the requested snooze would end at or
/// past the Dose's overdue point.
///
/// Unconditional, per the PRD's own text: an already-Overdue Dose reaches
/// this the same way a Due one about to cross the boundary does -- see
/// [DoseRecorder.snooze]'s own doc comment for why one comparison covers both,
/// and never a separate "already Overdue" branch.
final class SnoozeWindowExceededFailure extends DoseRecorderFailure {
  const SnoozeWindowExceededFailure(this.doseId);

  /// The Dose that was refused.
  final String doseId;

  @override
  String get message => 'This dose is too close to its overdue time to snooze.';
}
