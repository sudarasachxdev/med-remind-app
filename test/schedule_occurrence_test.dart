// One test per Frequency-pattern row of this spec's I/O matrix, plus the
// start/end-date boundary rows. Testing depth is LIGHTER (project-context.md):
// pure date math with nothing to lose, so one test per row and no mutation
// testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/policy/schedule_occurrence_policy.dart';

Schedule _schedule({
  required Frequency frequency,
  Set<int>? daysOfWeek,
  int? intervalDays,
  String timeOfDay = '08:00',
}) => Schedule(
  id: 'schedule-1',
  medicineId: 'medicine-1',
  timeOfDay: timeOfDay,
  ianaTimezone: 'Asia/Colombo',
  frequency: frequency,
  daysOfWeek: daysOfWeek,
  intervalDays: intervalDays,
  dosageAmount: 1,
);

void main() {
  // A Wednesday -- FixedClock's own reference day -- so weekday-dependent
  // rows below have a known, unambiguous starting point.
  final DateTime today = DateTime(2026, 9, 9);
  final DateTime horizonEnd = today.add(const Duration(days: 13));

  test('every day: one occurrence per day, all 14 days of the horizon', () {
    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(frequency: Frequency.everyDay),
      medicineStartDate: today,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    expect(occurrences, hasLength(14));
    expect(occurrences.first, DateTime(2026, 9, 9, 8, 0));
    expect(occurrences.last, DateTime(2026, 9, 22, 8, 0));
  });

  test('weekdays: only Monday through Friday within the horizon', () {
    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(frequency: Frequency.weekdays),
      medicineStartDate: today,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    // Sep 9-22 2026 holds two weekends (12-13 and 19-20): 14 days minus 4.
    expect(occurrences, hasLength(10));
    expect(
      occurrences.every(
        (DateTime d) =>
            d.weekday >= DateTime.monday && d.weekday <= DateTime.friday,
      ),
      isTrue,
    );
  });

  test('specific days: only the named weekdays within the horizon', () {
    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.monday, DateTime.thursday},
      ),
      medicineStartDate: today,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    expect(occurrences, <DateTime>[
      DateTime(2026, 9, 10, 8, 0), // Thu
      DateTime(2026, 9, 14, 8, 0), // Mon
      DateTime(2026, 9, 17, 8, 0), // Thu
      DateTime(2026, 9, 21, 8, 0), // Mon
    ]);
  });

  test('every N days: counted from the Medicine\'s start date, not reset to '
      '"today"', () {
    // startDate is 5 days before the horizon begins. If the cadence reset
    // to "today" instead of counting from startDate, day 0 of the horizon
    // would be an occurrence; it is 5 days after the real anchor (5 % 3 !=
    // 0) and must NOT appear.
    final DateTime startDate = today.subtract(const Duration(days: 5));

    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(frequency: Frequency.everyNDays, intervalDays: 3),
      medicineStartDate: startDate,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    expect(occurrences, <DateTime>[
      DateTime(2026, 9, 10, 8, 0),
      DateTime(2026, 9, 13, 8, 0),
      DateTime(2026, 9, 16, 8, 0),
      DateTime(2026, 9, 19, 8, 0),
      DateTime(2026, 9, 22, 8, 0),
    ]);
  });

  test('start date mid-horizon: no occurrence before it', () {
    final DateTime startDate = today.add(const Duration(days: 3));

    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(frequency: Frequency.everyDay),
      medicineStartDate: startDate,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    expect(occurrences, hasLength(11)); // days 3..13 inclusive.
    expect(occurrences.first, DateTime(2026, 9, 12, 8, 0));
  });

  test('end date mid-horizon: no occurrence after it, even though the horizon '
      'extends further', () {
    final DateTime endDate = today.add(const Duration(days: 5));

    final List<DateTime> occurrences = occurrencesFor(
      schedule: _schedule(frequency: Frequency.everyDay),
      medicineStartDate: today,
      medicineEndDate: endDate,
      rangeStart: today,
      rangeEnd: horizonEnd,
    );

    expect(occurrences, hasLength(6)); // days 0..5 inclusive.
    expect(occurrences.last, DateTime(2026, 9, 14, 8, 0));
  });
}
