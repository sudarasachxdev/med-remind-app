// One test per row of spec-1-6's I/O matrix, plus the acceptance criteria
// that restate a row as a named claim. Testing depth is LIGHTER
// (project-context.md): one test per row, an injected `now` rather than a
// `Clock`, no mutation testing -- this story writes nothing to disk.
//
// `tzdata.initializeTimeZones()` runs once in `setUpAll`, per the house rule
// that only the composition root and test `setUp` call it -- never domain
// code (AD-1, 2026-09-09 amendment).

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/dose_state.dart';
import 'package:med_remind_app/domain/model/logical_day.dart';
import 'package:med_remind_app/domain/policy/dose_resolver.dart';
import 'package:med_remind_app/domain/policy/logical_day_policy.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Dose _dose({
  String medicineId = 'medicine-1',
  String scheduleId = 'schedule-1',
  required DateTime scheduledLocal,
  String ianaTimezone = 'Asia/Colombo',
  DateTime? takenAt,
  DateTime? skippedAt,
  DateTime? snoozedUntil,
  int escalationWindowMinutes = 60,
}) => Dose(
  scheduleId: scheduleId,
  medicineId: medicineId,
  scheduledLocal: scheduledLocal,
  ianaTimezone: ianaTimezone,
  takenAt: takenAt,
  skippedAt: skippedAt,
  snoozedUntil: snoozedUntil,
  escalationWindowMinutes: escalationWindowMinutes,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // A Wednesday, 08:00 Asia/Colombo (a fixed +05:30 offset, no DST) ->
  // 2026-09-09T02:30:00Z. Most rows build on this one scheduled instant.
  final DateTime scheduledLocal = DateTime(2026, 9, 9, 8, 0);
  final DateTime scheduledAt = DateTime.utc(2026, 9, 9, 2, 30);

  test('before the time -> Scheduled', () {
    final dose = _dose(scheduledLocal: scheduledLocal);
    final now = scheduledAt.subtract(const Duration(minutes: 1));

    expect(resolve(dose, now).state, DoseState.scheduled);
  });

  test('inside the window -> Due', () {
    final dose = _dose(scheduledLocal: scheduledLocal);
    final now = scheduledAt.add(const Duration(minutes: 30));

    expect(resolve(dose, now).state, DoseState.due);
  });

  test('window elapsed, same logical day -> Overdue', () {
    final dose = _dose(scheduledLocal: scheduledLocal);
    // 15:30 local, same calendar day as the 08:00 scheduled time.
    final now = DateTime.utc(2026, 9, 9, 10, 0);

    expect(resolve(dose, now).state, DoseState.overdue);
  });

  test('logical day advanced -> Missed', () {
    final dose = _dose(scheduledLocal: scheduledLocal);
    // 04:30 local the next day -- past the 04:00 boundary.
    final now = DateTime.utc(2026, 9, 9, 23, 0);

    expect(resolve(dose, now).state, DoseState.missed);
  });

  test('taken -> Taken, loggedLate == false', () {
    final dose = _dose(
      scheduledLocal: scheduledLocal,
      takenAt: scheduledAt.add(const Duration(minutes: 5)),
    );
    final now = scheduledAt.add(const Duration(hours: 3));

    final resolution = resolve(dose, now);
    expect(resolution.state, DoseState.taken);
    expect(resolution.loggedLate, isFalse);
  });

  test('taken after the window -> Taken, loggedLate == true', () {
    final dose = _dose(
      scheduledLocal: scheduledLocal,
      takenAt: scheduledAt.add(const Duration(minutes: 61)),
    );
    final now = scheduledAt.add(const Duration(hours: 3));

    final resolution = resolve(dose, now);
    expect(resolution.state, DoseState.taken);
    expect(resolution.loggedLate, isTrue);
  });

  test(
    'skipped beats everything, even a takenAt on the same Dose -> Skipped',
    () {
      // The acceptance criterion this story names explicitly: proving the
      // branch order is the rule, not an accident of the happy path.
      final dose = _dose(
        scheduledLocal: scheduledLocal,
        takenAt: scheduledAt.add(const Duration(minutes: 5)),
        skippedAt: scheduledAt.add(const Duration(minutes: 10)),
      );
      final now = scheduledAt.add(const Duration(hours: 3));

      expect(resolve(dose, now).state, DoseState.skipped);
    },
  );

  test('taken beats a live snooze -> Taken', () {
    final dose = _dose(
      scheduledLocal: scheduledLocal,
      takenAt: scheduledAt.add(const Duration(minutes: 5)),
      snoozedUntil: scheduledAt.add(const Duration(hours: 2)),
    );
    final now = scheduledAt.add(const Duration(minutes: 30));

    expect(resolve(dose, now).state, DoseState.taken);
  });

  test('snooze live -> Snoozed', () {
    final dose = _dose(
      scheduledLocal: scheduledLocal,
      snoozedUntil: scheduledAt.add(const Duration(hours: 2)),
    );
    final now = scheduledAt.add(const Duration(minutes: 90));

    expect(resolve(dose, now).state, DoseState.snoozed);
  });

  test('snooze expired -> falls through to the time-driven branches, no '
      'mutation, Overdue here', () {
    final dose = _dose(
      scheduledLocal: scheduledLocal,
      snoozedUntil: scheduledAt.add(const Duration(minutes: 20)),
    );
    // Window (60min) has elapsed and the snooze (20min) has long expired,
    // but it is still the same logical day.
    final now = scheduledAt.add(const Duration(hours: 4));

    final resolution = resolve(dose, now);
    expect(resolution.state, DoseState.overdue);
    // Nothing about resolve() can mutate the Dose -- it is a pure function
    // over immutable facts -- so re-resolving gives the identical answer.
    expect(resolve(dose, now), resolution);
  });

  test('04:00 boundary, before -> still Monday\'s logical day, Overdue', () {
    final monday23 = DateTime(2026, 9, 7, 23, 0); // Monday 23:00
    final dose = _dose(scheduledLocal: monday23);
    // 03:59 Tuesday local == 22:29 UTC Monday.
    final now = DateTime.utc(2026, 9, 7, 22, 29);

    expect(resolve(dose, now).state, DoseState.overdue);
  });

  test('04:00 boundary, after -> Missed', () {
    final monday23 = DateTime(2026, 9, 7, 23, 0); // Monday 23:00
    final dose = _dose(scheduledLocal: monday23);
    // 04:00 Tuesday local == 22:30 UTC Monday.
    final now = DateTime.utc(2026, 9, 7, 22, 30);

    expect(resolve(dose, now).state, DoseState.missed);
  });

  test('DST spring forward: a dose in the skipped hour resolves without '
      'throwing, and its logical day is the calendar day before the '
      '04:00 boundary', () {
    // 2026-03-08 is the US spring-forward date: clocks jump from 02:00 to
    // 03:00, so 02:30 does not exist as a local time.
    final skippedHour = DateTime(2026, 3, 8, 2, 30);
    final dose = _dose(
      scheduledLocal: skippedHour,
      ianaTimezone: 'America/New_York',
    );

    expect(
      () => resolve(dose, dose.scheduledAt),
      returnsNormally,
      reason: 'a non-existent local time must not crash resolution',
    );

    // Whichever side of the transition package:timezone resolves 02:30 to,
    // the result is still before 04:00 local, so it belongs to the
    // previous calendar day.
    expect(
      logicalDay(dose.scheduledAt, dose.ianaTimezone),
      const LogicalDay(2026, 3, 7),
    );
  });

  test('the 04:00 boundary is still 04:00 on a spring-forward day', () {
    // The regression this file did not catch first time round. `logicalDay`
    // originally subtracted an absolute `Duration(hours: 4)`, which reads as
    // equivalent to comparing the hour and is not: between local midnight and
    // 04:00 on a spring-forward day only THREE absolute hours elapse, so the
    // boundary slid to 05:00 local on exactly the two days a year when a wrong
    // answer is hardest to notice.
    //
    // The cost was not cosmetic -- a dose at 04:30 that morning was filed under
    // the previous day, so Home and History showed it under the wrong heading
    // and Overdue vs Missed was decided against the wrong day.
    //
    // The original DST test asserted only `returnsNormally` and a dose at
    // 02:30, which is below the boundary either way. Not throwing was never the
    // property at risk.
    const String zone = 'America/New_York';
    final tz.Location location = tz.getLocation(zone);

    // 2026-03-08 is the US spring-forward date; 2026-03-15 is an ordinary
    // Sunday one week later. The boundary must fall in the same place on both.
    for (final ({int day, LogicalDay before, LogicalDay onOrAfter}) c
        in <({int day, LogicalDay before, LogicalDay onOrAfter})>[
          (
            day: 8,
            before: const LogicalDay(2026, 3, 7),
            onOrAfter: const LogicalDay(2026, 3, 8),
          ),
          (
            day: 15,
            before: const LogicalDay(2026, 3, 14),
            onOrAfter: const LogicalDay(2026, 3, 15),
          ),
        ]) {
      expect(
        logicalDay(tz.TZDateTime(location, 2026, 3, c.day, 3, 59), zone),
        c.before,
        reason: '03:59 on 2026-03-${c.day} belongs to the previous day',
      );
      expect(
        logicalDay(tz.TZDateTime(location, 2026, 3, c.day, 4), zone),
        c.onOrAfter,
        reason: '04:00 on 2026-03-${c.day} starts the new logical day',
      );
      expect(
        logicalDay(tz.TZDateTime(location, 2026, 3, c.day, 4, 30), zone),
        c.onOrAfter,
        reason: '04:30 on 2026-03-${c.day} -- the dose the old bug misfiled',
      );
    }
  });

  test('DST fall back: a dose in the repeated hour resolves without throwing, '
      'to one consistent answer', () {
    // 2026-11-01 is the US fall-back date: 01:00-02:00 occurs twice.
    final repeatedHour = DateTime(2026, 11, 1, 1, 30);
    final dose = _dose(
      scheduledLocal: repeatedHour,
      ianaTimezone: 'America/New_York',
    );

    expect(() => resolve(dose, dose.scheduledAt), returnsNormally);

    final LogicalDay first = logicalDay(dose.scheduledAt, dose.ianaTimezone);
    final LogicalDay second = logicalDay(dose.scheduledAt, dose.ianaTimezone);
    expect(first, second, reason: 'one consistent answer, not two');
    expect(first, const LogicalDay(2026, 10, 31));
  });

  test('zone travel: the logical day comes from the dose\'s own zone, not '
      'whatever zone "now" is being read in', () {
    final monday23 = DateTime(2026, 9, 7, 23, 0); // Monday 23:00 Colombo
    final dose = _dose(scheduledLocal: monday23, ianaTimezone: 'Asia/Colombo');
    final now = DateTime.utc(2026, 9, 7, 22, 45);

    // The same instant names a different calendar day in the two zones --
    // otherwise this test could not prove which one resolve() used.
    expect(
      logicalDay(now, 'Asia/Colombo'),
      isNot(logicalDay(now, 'Europe/Berlin')),
    );

    // Correct per Asia/Colombo, the dose's own zone: the logical day has
    // already advanced past Monday, so this is Missed rather than Overdue.
    expect(resolve(dose, now).state, DoseState.missed);
  });

  test('14-day edge, inside: a Missed dose 13 days old is isResolvable', () {
    final dose = _dose(scheduledLocal: scheduledLocal);
    final now = dose.scheduledAt.add(const Duration(days: 13));

    expect(resolve(dose, now).state, DoseState.missed);
    expect(dose.isResolvable(now), isTrue);
  });

  test(
    '14-day edge, outside: a Missed dose 15 days old is not isResolvable',
    () {
      final dose = _dose(scheduledLocal: scheduledLocal);
      final now = dose.scheduledAt.add(const Duration(days: 15));

      expect(resolve(dose, now).state, DoseState.missed);
      expect(dose.isResolvable(now), isFalse);
    },
  );

  test('AD-16: a Dose\'s own escalationWindowMinutes decides loggedLate, not a '
      'default', () {
    final DateTime takenAt = scheduledAt.add(const Duration(minutes: 45));

    final narrowWindowDose = _dose(
      scheduledLocal: scheduledLocal,
      escalationWindowMinutes: 30,
      takenAt: takenAt,
    );
    final wideWindowDose = _dose(
      scheduledLocal: scheduledLocal,
      escalationWindowMinutes: 90,
      takenAt: takenAt,
    );
    final now = scheduledAt.add(const Duration(hours: 2));

    // The same takenAt is late against the 30-minute window and on time
    // against the 90-minute one -- each Dose's own frozen value decides,
    // never a shared default.
    expect(resolve(narrowWindowDose, now).loggedLate, isTrue);
    expect(resolve(wideWindowDose, now).loggedLate, isFalse);
  });
}
