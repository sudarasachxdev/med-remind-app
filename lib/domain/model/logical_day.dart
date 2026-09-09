// Which calendar day a moment belongs to, once the 04:00 boundary has been
// applied (AD-2, AD-6).
//
// AD-1: pure Dart, no imports.
//
// See `domain/policy/logical_day_policy.dart` for how one of these is
// produced. This file only carries the answer.

/// The calendar day a moment falls on, in one zone, after the product's 04:00
/// boundary has been applied.
///
/// Deliberately not a `DateTime`. A `DateTime` invites `==` against another
/// `DateTime` that happens to carry a time of day -- the raw date comparison
/// the spine's Dates & times convention forbids, and exactly the mistake a
/// bare `scheduledAt.day == now.day` would make across the 04:00 boundary or a
/// month end. This type has no time component to compare by mistake: it means
/// "which day", and nothing else.
final class LogicalDay {
  /// Creates the value directly. Prefer `logicalDay()`, which applies the
  /// boundary; this constructor exists for that function and for tests that
  /// want to name an expected day without going through the boundary
  /// arithmetic themselves.
  const LogicalDay(this.year, this.month, this.day);

  /// The calendar year, e.g. `2026`.
  final int year;

  /// The calendar month, `1`-`12`.
  final int month;

  /// The day of the month, `1`-`31`.
  final int day;

  @override
  bool operator ==(Object other) =>
      other is LogicalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      'LogicalDay(${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')})';
}
