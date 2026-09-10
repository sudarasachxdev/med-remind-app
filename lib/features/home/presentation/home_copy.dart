// Every word (and every date/time format) Home says, in one place.
//
// Gathered here for the two reasons `add_medicine_copy.dart` gives: a rule
// about the *set* of strings (EXPERIENCE.md's Voice and Tone) needs the set to
// exist, and nothing here is invented without saying so.
//
// THE GREETING, THE DATE PILL AND THE WEEK STRIP are the one place this file
// diverges from the delivered mock rather than transcribing it, and each
// divergence is a resolution already recorded in the planning documents, not
// an editorial choice made here:
//
//   * [greetingFor] -- EXPERIENCE.md's `[RESOLVED 2026-09-10]` entry drops the
//     mock's "Good morning 👋 / Emily": no FR names a personalised greeting or
//     a stored display name, and the emoji is banned the same way the streak
//     badge's was. Time-of-day only.
//   * The bell, the red dot and the avatar the same entry describes are not
//     transcribed at all -- there is nothing here for them to be.
//   * [privacyFootnote] is transcribed from the mock's own home block
//     ("Everything is stored on this phone.<br>No account, no cloud."), which
//     is also `EXPERIENCE.md`'s Voice and Tone table verbatim. It is a
//     DIFFERENT sentence from `OnboardingCopy.panel1BodyPrivacy` ("Everything
//     stays on this phone. No account, works offline.") -- the two screens'
//     mock blocks simply say it two different ways, and grepping the tree
//     before adding this constant found no existing one to reuse.
//
// EVERYTHING ELSE is either the mock's own wording (the overdue banner's
// shape, "next dose", "nothing scheduled") corrected only where DESIGN.md
// documents the mock as defective (the overdue-card colour, handled in
// `dose_card.dart`, not here), or a small formatter with no prose voice of its
// own -- a wall-clock time, a calendar date, a dose amount -- generalising
// `add_medicine_copy.dart`'s own `timeOfDayLabel`/`doseSummary` rather than
// duplicating their shape by accident.

/// The copy and small text formatters of Home's daily plan.
abstract final class HomeCopy {
  // --- Greeting and date ------------------------------------------------------

  /// Time-of-day only -- see the file comment's `[RESOLVED 2026-09-10]` note.
  /// No name, no emoji: `heading-lg`, the same role DESIGN.md's type scale
  /// reserves for "the Home greeting name" now that there is no name to show.
  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const List<String> _weekdayNames = <String>[
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _monthNames = <String>[
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// `Monday, 9 September` -- the mock's date-pill format: full weekday, day
  /// with no leading zero, full month, no year.
  static String formattedDate(DateTime date) =>
      '${_weekdayNames[date.weekday]}, ${date.day} ${_monthNames[date.month]}';

  /// The week strip's single-letter day labels, `M T W T F S S`, indexed like
  /// `AddMedicineCopy.dayLetters` (Monday = 1 .. Sunday = 7). Duplicated
  /// rather than imported from that feature's copy file: this is seven
  /// characters of calendar vocabulary, not a reason to couple two features.
  static const List<String> weekdayLetters = <String>[
    '',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  // --- Time ---------------------------------------------------------------------

  /// `8:00 AM` / `8:15 PM` -- a wall-clock time as the design writes it.
  ///
  /// Generalises `AddMedicineCopy.timeOfDayLabel` to a real minute value: that
  /// formatter's stepper only ever produces a whole hour, but a Dose's own
  /// scheduled time carries no such guarantee at this layer.
  static String timeLabel(DateTime time) {
    final int hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String meridiem = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $meridiem';
  }

  // --- Dose amount and the meta line --------------------------------------------

  /// A dose amount without a trailing `.0` on a whole number -- `1`, `2.5`.
  static String doseAmountLabel(double amount) =>
      amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();

  /// `2 tablets` -- generalises `AddMedicineCopy.doseSummary` (which takes an
  /// `int`) to a Dose's own `double` amount. Naively pluralised, the mock's own
  /// choice, carried over unchanged.
  static String doseSummary(double amount, String unit) =>
      '${doseAmountLabel(amount)} ${unit.toLowerCase()}${amount > 1 ? 's' : ''}';

  /// The dose card's meta line: `Condition · dose` when a Condition is
  /// present, the dose alone when it is not (this spec's own I/O matrix).
  static String metaLine({
    required String? condition,
    required double amount,
    required String unit,
  }) {
    final String dose = doseSummary(amount, unit);
    return condition == null ? dose : '$condition · $dose';
  }

  // --- Status chips ---------------------------------------------------------------

  /// The plain (Scheduled) card's chip word.
  static const String stateScheduled = 'Scheduled';

  /// The due card's chip word. Not a repeated time: the time-grouped list's
  /// own divider above the card already states it (see `home_screen.dart`).
  static const String stateDue = 'Due now';

  /// The overdue card's chip -- the mock's own copy, with its time bound to
  /// the Dose's actual scheduled time rather than left as static text.
  static String stateOverdue(DateTime scheduledAt) =>
      'Overdue · was due ${timeLabel(scheduledAt)}';

  // --- Progress card ----------------------------------------------------------------

  /// The progress card's title -- the mock's own words, UX-DR6's "title" that
  /// sits beside the `n of m doses taken` line.
  static const String progressTitle = "Today's progress";

  /// `1 of 3 doses taken` -- UX-DR6's one permitted aggregate metric.
  static String progressLabel(int taken, int scheduled) =>
      '$taken of $scheduled doses taken';

  /// The ring's knockout-centre percentage. `0%` when nothing is scheduled
  /// today, rather than dividing by zero.
  static String percentLabel(int taken, int scheduled) =>
      scheduled == 0 ? '0%' : '${((taken / scheduled) * 100).round()}%';

  // --- Next-dose chip -----------------------------------------------------------------

  /// The chip's second line when a next dose exists (UX-DR7).
  static const String nextDoseLabel = 'next dose';

  /// The chip's whole text when none exists anywhere in the visible horizon
  /// (this spec's own I/O matrix row).
  static const String nothingScheduled = 'nothing scheduled';

  // --- Overdue banner -------------------------------------------------------------------

  /// The banner's title, pluralised by [count].
  ///
  /// NOT the mock's literal "waiting from this morning": an overdue dose can
  /// fall at any time of day, and asserting a time of day that may not be true
  /// is exactly what EXPERIENCE.md's "state the fact" rule forbids. "Earlier
  /// today" keeps the mock's meaning without inventing a fact this screen does
  /// not have.
  static String overdueBannerTitle(int count) => count == 1
      ? '1 dose is waiting from earlier today'
      : '$count doses are waiting from earlier today';

  /// The banner's second line, from `EXPERIENCE.md`'s State Patterns table,
  /// pluralised for more than one dose ("it" -> "them").
  static String overdueBannerBody(int count) => count == 1
      ? 'Reminders have stopped. You can still record it.'
      : 'Reminders have stopped. You can still record them.';

  // --- Footer -----------------------------------------------------------------------------

  /// `EXPERIENCE.md`'s Voice and Tone table, verbatim -- see the file comment
  /// for why this is not `OnboardingCopy.panel1BodyPrivacy`.
  static const String privacyFootnote =
      'Everything is stored on this phone. No account, no cloud.';

  // --- Empty state (UX-DR16, Story 1.9) ---------------------------------------------------

  /// The empty-state card's title, shown when no Medicine has been saved at
  /// all (never when one merely has no Dose today -- see `HomePlan.hasMedicines`).
  static const String emptyStateTitle = 'Nothing scheduled yet';

  /// The empty-state card's body, beneath [emptyStateTitle]. The mock's own
  /// words, already sentence case with no exclamation mark (UX-DR19).
  static const String emptyStateBody =
      'Add your first medicine and MediTracker will remind you when each '
      'dose is due.';

  // The action label itself is not a new string here: the empty state's
  // "Add medicine" button reuses `AddMedicineCopy.screenTitle` rather than a
  // second constant for the same three words -- see `home_screen.dart`.

  // --- Every string this screen says --------------------------------------

  /// Every string Home can show, for the Voice and Tone test.
  ///
  /// A getter, not a constant, for the same reason `AddMedicineCopy.all` and
  /// `OnboardingCopy.all` are: the composed strings (the greeting, the chips,
  /// the banner) have to be rendered at real values to be checked as the
  /// sentences a user actually reads, and leaving them out would exempt the
  /// only generated copy on this screen from the rules that govern everything
  /// else. UX-DR19 requires this screen to follow Voice and Tone as much as
  /// any other; nothing checked that until this list existed.
  static List<String> get all => <String>[
    greetingFor(DateTime(2026, 1, 1, 6)),
    greetingFor(DateTime(2026, 1, 1, 13)),
    greetingFor(DateTime(2026, 1, 1, 19)),
    stateScheduled,
    stateDue,
    stateOverdue(DateTime(2026, 1, 1, 8)),
    progressTitle,
    progressLabel(1, 3),
    nextDoseLabel,
    nothingScheduled,
    overdueBannerTitle(1),
    overdueBannerTitle(2),
    overdueBannerBody(1),
    overdueBannerBody(2),
    privacyFootnote,
    emptyStateTitle,
    emptyStateBody,
  ];
}
