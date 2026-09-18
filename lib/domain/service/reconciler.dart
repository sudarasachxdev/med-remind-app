// AD-9's one caller of the whole reconciliation pipeline: the single entry
// point that ties Stories 3.2-3.4's previously-caller-less mechanisms
// together, with exactly one production call site
// (`HomePlanController.build()`).
//
// AD-1: pure Dart, `package:meta/` and `package:timezone/` only, transitively
// through `Dose`. This file's own imports are `Clock`, `MedicineRepository`,
// `DoseRepository`, `DoseGenerator`, `ReminderScheduler`, `DoseNotifier`,
// `ReconciliationStateStore`, `Medicine`, `Schedule`, `Dose` and the budget
// policy -- ports, sibling domain services and sibling domain types, nothing
// platform-bound.
//
// A domain SERVICE, not a policy, matching `DoseGenerator`/`DoseRecorder`'s
// own reasoning: it orchestrates seven ports/services rather than computing a
// pure answer from arguments alone -- a higher-level orchestrator composing
// already-built ones.
//
// AD-5: this class holds a `Clock` and reads `_clock.now()` itself; a caller
// never passes `now` in, matching `DoseRecorder`'s own convention.
//
// PRODUCT DECISION, 2026-09-17: when the device's timezone changes, active
// Schedules follow the user to the new zone -- "8:00 AM" means 8:00 AM
// wherever they now are. This is why step 2 below updates
// `Schedule.ianaTimezone` itself, not merely `Dose.scheduledUtc`.
//
// A LOAD-BEARING FACT THIS DESIGN RESTS ON: `Dose.scheduledAt` is never a
// cached value read back into a Dart object -- `DriftDoseRepository
// ._doseFromRow` always reconstructs a `Dose` from its stored
// `scheduledLocal`/`ianaTimezone`, and the constructor always re-derives
// `scheduledAt` from those two. `scheduled_utc` exists purely for the
// database's own ordering/range queries and is never read back into a `Dose`.
// So "recompute `scheduledUtc` where the zone moved" needs no separate
// persistence step of its own: it is automatically true the moment a
// Schedule's zone is updated and its Doses are regenerated
// (`DoseGenerator.regenerateAfterScheduleChange`) -- regeneration's own
// `saveDose` calls write the correct `scheduled_utc` as a matter of course.

import '../model/dose.dart';
import '../model/medicine.dart';
import '../model/schedule.dart';
import '../policy/dose_resolution_policy.dart';
import '../policy/notification_budget_policy.dart';
import '../port/clock.dart';
import '../port/dose_notifier.dart';
import '../port/dose_repository.dart';
import '../port/medicine_repository.dart';
import '../port/reconciliation_state_store.dart';
import 'dose_generator.dart';
import 'reminder_scheduler.dart';

/// Performs AD-9's five reconciliation steps, in order, on every call to
/// [run].
///
/// This is the only class permitted to call [DoseGenerator.
/// regenerateAfterScheduleChange] in reaction to a Schedule's own
/// `ianaTimezone` changing (AD-9: "reacting to a zone change is the
/// Reconciler's alone"), and the only class permitted to call
/// [ReminderScheduler.schedulePrimary] or [DoseNotifier.cancelPending] at all
/// -- "nothing else in the codebase re-registers notifications".
final class Reconciler {
  /// Creates a reconciler over every port/service AD-9's pipeline needs. All
  /// seven are ports or already-built domain services (AD-1): this class
  /// never sees a Drift adapter or `flutter_local_notifications` directly.
  Reconciler(
    this._clock,
    this._medicines,
    this._doses,
    this._doseGenerator,
    this._reminderScheduler,
    this._notifier,
    this._reconciliationState,
  );

  final Clock _clock;
  final MedicineRepository _medicines;
  final DoseRepository _doses;
  final DoseGenerator _doseGenerator;
  final ReminderScheduler _reminderScheduler;
  final DoseNotifier _notifier;
  final ReconciliationStateStore _reconciliationState;

  /// Runs AD-9's five steps, in order:
  ///
  ///   1. **Detect timezone change.** Compares [Clock.ianaTimezone] against
  ///      the stored last-known zone. A `null` stored value (first run ever)
  ///      does not count as a change -- there is nothing to react to yet.
  ///   2. **React, if changed.** Every Schedule of every Medicine whose zone
  ///      differs from the current one is saved with the updated zone and
  ///      regenerated, regardless of its Medicine's active state -- a paused
  ///      medicine's schedule should still reflect where the user actually
  ///      is, and [DoseGenerator.regenerateAfterScheduleChange]'s own
  ///      active-state check already no-ops the dose side of it for an
  ///      inactive Medicine.
  ///   3. **Persist the current zone**, unconditionally -- establishes the
  ///      baseline on a first run, a no-op write otherwise.
  ///   4. **Generate missing Doses** to the horizon, unconditionally.
  ///      Idempotent (AD-10) alongside step 2's own regeneration.
  ///   5. **Re-register notifications within budget** -- cancels every
  ///      candidate's pending notifications, then schedules a primary for
  ///      every candidate [planBudget] assigns a non-empty tier list.
  ///
  /// Step 6, "surface any permission or scheduling degradation", needs no
  /// code here: `HomePlan.notificationsDenied`/`exactAlarmsDenied`/
  /// `budgetExceeded` are all computed fresh on every `HomePlanController
  /// .build()`, independent of when this method last ran.
  Future<void> run() async {
    final DateTime now = _clock.now();
    final String currentZone = _clock.ianaTimezone;

    final String? lastKnownZone = await _reconciliationState
        .lastKnownIanaTimezone();
    final bool zoneChanged =
        lastKnownZone != null && lastKnownZone != currentZone;

    if (zoneChanged) {
      await _reactToZoneChange(currentZone, now);
    }

    await _reconciliationState.saveLastKnownIanaTimezone(currentZone);

    await _doseGenerator.generate(now);

    await _reregisterWithinBudget(now);
  }

  /// AD-9 step 2: every Schedule of every Medicine whose [Schedule
  /// .ianaTimezone] differs from [currentZone] follows the user to it.
  Future<void> _reactToZoneChange(String currentZone, DateTime now) async {
    for (final Medicine medicine in await _medicines.allMedicines()) {
      for (final Schedule schedule in await _medicines.schedulesFor(
        medicine.id,
      )) {
        if (schedule.ianaTimezone == currentZone) continue;

        final Schedule updated = schedule.copyWith(ianaTimezone: currentZone);
        await _medicines.saveSchedule(updated);
        await _doseGenerator.regenerateAfterScheduleChange(updated, now);
      }
    }
  }

  /// AD-9 step 5, AD-8: cancels every candidate's pending notifications, then
  /// schedules a primary reminder for every candidate [planBudget] did not
  /// leave beyond budget.
  Future<void> _reregisterWithinBudget(DateTime now) async {
    final DateTime today = Medicine.dateOnly(now);
    final DateTime horizonEnd = today.add(
      const Duration(days: doseResolveWindowDays),
    );

    final List<Dose> visible = await _doses.dosesScheduledBetween(
      today,
      horizonEnd,
    );

    final Map<String, bool> remindersEnabledByScheduleId = <String, bool>{};
    for (final Medicine medicine in await _medicines.allMedicines()) {
      for (final Schedule schedule in await _medicines.schedulesFor(
        medicine.id,
      )) {
        remindersEnabledByScheduleId[schedule.id] = schedule.remindersEnabled;
      }
    }

    final List<Dose> candidates =
        visible
            .where(
              (Dose dose) =>
                  needsChainConsidered(dose, now) &&
                  (remindersEnabledByScheduleId[dose.scheduleId] ?? false),
            )
            .toList()
          ..sort((Dose a, Dose b) => a.scheduledAt.compareTo(b.scheduledAt));

    for (final ScheduledTiers entry in planBudget(candidates)) {
      await _notifier.cancelPending(entry.dose.id);
      if (entry.tiers.isNotEmpty) {
        await _reminderScheduler.schedulePrimary(
          entry.dose,
          remindersEnabled: true,
        );
      }
    }
  }
}
