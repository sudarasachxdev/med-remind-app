// A clock that does not move.
//
// "Starts today" is an assertion about a known calendar date, not about
// whatever day the suite happens to run on. A test that read the real clock
// would pass every day and fail once, at a midnight or a DST boundary, in CI.
//
// The zone is a real IANA identifier because `Schedule.isValidIanaTimezone`
// rejects anything else, and because AD-6 makes the stored zone the value Dose
// resolution later reads back as truth. `Asia/Colombo` is deliberately NOT
// `Etc/UTC`: a test on UTC cannot tell a correct zone from a placeholder one,
// which is the exact confusion AD-9's amendment exists to remove.

import 'package:med_remind_app/domain/port/clock.dart';

/// A [Clock] frozen at [instant], in [ianaTimezone].
final class FixedClock implements Clock {
  /// Creates a clock frozen at [instant].
  /// `DateTime` has no const constructor, so [defaultInstant] cannot be a
  /// parameter default and is resolved in the initialiser instead.
  FixedClock({DateTime? instant, this.ianaTimezone = defaultZone})
    : instant = instant ?? defaultInstant;

  /// The instant [now] returns unless a test names another.
  ///
  /// A Wednesday, so `weekdays` and `specificDays` behave differently and a
  /// test cannot pass by conflating them. Mid-morning, so a `logicalDay`
  /// boundary at 04:00 is nowhere near it.
  static final DateTime defaultInstant = DateTime(2026, 9, 9, 10, 30);

  /// The zone [ianaTimezone] returns unless a test names another.
  static const String defaultZone = 'Asia/Colombo';

  /// The frozen instant.
  final DateTime instant;

  @override
  final String ianaTimezone;

  @override
  DateTime now() => instant;
}
