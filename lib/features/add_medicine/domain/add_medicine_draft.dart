// Everything the add flow has been told so far, as one immutable value.
//
// WHY THIS IS ITS OWN FILE. Nine of the thirteen rows in the story's I/O matrix
// are questions about draft state rather than about widgets -- "is Continue
// enabled", "does decrement move", "did the inline row collapse". Held in a
// plain immutable object they are unit-testable without pumping a widget, and
// the enablement rule stops being duplicated across three step files. It is
// also the guard against the failure this project keeps hitting: a test that
// asserts on a *rendering* of a thing rather than on the thing.
//
// So "Continue enabled" is exactly one pure function -- [canAdvanceFrom] -- and
// every step screen reads it rather than re-deriving it from the widgets it
// happens to have built.
//
// WHAT IS NOT HERE. No `id` and no `glyphIndex`: AD-22 assigns both inside
// `MedicineRepository.addMedicine`, and a draft that could carry either could
// hand two Medicines the same identity or pick its own glyph. No `instructions`
// and no `endDate`: FR-1 and FR-2 set both later, from Medicine detail, and
// this flow deliberately never asks. No `startDate`: "today" comes from the
// injected `Clock` at the moment of saving (AD-5), never from a value a draft
// could carry stale across a midnight.
//
// No strings the user reads, either. The chip labels, the repeat labels and the
// review-row wording live in `presentation/add_medicine_copy.dart`, which is
// what `test/add_medicine_copy_test.dart` reads. This file holds the state and
// its mapping onto the domain; that one holds the words.

import '../../../domain/model/frequency.dart';
import '../../../domain/model/schedule.dart';
import '../../../domain/policy/medicine_vocabulary.dart';

/// The three steps of the add flow, in the order they are shown.
///
/// An enum rather than an `int`, for the reasons `OnboardingPanel` gives: the
/// current step cannot hold a fourth value, the step bar cannot disagree with
/// the content about how many steps there are, and the ordering lives in one
/// place instead of being re-derived with `+ 1` at each call site.
enum AddMedicineStep {
  /// Step 1 -- what you are taking, and how much.
  what,

  /// Step 2 -- when you take it.
  when,

  /// Step 3 -- reminders, the review, and Save.
  review;

  /// How many steps there are. The step bar's segment count.
  static int get count => values.length;

  /// This step's 1-based position, for `STEP 2 OF 3`.
  int get step => index + 1;

  /// Whether this is the first step. Back on it leaves the flow entirely --
  /// the matrix's "Back from step 1: exits to Home. Nothing created."
  bool get isFirst => index == 0;

  /// Whether this is the last step -- the one whose action saves.
  bool get isLast => index == values.length - 1;

  /// The step before this one, or `null` on the first.
  AddMedicineStep? get previous => isFirst ? null : values[index - 1];

  /// The step after this one, or `null` on the last.
  AddMedicineStep? get next => isLast ? null : values[index + 1];
}

/// FR-4's four repeat patterns as the add flow offers them, each mapped onto
/// the `Frequency` the domain stores.
///
/// The mapping is declared here, once, rather than switched over at the save
/// site: the four options and the four frequencies are the same four things,
/// and a `switch` at the boundary is where a fifth option would silently map
/// onto the wrong one.
enum AddMedicineRepeat {
  /// `Every day`.
  everyDay(Frequency.everyDay),

  /// `Weekdays` -- Monday to Friday, a fixed set rather than a locale
  /// question.
  weekdays(Frequency.weekdays),

  /// `Specific days` -- the days the user picks. Requires at least one.
  specificDays(Frequency.specificDays),

  /// `Every N days` -- the interval the user picks. Minimum 2.
  everyNDays(Frequency.everyNDays);

  const AddMedicineRepeat(this.frequency);

  /// The `Frequency` a Schedule created from this option carries.
  final Frequency frequency;

  /// Whether this option reveals the inline seven-day row.
  bool get revealsDays => this == specificDays;

  /// Whether this option reveals the inline interval stepper.
  bool get revealsInterval => this == everyNDays;
}

/// The forms FR-1 leaves as free text, in the order the design shows them.
///
/// `Medicine.form` is deliberately free text with no closed vocabulary --
/// `medicine_vocabulary.dart` says so and says why: FR-1 defines a fixed set
/// for the dosage *unit* only, so a closed set in the domain would be inventing
/// a requirement nobody wrote. These four are the delivered design's chips, not
/// a domain rule, which is why they are a presentation-layer list and why a
/// Medicine whose form is none of them is still perfectly valid.
const List<String> addMedicineForms = <String>[
  'Tablet',
  'Capsule',
  'Liquid',
  'Drop',
];

/// The state of the add-medicine flow's form, at one moment.
final class AddMedicineDraft {
  /// Creates a draft. Every field has the value the flow opens with.
  const AddMedicineDraft({
    this.name = '',
    this.condition = '',
    this.form,
    this.amount = minimumAmount,
    this.unit,
    this.customUnit = '',
    this.hourOfDay = defaultHourOfDay,
    this.repeat = AddMedicineRepeat.everyDay,
    this.daysOfWeek = const <int>{},
    this.intervalDays = Schedule.minimumIntervalDays,
    this.remindersEnabled = true,
  });

  /// The lowest dose amount the stepper admits, and the amount a new draft
  /// opens on.
  ///
  /// UX-DR: "the dose amount floors at 1". Decrementing at the floor is inert
  /// rather than an error -- there is nothing to explain, so nothing is said.
  static const int minimumAmount = 1;

  /// The hour a new draft's reminder time opens on -- 20, which the flow shows
  /// as `08:00 PM`.
  ///
  /// The delivered design's own default (`newTime: '08:00 PM'`). Stored as a
  /// 24-hour hour rather than as the string, because [timeOfDay] has to be
  /// `HH:mm` for `Schedule` and a second spelling of one time would have to be
  /// kept in step by every reader.
  static const int defaultHourOfDay = 20;

  /// How many hours there are in a day, for the time stepper's wrap.
  static const int hoursInDay = 24;

  /// What the user calls the medicine. Required by FR-1.
  final String name;

  /// What it is for, in the user's own words. Optional, and never interpreted
  /// (PRD ss6): displayed, never validated, looked up or matched.
  final String condition;

  /// The chosen form, or `null` while nothing is chosen.
  ///
  /// `null` rather than a preselected `Tablet`. The mock opens with
  /// `form: 'Tablet'` beside `newName: 'Atorvastatin'` and `mg: 500` -- that is
  /// the mock's demo data, not a default, and preselecting a form would store a
  /// claim the user never made about a medicine we cannot see.
  final String? form;

  /// How much is taken per occurrence, as whole units. Floors at
  /// [minimumAmount].
  ///
  /// An `int` because the control is a stepper and the design steps by one.
  /// `Medicine.dosageAmount` is a `double` -- half a tablet and 2.5 ml are both
  /// ordinary -- and [dosageAmount] widens it at the boundary. Fractional
  /// amounts are entered later, from Medicine detail.
  final int amount;

  /// The chosen dosage unit, one of `dosageUnits`, or `null` while nothing is
  /// chosen.
  ///
  /// The domain's value, not the chip's label: FR-1's vocabulary is
  /// `medicine_vocabulary.dart`'s lower-case set, and the capitalisation the
  /// design shows is a label the copy file owns.
  final String? unit;

  /// The free-text unit FR-1 permits behind its `other` option.
  ///
  /// Kept when the user moves off `Other` and back, rather than discarded:
  /// nothing in the matrix asks for it to be forgotten, and retyping a unit
  /// because a neighbouring chip was tapped is a loss with no purpose. It is
  /// ignored entirely unless [unit] is `dosageUnitOther`, so a stale value
  /// cannot leak into what is stored -- see [resolvedUnit].
  final String customUnit;

  /// The reminder time, as an hour of a 24-hour day.
  final int hourOfDay;

  /// The chosen repeat pattern.
  final AddMedicineRepeat repeat;

  /// The days `Specific days` names, as 1 (Monday) .. 7 (Sunday).
  ///
  /// `DateTime.monday` .. `DateTime.sunday`, so nothing has to guess whether
  /// the week starts at 0 or on Sunday. Empty for every other repeat, because
  /// changing the repeat discards them -- see [withRepeat].
  final Set<int> daysOfWeek;

  /// The interval `Every N days` counts in. Floors at
  /// `Schedule.minimumIntervalDays`.
  final int intervalDays;

  /// Whether the user wants reminders for this medicine.
  ///
  /// Records intent only. Epic 3 owns notification scheduling, and nothing in
  /// this flow schedules anything.
  final bool remindersEnabled;

  // --- What the flow shows -------------------------------------------------

  /// Whether the free-text unit input is on screen.
  bool get isCustomUnitChosen => unit == dosageUnitOther;

  /// Whether the inline seven-day row is expanded.
  bool get isDayRowExpanded => repeat.revealsDays;

  /// Whether the inline interval stepper is expanded.
  bool get isIntervalStepperExpanded => repeat.revealsInterval;

  // --- Whether a step may be left ------------------------------------------

  /// Whether step 1 has everything FR-1 requires.
  bool get isWhatComplete =>
      name.trim().isNotEmpty &&
      form != null &&
      resolvedUnit.isNotEmpty &&
      amount >= minimumAmount;

  /// Whether step 2's repeat option has the companion value it needs.
  ///
  /// `Specific days` needs at least one day. `Every N days` cannot fail here:
  /// [intervalDays] opens at the minimum and the stepper's decrement is inert
  /// below it, so there is no state in which it is short. That is asserted
  /// rather than assumed -- the interval is checked, so that a future change
  /// which let it fall below the minimum fails this getter instead of
  /// `Schedule.pairingViolation` at save time.
  bool get isWhenComplete {
    if (repeat.revealsDays) return daysOfWeek.isNotEmpty;
    if (repeat.revealsInterval) {
      return intervalDays >= Schedule.minimumIntervalDays;
    }
    return true;
  }

  /// Whether everything needed to write a Medicine and its Schedule is here.
  bool get isReviewComplete => isWhatComplete && isWhenComplete;

  /// Whether the flow's forward action is enabled on [step].
  ///
  /// The one place "Continue enabled" is decided. Three screens read it; none
  /// of them re-derives it.
  bool canAdvanceFrom(AddMedicineStep step) => switch (step) {
    AddMedicineStep.what => isWhatComplete,
    AddMedicineStep.when => isWhenComplete,
    AddMedicineStep.review => isReviewComplete,
  };

  // --- What is written -----------------------------------------------------

  /// The unit a Medicine created from this draft would store.
  ///
  /// Never the `other` sentinel: `medicine_vocabulary.dart` says why -- a row
  /// reading `other` would render as "1 other" on every dose card. Empty while
  /// no unit is chosen, and empty while `Other` is chosen with nothing typed,
  /// which is what keeps Continue disabled in both cases.
  String get resolvedUnit {
    final String? chosen = unit;
    if (chosen == null) return '';
    if (chosen == dosageUnitOther) return customUnit.trim();
    return chosen;
  }

  /// [condition] as the domain wants it: `null` rather than an empty string.
  ///
  /// An empty string and "not given" are the same fact, and storing the first
  /// would make `Condition · Form` render as ` · Tablet` on Home and detail.
  String? get conditionOrNull {
    final String trimmed = condition.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// [name] as the domain wants it.
  String get trimmedName => name.trim();

  /// The wall-clock time a Schedule created from this draft would store, as
  /// 24-hour `HH:mm` (AD-6).
  ///
  /// `Schedule.isValidTimeOfDay` is strict -- exactly two digits, a colon,
  /// exactly two digits -- because the duplicate-schedule rule compares these
  /// strings, so `8:00` and `08:00` would be two spellings of one time that
  /// compared unequal.
  String get timeOfDay => '${hourOfDay.toString().padLeft(2, '0')}:00';

  /// [amount] as `Medicine.dosageAmount` and `Schedule.dosageAmount` want it.
  double get dosageAmount => amount.toDouble();

  /// The `Frequency` a Schedule created from this draft would carry.
  Frequency get frequency => repeat.frequency;

  /// The `daysOfWeek` companion `addSchedule` wants, or `null`.
  ///
  /// `null` for every repeat but `Specific days`, because
  /// `Schedule.pairingViolation` rejects a day set on any other -- an empty
  /// set would be rejected too, so this cannot be "the days, whatever they
  /// are".
  Set<int>? get scheduleDaysOfWeek =>
      repeat.revealsDays ? Set<int>.unmodifiable(daysOfWeek) : null;

  /// The `intervalDays` companion `addSchedule` wants, or `null`.
  int? get scheduleIntervalDays => repeat.revealsInterval ? intervalDays : null;

  // --- Edits ---------------------------------------------------------------

  /// This draft with [value] as the medicine's name.
  AddMedicineDraft withName(String value) => _copyWith(name: value);

  /// This draft with [value] as the condition.
  AddMedicineDraft withCondition(String value) => _copyWith(condition: value);

  /// This draft with [value] as the chosen form.
  AddMedicineDraft withForm(String value) => _copyWith(form: value);

  /// This draft with [value] as the chosen unit.
  AddMedicineDraft withUnit(String value) => _copyWith(unit: value);

  /// This draft with [value] as the free-text unit.
  AddMedicineDraft withCustomUnit(String value) => _copyWith(customUnit: value);

  /// This draft with one more of whatever is being taken.
  AddMedicineDraft withMoreAmount() => _copyWith(amount: amount + 1);

  /// This draft with one less, floored at [minimumAmount].
  ///
  /// At the floor this returns a draft equal to this one, so the control is
  /// inert rather than an error: there is nothing to explain about a dose that
  /// cannot go below one.
  AddMedicineDraft withLessAmount() =>
      _copyWith(amount: amount <= minimumAmount ? minimumAmount : amount - 1);

  /// This draft one hour later, wrapping past midnight.
  AddMedicineDraft withLaterTime() =>
      _copyWith(hourOfDay: (hourOfDay + 1) % hoursInDay);

  /// This draft one hour earlier, wrapping past midnight.
  ///
  /// `+ hoursInDay` before the modulo: Dart's `%` on a negative left operand
  /// would answer a negative hour, and `-1` would become `-1` rather than 23.
  AddMedicineDraft withEarlierTime() =>
      _copyWith(hourOfDay: (hourOfDay - 1 + hoursInDay) % hoursInDay);

  /// This draft with [value] as the repeat pattern, and both inline controls
  /// reset.
  ///
  /// The matrix's "Repeat changed away" row: choosing another option collapses
  /// the inline row and **discards** what it held. Keeping a day selection
  /// behind a collapsed control would let an invisible value decide whether
  /// Continue is enabled the next time `Specific days` is chosen, and would
  /// carry days the user picked minutes ago into a pattern they have since
  /// rejected.
  ///
  /// Choosing the option that is already chosen changes nothing at all, so
  /// re-tapping `Specific days` does not wipe the days just picked.
  AddMedicineDraft withRepeat(AddMedicineRepeat value) {
    if (value == repeat) return this;
    return _copyWith(
      repeat: value,
      daysOfWeek: const <int>{},
      intervalDays: Schedule.minimumIntervalDays,
    );
  }

  /// This draft with [day] added to or removed from the day selection.
  ///
  /// [day] is 1 (Monday) .. 7 (Sunday). Removing the last one leaves an empty
  /// set, which is a legitimate state of a half-filled form -- it disables
  /// Continue rather than being prevented, so the user is never trapped
  /// holding a day they did not want.
  AddMedicineDraft withDayToggled(int day) {
    final Set<int> next = <int>{...daysOfWeek};
    if (!next.remove(day)) next.add(day);
    return _copyWith(daysOfWeek: next);
  }

  /// This draft with one more day between doses.
  AddMedicineDraft withLongerInterval() =>
      _copyWith(intervalDays: intervalDays + 1);

  /// This draft with one fewer, floored at `Schedule.minimumIntervalDays`.
  ///
  /// Inert at the floor. An interval of 1 is `Every day` written the long way,
  /// and `Frequency` refuses to hold two spellings of one pattern.
  AddMedicineDraft withShorterInterval() => _copyWith(
    intervalDays: intervalDays <= Schedule.minimumIntervalDays
        ? Schedule.minimumIntervalDays
        : intervalDays - 1,
  );

  /// This draft with reminders on or off.
  AddMedicineDraft withReminders({required bool enabled}) =>
      _copyWith(remindersEnabled: enabled);

  /// The one copy constructor, private so that every edit above is a named
  /// intention rather than a call site assembling a new draft field by field.
  ///
  /// Nullable fields cannot be cleared through it -- `null` means "not
  /// supplied" -- which is fine, because nothing in this flow clears a chosen
  /// form or unit: the chips are a choice among options with no "none of them"
  /// among them.
  AddMedicineDraft _copyWith({
    String? name,
    String? condition,
    String? form,
    int? amount,
    String? unit,
    String? customUnit,
    int? hourOfDay,
    AddMedicineRepeat? repeat,
    Set<int>? daysOfWeek,
    int? intervalDays,
    bool? remindersEnabled,
  }) => AddMedicineDraft(
    name: name ?? this.name,
    condition: condition ?? this.condition,
    form: form ?? this.form,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    customUnit: customUnit ?? this.customUnit,
    hourOfDay: hourOfDay ?? this.hourOfDay,
    repeat: repeat ?? this.repeat,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    intervalDays: intervalDays ?? this.intervalDays,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
  );

  /// Value equality over every field.
  ///
  /// Not identity. The draft is held in a Riverpod notifier, and under identity
  /// equality every keystroke -- indeed every rebuild -- would look like a new
  /// value and repaint all three step screens. It also lets a test compare two
  /// drafts with one `expect`, so a field added without being carried through
  /// [_copyWith] shows up as an inequality rather than as a field nobody
  /// thought to assert.
  @override
  bool operator ==(Object other) =>
      other is AddMedicineDraft &&
      other.name == name &&
      other.condition == condition &&
      other.form == form &&
      other.amount == amount &&
      other.unit == unit &&
      other.customUnit == customUnit &&
      other.hourOfDay == hourOfDay &&
      other.repeat == repeat &&
      other.daysOfWeek.length == daysOfWeek.length &&
      other.daysOfWeek.containsAll(daysOfWeek) &&
      other.intervalDays == intervalDays &&
      other.remindersEnabled == remindersEnabled;

  @override
  int get hashCode => Object.hash(
    name,
    condition,
    form,
    amount,
    unit,
    customUnit,
    hourOfDay,
    repeat,
    // A Set's own hashCode is identity-based, so two equal day sets would
    // otherwise hash differently and break the == / hashCode contract.
    Object.hashAllUnordered(daysOfWeek),
    intervalDays,
    remindersEnabled,
  );

  @override
  String toString() =>
      'AddMedicineDraft($name, $amount $resolvedUnit $form, $timeOfDay, '
      '${repeat.name}, reminders $remindersEnabled)';
}
