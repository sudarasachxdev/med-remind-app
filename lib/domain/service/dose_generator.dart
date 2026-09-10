// `DoseGenerator` -- expands every active Medicine's Schedules into Doses
// over the rolling horizon, and the cleanup-then-regenerate operation a
// future Schedule edit will need (AD-10, as amended 2026-09-10; AD-11;
// AD-16; AD-20).
//
// AD-1: pure Dart, `package:meta/` (transitively, through `Dose`) and
// `package:timezone/` only. This file imports `package:timezone/timezone.dart`
// itself, to read "today" in each Schedule's own zone, exactly as
// `logical_day_policy.dart` already does under the 2026-09-09 amendment.
// `package:timezone/standalone.dart` and `package:timezone/data/*.dart` are
// never imported here: loading the zone database is the composition root's
// job and the test suite's `setUp`, never a domain file's own.
//
// This is a domain SERVICE, not a policy: it orchestrates two ports
// (`MedicineRepository`, `DoseRepository`) rather than computing a pure
// answer from arguments alone, which is why it lives in `domain/service/`
// rather than beside `schedule_occurrence_policy.dart`, the pure function it
// calls. Depending on a port is not an AD-1 violation -- `AddMedicineController`
// already depends on `MedicineRepository` the same way, and neither ever
// imports a Drift adapter.
//
// STORY 1.7B ENDS HERE, exactly as Story 1.6 and 1.7a ended at a policy and a
// port with no caller. No `Reconciler` exists yet to call `generate()`
// (Epic 3, AD-9) -- `test/story_scope_test.dart` guards the composition root
// against an early binding.

import 'package:timezone/timezone.dart' as tz;

import '../model/dose.dart';
import '../model/frequency.dart';
import '../model/medicine.dart';
import '../model/schedule.dart';
import '../policy/dose_resolution_policy.dart';
import '../policy/escalation_window_policy.dart';
import '../policy/schedule_occurrence_policy.dart';
import '../port/dose_repository.dart';
import '../port/medicine_repository.dart';

/// Sweeps every active Medicine's Schedules to the rolling horizon, and
/// rebuilds one Schedule's future Doses after its shape changes.
final class DoseGenerator {
  /// Creates a generator over [_medicines] and [_doses]. Both are ports
  /// (AD-1): this class never sees a Drift adapter, only what
  /// `MedicineRepository` and `DoseRepository` promise.
  DoseGenerator(this._medicines, this._doses);

  final MedicineRepository _medicines;
  final DoseRepository _doses;

  /// Generates every Dose due within [doseResolveWindowDays] of [now], for
  /// every Medicine with [Medicine.active] `true`.
  ///
  /// Idempotent (AD-10): a Dose already stored under its natural key is
  /// upserted with the same values, unless it has been acted on or is
  /// currently snoozed, in which case it is left untouched. Calling this
  /// twice with the same [now] and no state change in between writes nothing
  /// new -- this spec's own acceptance criterion -- and never deletes
  /// anything; only [regenerateAfterScheduleChange] does that.
  ///
  /// An inactive Medicine is skipped entirely for GENERATION -- no new Dose is
  /// written for it. This method never deletes anything, active Medicine or
  /// not: it is the purely-additive half of AD-10, and cleaning up a paused
  /// Medicine's existing future Doses is [regenerateAfterScheduleChange]'s job,
  /// since pausing is itself one of AD-10's three cleanup triggers.
  Future<void> generate(DateTime now) async {
    for (final Medicine medicine in await _medicines.allMedicines()) {
      if (!medicine.active) continue;
      await _generateForMedicine(medicine, now);
    }
  }

  /// AD-10's cleanup rule for one Schedule: deletes [schedule]'s own future,
  /// un-acted Doses -- stale once its time, Frequency or day set has
  /// changed -- and then regenerates, exactly as [generate] would for
  /// [schedule]'s Medicine.
  ///
  /// [schedule] is assumed already saved in its new shape through
  /// `MedicineRepository.saveSchedule`: the regenerate half re-reads every
  /// Schedule of the Medicine from [_medicines] rather than trusting
  /// [schedule] alone, so a sibling Schedule's own escalation window is
  /// recomputed too. AD-20's formula is medicine-wide, not schedule-local --
  /// regenerating only [schedule] in isolation could leave a sibling's window
  /// frozen against a candidate occurrence that no longer exists.
  ///
  /// A Dose already acted on, or currently snoozed, is never deleted --
  /// [schedule] changing does not undo a dose the user already recorded
  /// against its old time. Nothing is deleted at or before [now] either: only
  /// a genuinely future occurrence is stale, not one already showing as due,
  /// overdue or missed under the old shape.
  ///
  /// AD-10 names three cleanup triggers: a Schedule's time, its Frequency, or
  /// its Medicine's **active state**. `Schedule` carries no `active` field of
  /// its own, so that third trigger is `Medicine.active` -- meaning pausing a
  /// Medicine is itself one of the changes this method exists to clean up
  /// after, not an exemption from it. The delete below therefore runs
  /// unconditionally: a future, un-acted Dose is stale the moment ANY of the
  /// three things it was generated under has changed, whether or not the
  /// Medicine is still active afterwards. Leaving a paused Medicine's future
  /// Doses in place is exactly AD-10's named failure -- "strands the old
  /// Doses on Home" -- applied to pausing instead of a time change.
  ///
  /// Only the SECOND half -- regenerating -- is conditional on the Medicine
  /// still being active, matching [generate]'s own rule that an inactive
  /// Medicine gets no new Doses. If the Medicine no longer exists at all
  /// (impossible under AD-12's cascade, guarded anyway), nothing further
  /// happens either.
  Future<void> regenerateAfterScheduleChange(
    Schedule schedule,
    DateTime now,
  ) async {
    for (final Dose dose in await _doses.dosesForSchedule(schedule.id)) {
      if (_isActedOnOrSnoozed(dose)) continue;
      if (!dose.scheduledAt.isAfter(now)) continue;
      await _doses.deleteDose(dose.id);
    }

    final Medicine? medicine = await _medicines.findMedicine(
      schedule.medicineId,
    );
    if (medicine == null || !medicine.active) return;

    await _generateForMedicine(medicine, now);
  }

  /// The sweep for one Medicine, assumed already checked active by the
  /// caller. Shared by [generate] and [regenerateAfterScheduleChange] so the
  /// two never compute an escalation window differently for the same
  /// Medicine.
  Future<void> _generateForMedicine(Medicine medicine, DateTime now) async {
    final List<Schedule> schedules = await _medicines.schedulesFor(medicine.id);
    if (schedules.isEmpty) return;

    // One horizon end per Schedule, not one for the whole Medicine: two
    // Schedules of the same Medicine can carry different `ianaTimezone`s (a
    // user who travelled between adding them), and "today" -- the horizon's
    // own start day -- is read in each Schedule's own zone, never the
    // device's (AD-6, AD-9).
    final Map<String, List<DateTime>> inHorizon = <String, List<DateTime>>{};
    final Map<String, DateTime?> lookahead = <String, DateTime?>{};

    for (final Schedule schedule in schedules) {
      final tz.Location location = tz.getLocation(schedule.ianaTimezone);
      final DateTime today = _calendarDate(tz.TZDateTime.from(now, location));
      final DateTime horizonEnd = today.add(
        const Duration(days: doseResolveWindowDays - 1),
      );

      inHorizon[schedule.id] = occurrencesFor(
        schedule: schedule,
        medicineStartDate: medicine.startDate,
        medicineEndDate: medicine.endDate,
        rangeStart: today,
        rangeEnd: horizonEnd,
      );

      // AD-20's interval calculation may look past the horizon (this spec's
      // own Boundaries): one occurrence beyond it, per Schedule, never
      // persisted, is enough to answer "what's next" for whichever occurrence
      // turns out to be this Medicine's last one inside the horizon. Bounded
      // to the widest gap this Schedule's own Frequency can ever leave, so a
      // real next occurrence is never missed by searching too narrow a
      // window, and an ended Medicine correctly yields nothing here instead
      // of a false one.
      final List<DateTime> beyond = occurrencesFor(
        schedule: schedule,
        medicineStartDate: medicine.startDate,
        medicineEndDate: medicine.endDate,
        rangeStart: horizonEnd.add(const Duration(days: 1)),
        rangeEnd: horizonEnd.add(Duration(days: _maxGapDays(schedule))),
      );
      lookahead[schedule.id] = beyond.isEmpty ? null : beyond.first;
    }

    // The AD-20 candidate pool for this Medicine: every in-horizon occurrence
    // across all its Schedules, plus each Schedule's single beyond-horizon
    // lookahead -- see `escalation_window_policy.dart`'s doc comment, which
    // anticipates exactly this kind of unpersisted candidate.
    final List<DoseOccurrence> pool = <DoseOccurrence>[];
    for (final Schedule schedule in schedules) {
      for (final DateTime local in inHorizon[schedule.id]!) {
        pool.add((
          medicineId: medicine.id,
          scheduledAt: _instantOf(local, schedule.ianaTimezone),
        ));
      }
      final DateTime? beyondLocal = lookahead[schedule.id];
      if (beyondLocal != null) {
        pool.add((
          medicineId: medicine.id,
          scheduledAt: _instantOf(beyondLocal, schedule.ianaTimezone),
        ));
      }
    }

    for (final Schedule schedule in schedules) {
      for (final DateTime local in inHorizon[schedule.id]!) {
        await _upsert(
          medicine: medicine,
          schedule: schedule,
          local: local,
          pool: pool,
        );
      }
    }
  }

  /// Writes one occurrence, unless a stored Dose on its natural key has
  /// already been acted on or is currently snoozed (AD-10).
  Future<void> _upsert({
    required Medicine medicine,
    required Schedule schedule,
    required DateTime local,
    required List<DoseOccurrence> pool,
  }) async {
    final String id = _idFor(schedule.id, local);
    final Dose? existing = await _doses.findDose(id);
    if (existing != null && _isActedOnOrSnoozed(existing)) return;

    final DateTime instant = _instantOf(local, schedule.ianaTimezone);
    // AD-16's full resolution order -- schedule's own override, then the
    // AD-20 formula (with this spec's ceiling completion for a Medicine's
    // genuinely last-ever occurrence); see `effectiveEscalationWindow`'s own
    // doc comment for why the middle, app-wide rung is not reachable here.
    final Duration window = effectiveEscalationWindow(
      schedule: schedule,
      current: (medicineId: medicine.id, scheduledAt: instant),
      candidates: pool,
    );

    await _doses.saveDose(
      Dose(
        scheduleId: schedule.id,
        medicineId: medicine.id,
        scheduledLocal: local,
        ianaTimezone: schedule.ianaTimezone,
        // An expired snooze (`snoozedUntil` in the past, so it already fell
        // through to a time-driven state per AD-2) still keeps its count; only
        // a CURRENTLY-active snooze skips the write entirely, above.
        snoozeCount: existing?.snoozeCount ?? 0,
        escalationWindowMinutes: window.inMinutes,
        medicineName: medicine.name,
        dosageAmount: schedule.dosageAmount,
        dosageUnit: medicine.dosageUnit,
        form: medicine.form,
      ),
    );
  }

  static bool _isActedOnOrSnoozed(Dose dose) =>
      dose.takenAt != null ||
      dose.skippedAt != null ||
      dose.snoozedUntil != null;

  /// Mirrors `Dose`'s own id derivation (`"{scheduleId}:{scheduledLocal
  /// ISO-8601}"`) so a stored row can be looked up before the `Dose` it
  /// belongs to is built.
  static String _idFor(String scheduleId, DateTime scheduledLocal) =>
      '$scheduleId:${scheduledLocal.toIso8601String()}';

  /// [instant] read as a wall-clock date in [location] -- "today" for one
  /// Schedule's own horizon, never the device's current zone (AD-6, AD-9).
  static DateTime _calendarDate(tz.TZDateTime instant) =>
      DateTime(instant.year, instant.month, instant.day);

  /// [local] -- a wall-clock time with no zone of its own -- as an absolute
  /// instant in [ianaTimezone]. Mirrors the private `Dose._asInstant`: needed
  /// here to build the AD-20 candidate pool before the `Dose` these instants
  /// belong to can be constructed.
  static DateTime _instantOf(DateTime local, String ianaTimezone) {
    final tz.Location location = tz.getLocation(ianaTimezone);
    return tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  /// The widest gap [schedule]'s own Frequency can ever leave between two
  /// consecutive occurrences -- how far past the horizon the AD-20 lookahead
  /// must search to be certain of finding a real one, if the Medicine has not
  /// ended by then.
  static int _maxGapDays(Schedule schedule) {
    switch (schedule.frequency) {
      case Frequency.everyDay:
        return 1;
      case Frequency.weekdays:
      case Frequency.specificDays:
        return 7;
      case Frequency.everyNDays:
        return schedule.intervalDays!;
    }
  }
}
