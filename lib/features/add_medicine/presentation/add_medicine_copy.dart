// Every word the add-medicine flow says, in one place.
//
// Gathered here for the two reasons `onboarding_copy.dart` gives. Review:
// EXPERIENCE.md's Voice and Tone rules are properties of the *set* of strings,
// and a rule about a set needs the set to exist -- `add_medicine_copy_test.dart`
// reads [AddMedicineCopy.all] and checks all of it. Provenance: nothing here is
// invented unless it says so, and each string names where it came from.
//
// THE SOURCE. Everything below is transcribed from the delivered design,
//
//   _bmad-output/planning-artifacts/ux-designs/ux-medi_tracker-2026-08-24/
//     imports/MediTracker.dc.html
//
// specifically its `<sc-if value="{{ isAdd }}">` block -- the `st1` / `st2` /
// `st3` steps -- and the `addCta`, `addStepLabel`, `reviewDose` and
// `reminderLabel` expressions in the trailing script, which are where the
// composed strings live. Open THAT file, not `MediTracker Screens.dc.html`,
// which is a 4.5 KB loader wrapper containing no design; see
// `imports/README.md`. Story 1.3 invented three onboarding titles that already
// existed one directory away, and this file exists partly so that does not
// happen twice.
//
// FIVE STRINGS ARE NOT TRANSCRIBED, and each says why at its own declaration:
//
//   * [conditionPlaceholder] -- the design has no Condition input at all. The
//     wording was decided by the product owner (2026-09-07); see its doc.
//   * [timezoneUnavailable] -- the failure only became possible when AD-9 was
//     amended on 2026-09-08, after the design was delivered.
//   * [actionBack] -- the design draws the control (an arrow) but gives it no
//     word, and a screen reader needs one.
//   * the four stepper labels and the seven day names -- the design's controls
//     are icon glyphs and single letters, which announce as nothing and as
//     ambiguity. `M` and `T` cannot tell Monday from Tuesday out loud.
//
// Everything else is the mock's own wording, including its middle dots and its
// pluralisation.

import '../domain/add_medicine_draft.dart';

/// The copy of the three add-medicine steps.
abstract final class AddMedicineCopy {
  // --- The header -----------------------------------------------------------

  /// The screen's title, above the step bar. `title` at weight 700.
  static const String screenTitle = 'Add medicine';

  /// Leaves the flow without creating anything. The matrix's "Cancel at any
  /// step: closes flow. No Medicine, no Schedule."
  static const String actionCancel = 'Cancel';

  /// Retreats one step, and on step 1 leaves for Home.
  ///
  /// NOT transcribed: the mock draws an `arrow_back` glyph with no word, so a
  /// screen reader would announce an unlabelled box. `onboarding_copy.dart`
  /// composed the same word for the same reason, and using a second word for
  /// the same control in the same product would be worse than composing one.
  static const String actionBack = 'Back';

  /// The ALL-CAPS position line above the title -- `STEP 2 OF 3`.
  ///
  /// The mock's `STEP {{ addStepLabel }} OF 3`, where `addStepLabel` is
  /// `String(Math.min(s.addStep, 3))`. The total is a parameter rather than the
  /// literal 3 the mock writes, so the sentence cannot disagree with
  /// `AddMedicineStep.count` about how many steps there are.
  static String stepLabel(int step, int total) => 'STEP $step OF $total';

  /// The step bar's screen-reader label -- `Step 2 of 3`.
  ///
  /// Sentence case, not [stepLabel]'s capitals: ALL-CAPS is a property of how
  /// the position line is *set*, and a screen reader announcing "S T E P" is
  /// the failure that distinction exists to avoid. The same sentence onboarding
  /// uses, deliberately -- one product, one way of saying where you are.
  static String stepBarLabel(int step, int total) => 'Step $step of $total';

  // --- Step 1: what you are taking -----------------------------------------

  /// Step 1's question. `heading-md`, which DESIGN.md reserves for exactly
  /// this: "The stepped-flow questions".
  static const String stepOneHeading = 'What are you taking, and how much?';

  /// The name input's placeholder.
  static const String namePlaceholder = 'Medicine name';

  /// The Condition input's placeholder.
  ///
  /// THE ONE COMPOSED VISIBLE STRING IN THE FLOW, decided by the product owner
  /// on 2026-09-07 rather than transcribed, because the delivered design has no
  /// Condition input to transcribe one from. `Medicine.condition` exists,
  /// `addMedicine` takes it, and the design renders it as `Condition · Form` on
  /// Home and on Medicine detail -- only the capture was missing.
  ///
  /// It reuses FR-1's own wording for the field and matches the flow's plain
  /// question voice; the step heading is already "What are you taking, and how
  /// much?". Two alternatives were rejected, for reasons worth keeping:
  /// `Condition (optional)` puts our domain word in front of the user and would
  /// be the only placeholder in the flow that labels its own optionality, and
  /// `e.g. Type 2 Diabetes` reads as a format requirement and hints the field
  /// is looked up -- which PRD ss6 forbids, since Condition is displayed but
  /// never interpreted, validated or matched against any database.
  static const String conditionPlaceholder = "What it's for";

  /// The ALL-CAPS label above the form chips.
  static const String formLabel = 'FORM';

  /// The ALL-CAPS label above the dose stepper.
  static const String doseLabel = 'DOSE PER TIME';

  /// The free-text unit input's placeholder, shown when `Other` is chosen.
  ///
  /// The mock offers `Other` as a chip but draws no input behind it. FR-1
  /// requires one ("selecting 'other' permits a free-text unit") and
  /// EXPERIENCE.md's option-row spec is where the inline reveal comes from, so
  /// the control is the spine's and the word is FR-1's own noun.
  static const String customUnitPlaceholder = 'Unit';

  /// The label a screen reader hears on the dose stepper's minus.
  ///
  /// The mock's control is a `remove` glyph, which announces as nothing.
  static const String actionDecreaseDose = 'Decrease dose';

  /// The label a screen reader hears on the dose stepper's plus.
  static const String actionIncreaseDose = 'Increase dose';

  // --- Step 2: when you take it --------------------------------------------

  /// Step 2's question.
  static const String stepTwoHeading = 'When should you take it?';

  /// The ALL-CAPS label above the time control.
  static const String timeLabel = 'TIME';

  /// The ALL-CAPS label above the repeat options.
  static const String repeatLabel = 'REPEAT';

  /// The label a screen reader hears on the time control's minus.
  static const String actionEarlierTime = 'Earlier time';

  /// The label a screen reader hears on the time control's plus.
  static const String actionLaterTime = 'Later time';

  /// The label a screen reader hears on the interval stepper's minus.
  ///
  /// Says what the number means rather than repeating "decrease": two steppers
  /// on one screen both announcing "Decrease" would be two controls with one
  /// label, which is one control to a reader.
  static const String actionShorterInterval = 'Fewer days between doses';

  /// The label a screen reader hears on the interval stepper's plus.
  static const String actionLongerInterval = 'More days between doses';

  /// The single letters of the inline day row, indexed by `DateTime.monday`..
  /// `DateTime.sunday`.
  ///
  /// DESIGN.md's Day selector component: "seven `rounded/pill` toggles in a
  /// row, `M T W T F S S`". Index 0 is unused so that `dayLetters[
  /// DateTime.monday]` is Monday; a zero-based list would make every lookup an
  /// off-by-one waiting to happen, which is the reasoning
  /// `DuplicateScheduleFailure.dayNames` already uses.
  static const List<String> dayLetters = <String>[
    '',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  /// The day names a screen reader hears, indexed the same way.
  ///
  /// NOT transcribed, and unavoidable: the design's toggles carry single
  /// letters, and `M T W T F S S` announces two Ts and two Ss with nothing to
  /// tell them apart. The names are the calendar's, not a product decision.
  static const List<String> dayNames = <String>[
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // --- Step 3: reminders and the review ------------------------------------

  /// Step 3's heading.
  static const String stepThreeHeading = "Reminders, then you're set";

  /// The reminders row's title.
  static const String reminderEnabled = 'Reminder enabled';

  /// How long after the scheduled time the follow-up fires.
  ///
  /// The mock's `followUp: 15`. These three numbers are the delivered design's
  /// own defaults and are named here rather than typed into the sentence, so
  /// that the row shows the REAL timings -- the story's acceptance criterion is
  /// that step 3 shows "+15 / +30 / +60" and not a description of escalation.
  ///
  /// AD-16 makes the escalation window a `domain/policy/` constant with a
  /// resolution order, and Story 1.6 owns that policy. When it lands, this
  /// sentence reads from there and these three constants go. They are not put
  /// in `domain/policy/` now because a constant with no policy behind it is a
  /// number in a different directory.
  static const int followUpMinutes = 15;

  /// The last notification for a dose, in minutes after the scheduled time.
  static const int finalReminderMinutes = 30;

  /// When a dose is marked overdue and follow-ups stop, in minutes after the
  /// scheduled time.
  static const int overdueMinutes = 60;

  /// The reminders row's second line: the escalation, as its three real
  /// offsets.
  ///
  /// The mock's `Follow-up +15, final +30, overdue +60`, composed from the
  /// three constants above so the sentence and the timings cannot drift apart.
  static String get escalationTimings =>
      'Follow-up +$followUpMinutes, final +$finalReminderMinutes, '
      'overdue +$overdueMinutes';

  /// The review row labels, in the order the mock lists them.
  static const String reviewTimeLabel = 'Time';

  /// The `Repeat` review row's label.
  static const String reviewRepeatLabel = 'Repeat';

  /// The `Reminders` review row's label.
  static const String reviewRemindersLabel = 'Reminders';

  /// The `Starts` review row's label.
  static const String reviewStartsLabel = 'Starts';

  /// The `Starts` row's value.
  ///
  /// A word, not a formatted date, and the mock's own word. FR-1 gives a new
  /// Medicine "a start date of today", and the date itself comes from the
  /// injected clock at the moment of saving (AD-5) -- so rendering a formatted
  /// date here would be rendering a value this screen has not read.
  static const String reviewStartsValue = 'Today';

  /// The `Reminders` row's value when reminders are on.
  ///
  /// The mock's `reminderLabel`: `s.reminder ? 'On · +15 / +30 min' : 'Off'`.
  /// Composed from the same constants as [escalationTimings]; the mock quotes
  /// two of the three here and all three above, and that difference is the
  /// mock's, not a simplification.
  static String get reminderSummaryOn =>
      'On · +$followUpMinutes / +$finalReminderMinutes min';

  /// The `Reminders` row's value when reminders are off.
  static const String reminderSummaryOff = 'Off';

  /// The note under the review card.
  static const String stepThreeFootnote =
      'You can change any of this later from Schedule.';

  // --- Actions --------------------------------------------------------------

  /// The primary action on steps 1 and 2.
  ///
  /// The mock's `addCta`: `s.addStep >= 3 ? 'Save medicine' : 'Continue'`.
  static const String actionContinue = 'Continue';

  /// The primary action on step 3.
  static const String actionSave = 'Save medicine';

  // --- Composed values -----------------------------------------------------

  /// A wall-clock hour as the design writes it -- `08:00 PM`.
  ///
  /// The mock's `shiftTime` formatting: a zero-padded 12-hour hour, `:00`, and
  /// the meridiem. Zero-padded because the mock pads (`String(h12).padStart(2,
  /// '0')`) and because a column of times that changes width as it crosses ten
  /// o'clock reads as a layout bug.
  static String timeOfDayLabel(int hourOfDay) {
    final int hour12 = hourOfDay % 12 == 0 ? 12 : hourOfDay % 12;
    final String meridiem = hourOfDay >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:00 $meridiem';
  }

  /// The chip label for a dosage unit.
  ///
  /// The design's five chips are `Tablet`, `Capsule`, `ml`, `Drop`, `Other` --
  /// the capitalisation of FR-1's own lower-case vocabulary, except `ml`, which
  /// is a unit symbol and is never capitalised. A map rather than a derivation,
  /// because "capitalise the first letter unless it is ml" is a rule with one
  /// exception, which is a table written as code.
  static const Map<String, String> unitLabels = <String, String>{
    'tablet': 'Tablet',
    'capsule': 'Capsule',
    'ml': 'ml',
    'drop': 'Drop',
    'other': 'Other',
  };

  /// The option-row label for a repeat pattern.
  ///
  /// Three are the mock's own strings. The fourth is the mock's `Every 2 days`
  /// with its 2 replaced by the interval the stepper holds: DESIGN.md's
  /// Interval stepper component is "revealed inline beneath 'Every N days'", so
  /// the option's own label has to follow N or the row and the control beneath
  /// it would disagree. At the default interval of 2 it reads exactly as the
  /// mock draws it.
  static String repeatOptionLabel(
    AddMedicineRepeat repeat, {
    required int intervalDays,
  }) => switch (repeat) {
    AddMedicineRepeat.everyDay => 'Every day',
    AddMedicineRepeat.weekdays => 'Weekdays',
    AddMedicineRepeat.specificDays => 'Specific days',
    AddMedicineRepeat.everyNDays => 'Every $intervalDays days',
  };

  /// The dose as the review card states it -- `2 tablets`.
  ///
  /// The mock's `reviewDose`: `s.amount + ' ' + s.unit.toLowerCase() +
  /// (s.amount > 1 ? 's' : '')`. Lower-cased and naively pluralised, both the
  /// mock's own choices: the stored unit is FR-1's lower-case vocabulary
  /// anyway, and a free-text unit the user typed is shown as they typed it,
  /// lower-cased, rather than being second-guessed.
  static String doseSummary(int amount, String unit) =>
      '$amount ${unit.toLowerCase()}${amount > 1 ? 's' : ''}';

  /// The confirmation shown on Home after a save.
  ///
  /// The mock's `this.flash(s.newName + ' added · first reminder ' +
  /// s.newTime)`. It states exactly what was recorded -- the medicine, and when
  /// the first reminder is -- which is EXPERIENCE.md's rule for a confirmation.
  static String savedConfirmation(String name, String firstReminder) =>
      '$name added · first reminder $firstReminder';

  /// Shown when the device has not told us its IANA zone.
  ///
  /// NOT transcribed, and it could not be: the failure did not exist when the
  /// design was delivered. AD-9's amendment of 2026-09-08 permits a Schedule's
  /// zone to be READ from the device at creation, and `UnresolvedZoneClock`
  /// throws rather than answering when the platform could not name one -- which
  /// is the fix, not the bug: AD-6 makes the stored zone the truth Stories
  /// 1.6/1.7 resolve Doses against, so a guessed zone would be permanently
  /// wrong and read back as true.
  ///
  /// It states the fact and what was not done, in the product's voice, and it
  /// does not ask the user to fix something they have no control over from
  /// here.
  static const String timezoneUnavailable =
      'This phone has not reported its time zone, so a reminder time cannot '
      'be saved yet. Nothing has been saved.';

  /// The ALL-CAPS section labels of this flow.
  ///
  /// DESIGN.md: "ALL-CAPS 12.5px/600 labels group form sections -- the only
  /// place capitals are used." Listed so [all]'s sentence-case rule can exempt
  /// exactly these four and no others, rather than exempting anything that
  /// happens to be shouted.
  static const List<String> sectionLabels = <String>[
    formLabel,
    doseLabel,
    timeLabel,
    repeatLabel,
  ];

  /// Every string this feature says, for the Voice and Tone test.
  ///
  /// A getter rather than a constant so the composed strings can be rendered at
  /// real values: a sentence built at runtime is still a sentence the user
  /// reads, and leaving them out would exempt the only generated strings here
  /// from the rules that govern all the others.
  static List<String> get all => <String>[
    screenTitle,
    actionCancel,
    actionBack,
    stepOneHeading,
    namePlaceholder,
    conditionPlaceholder,
    customUnitPlaceholder,
    actionDecreaseDose,
    actionIncreaseDose,
    stepTwoHeading,
    actionEarlierTime,
    actionLaterTime,
    actionShorterInterval,
    actionLongerInterval,
    stepThreeHeading,
    reminderEnabled,
    escalationTimings,
    reviewTimeLabel,
    reviewRepeatLabel,
    reviewRemindersLabel,
    reviewStartsLabel,
    reviewStartsValue,
    reminderSummaryOn,
    reminderSummaryOff,
    stepThreeFootnote,
    actionContinue,
    actionSave,
    timezoneUnavailable,
    ...sectionLabels,
    ...unitLabels.values,
    for (final String name in dayNames.skip(1)) name,
    for (final AddMedicineStep step in AddMedicineStep.values) ...<String>[
      stepLabel(step.step, AddMedicineStep.count),
      stepBarLabel(step.step, AddMedicineStep.count),
    ],
    for (final AddMedicineRepeat repeat in AddMedicineRepeat.values)
      repeatOptionLabel(
        repeat,
        intervalDays: const AddMedicineDraft().intervalDays,
      ),
    for (final String form in addMedicineForms) form,
    timeOfDayLabel(const AddMedicineDraft().hourOfDay),
    doseSummary(1, 'tablet'),
    doseSummary(2, 'tablet'),
    savedConfirmation('Atorvastatin', timeOfDayLabel(20)),
  ];
}
