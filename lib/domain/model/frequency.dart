// The four repeat patterns a Schedule can have (FR-4).
//
// AD-1: pure Dart. No import at all — an enum of four names needs none.
//
// The vocabulary is PRD §3's, verbatim: `Frequency`, not `Repeat`, not
// `Recurrence`. The spine's Consistency Conventions make the glossary binding
// in type names, table names and UI copy alike.

/// How often a `Schedule` recurs.
///
/// FR-4 has exactly four patterns and no fifth. Two of them carry a companion
/// field on the Schedule, and the pairing is the domain's rule rather than the
/// schema's — the columns are both nullable because three of the four values
/// leave each one empty:
///
///   * [specificDays] is the only value for which `daysOfWeek` is meaningful,
///     and it requires at least one day.
///   * [everyNDays] is the only value for which `intervalDays` is meaningful,
///     and it requires at least 2 — an interval of 1 is [everyDay] written the
///     long way, and two spellings of the same pattern would have to be kept
///     in step by every reader.
enum Frequency {
  /// Every calendar day, in the Schedule's own zone.
  everyDay,

  /// Monday to Friday.
  ///
  /// A fixed day set rather than a locale question: FR-4 names weekdays, and
  /// a "weekend" that moved with the locale would silently change an existing
  /// Schedule's meaning when the phone's region changed.
  weekdays,

  /// The days named in `Schedule.daysOfWeek`.
  specificDays,

  /// Every `Schedule.intervalDays` days, counted from the medicine's start
  /// date.
  everyNDays,
}
