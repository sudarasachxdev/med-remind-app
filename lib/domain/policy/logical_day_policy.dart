// The 04:00 boundary, and the one function that applies it (AD-2, AD-6).
//
// AD-1, as amended 2026-09-09: the domain's allowlist widens to admit
// `package:timezone/` so that this file can do real zone arithmetic --
// `timezone.dart` itself imports only `dart:collection` and
// `dart:typed_data`, both pure. `package:timezone/standalone.dart` and
// `package:timezone/data/*.dart` are NOT imported here: the former pulls in
// `dart:io`, and initialising the zone database is the composition root's job
// and the test suite's `setUp`, never a domain file's. A domain file that
// initialised its own zone data on first use would make "is the database
// loaded" state that depends on which function ran first.
//
// AD-2's rule: "logicalDay() is always evaluated in the Dose's own stored
// ianaTimezone, never the device's current zone." A dose keeps the day it
// belongs to even if the user flies somewhere else -- Home and History can
// never disagree about which day heading a Dose sits under.

import 'package:timezone/timezone.dart' as tz;

import '../model/logical_day.dart';

/// The hour, local time, at which one calendar day's doses end and the next's
/// begin.
///
/// Not midnight: a dose scheduled at 23:00 that is still unactioned at 01:00
/// the next morning is still "tonight's" dose to the person taking it, not a
/// dose that quietly became overdue for a day that has not started yet from
/// their point of view. Four in the morning is late enough that nobody is
/// still awake from the day before, and early enough that nobody has started
/// the next one.
const int logicalDayBoundaryHour = 4;

/// Which calendar day [instant] belongs to, once the [logicalDayBoundaryHour]
/// boundary is applied, read in [ianaTimezone] -- never the device's current
/// zone (AD-2).
///
/// [instant] may be any [DateTime]; only the absolute moment it represents is
/// used. It is re-read as wall-clock time in [ianaTimezone], and the boundary
/// is then applied to the WALL-CLOCK HOUR -- never by subtracting a duration
/// from the instant.
///
/// That distinction is the whole correctness of this function, and it was wrong
/// until 2026-09-09. The first version subtracted `Duration(hours: 4)` from the
/// zoned time and took the resulting date, which reads as equivalent and is
/// not: between local midnight and 04:00 on a spring-forward day only THREE
/// absolute hours elapse, so the boundary silently slid to 05:00 local on
/// exactly the two days a year when a wrong answer is hardest to notice. A dose
/// at 04:30 that morning was filed under the previous day -- the wrong heading
/// on Home and in History, and `Overdue` vs `Missed` decided against the wrong
/// day. Comparing the hour, and rolling the DATE back in UTC where no DST
/// exists, cannot bend that way.
///
/// A dose landing in a skipped hour (spring forward) or a repeated one (fall
/// back) still resolves to one answer, because [tz.TZDateTime] never rejects a
/// wall-clock time as non-existent -- it resolves it against the zone's real
/// transition data instead.
///
/// Throws [tz.LocationNotFoundException] when [ianaTimezone] is not a zone the
/// loaded database knows. That can only happen if the database was never
/// initialised or is older than the zone a caller stored -- a composition-root
/// or test-setup problem, not something this function should paper over.
LogicalDay logicalDay(DateTime instant, String ianaTimezone) {
  final tz.Location location = tz.getLocation(ianaTimezone);
  final tz.TZDateTime zoned = tz.TZDateTime.from(instant, location);

  if (zoned.hour >= logicalDayBoundaryHour) {
    return LogicalDay(zoned.year, zoned.month, zoned.day);
  }

  // Before the boundary, so this belongs to the previous calendar day. Rolled
  // back in UTC on the date alone: UTC has no transitions, so "the day before"
  // is exactly 24 hours there and the arithmetic cannot be bent by the zone
  // whose date we are rolling.
  final DateTime previous = DateTime.utc(
    zoned.year,
    zoned.month,
    zoned.day,
  ).subtract(const Duration(days: 1));
  return LogicalDay(previous.year, previous.month, previous.day);
}
