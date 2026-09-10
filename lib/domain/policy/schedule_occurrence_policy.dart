// Expands a Schedule's Frequency into the calendar days it produces an
// occurrence on, over a caller-supplied range (FR-4, AD-10).
//
// AD-1: pure Dart. The only imports are the sibling `Frequency` and
// `Schedule` models -- no `package:timezone/`, because every date this file
// touches arrives and leaves as a bare calendar day. Turning an absolute
// `now` into "today, in this Schedule's own zone" is `DoseGenerator`'s job
// (`lib/domain/service/dose_generator.dart`), which has the zone database
// available to it under the same 2026-09-09 AD-1 amendment `dose.dart` and
// `logical_day_policy.dart` already use; this file only decides, given a
// day, whether the Frequency lands on it.
//
// This is deliberately NOT `Schedule.occupiedDaysOfWeek`. That getter
// over-claims all seven days for `Frequency.everyNDays` on purpose, for the
// clash-detection heuristic `DriftMedicineRepository._requireNoClash` runs --
// treating every-3-days as "could be any day" is the right, conservative
// answer for "might these two Schedules collide", and the wrong answer for
// "on which days does this Schedule actually fire". This file is the one
// place FR-4's four patterns are decided for the second question, so
// `DoseGenerator` is its only caller and `occupiedDaysOfWeek` keeps meaning
// only what the clash check needs it to mean.

import '../model/frequency.dart';
import '../model/schedule.dart';

/// Every calendar day [schedule] produces an occurrence on, from
/// [rangeStart] through [rangeEnd] inclusive, honouring the owning
/// Medicine's [medicineStartDate] and [medicineEndDate].
///
/// All four `DateTime` parameters are calendar dates -- any time-of-day
/// component is ignored, exactly like `Medicine.startDate`/`endDate`
/// themselves (see `Medicine.dateOnly`). [medicineStartDate] and
/// [medicineEndDate] clip the range before any Frequency pattern is applied:
/// a day before the Medicine started or after it ended never reaches
/// [Frequency]'s own branch below, which is what makes the "start date
/// mid-horizon" and "end date mid-horizon" rows of this spec's I/O matrix
/// hold without either of the four patterns needing to know about the
/// boundary itself.
///
/// Returned as **local wall-clock** `DateTime`s -- [Schedule.timeOfDay]'s
/// hour and minute, merged onto each qualifying day -- ascending, one per
/// qualifying day. Each is ready to become a `Dose.scheduledLocal` once
/// paired with [Schedule.ianaTimezone]; see the file comment for why no zone
/// arithmetic happens here.
///
/// [Frequency.everyNDays] counts from [medicineStartDate] -- never from
/// [rangeStart] or "today" -- per this spec's own rule: two generation runs
/// with different `now` values must land on the same dates for the same
/// Schedule, which only holds if the cadence is anchored to a fixed point
/// rather than reset on every call.
List<DateTime> occurrencesFor({
  required Schedule schedule,
  required DateTime medicineStartDate,
  DateTime? medicineEndDate,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final DateTime anchor = _dateOnly(medicineStartDate);
  final DateTime? ends = medicineEndDate == null
      ? null
      : _dateOnly(medicineEndDate);

  DateTime day = _dateOnly(rangeStart);
  if (day.isBefore(anchor)) day = anchor;
  DateTime last = _dateOnly(rangeEnd);
  if (ends != null && last.isAfter(ends)) last = ends;

  final int hour = int.parse(schedule.timeOfDay.substring(0, 2));
  final int minute = int.parse(schedule.timeOfDay.substring(3, 5));

  final List<DateTime> occurrences = <DateTime>[];
  while (!day.isAfter(last)) {
    if (_frequencyMatches(schedule, day, anchor)) {
      occurrences.add(DateTime(day.year, day.month, day.day, hour, minute));
    }
    day = day.add(const Duration(days: 1));
  }
  return occurrences;
}

/// Whether [schedule]'s [Schedule.frequency] lands on [day] -- the one place
/// FR-4's four patterns are decided. [anchor] is the owning Medicine's own
/// start date, already clamped into the range by [occurrencesFor].
bool _frequencyMatches(Schedule schedule, DateTime day, DateTime anchor) {
  switch (schedule.frequency) {
    case Frequency.everyDay:
      return true;
    case Frequency.weekdays:
      return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
    case Frequency.specificDays:
      return (schedule.daysOfWeek ?? const <int>{}).contains(day.weekday);
    case Frequency.everyNDays:
      // Counted from the Medicine's own start date, never from `day` -- see
      // this file's doc comment. `schedule.intervalDays` is non-null here:
      // every Schedule this function is handed came from `MedicineRepository`,
      // which refuses to hand back a pairing-invalid row (see
      // `DriftMedicineRepository._scheduleFromRow`).
      final int intervalDays = schedule.intervalDays!;
      return day.difference(anchor).inDays % intervalDays == 0;
  }
}

/// [value]'s calendar date, normalised through UTC field construction so that
/// a difference or a day-by-day walk this file computes is never bent by the
/// HOST machine's own local DST transitions.
///
/// This re-reads [value]'s year/month/day and re-labels them UTC; it does
/// NOT call `.toUtc()`, which would shift the instant by an offset instead of
/// keeping the calendar date. The same defence `logicalDayPolicy.logicalDay`
/// takes for its "previous day" rollback, and for the same reason: a
/// local-to-local `DateTime` subtraction can read as 23 or 25 hours on the
/// two days a year the HOST's zone changes, which would misfire the
/// `everyNDays` cadence by exactly one day at exactly the moment nobody is
/// looking to catch it.
DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
