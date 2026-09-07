// The Medicine aggregate root (AD-12).
//
// AD-1: pure Dart. The only import is the sibling policy that owns the glyph
// count, which `test/architecture_test.dart` permits -- a relative import
// inside the domain is how the domain is allowed to be built out of more than
// one file.
//
// Vocabulary is PRD §3's, verbatim: `Medicine`, never `Drug`.

import '../policy/glyph_policy.dart';

/// One medicine the user takes, and the root of its aggregate.
///
/// A Medicine owns its `Schedule`s (AD-12): they have no independent lifecycle,
/// they are created, edited and deleted only through `MedicineRepository`, and
/// deleting the Medicine deletes them. This class holds no list of them
/// because a Medicine is loaded and edited without them far more often than
/// with them; `MedicineRepository.schedulesFor` reads them when they are
/// wanted.
///
/// Dates here are **calendar dates**, not instants: `startDate` is the day the
/// regimen begins in the user's own reckoning, and a Medicine started on the
/// 1st was not started on the 31st because the phone was in another zone. The
/// adapter persists them as `YYYY-MM-DD` text for exactly that reason -- see
/// [dateOnly], which the constructor applies so that a `DateTime` carrying a
/// time of day cannot become part of a Medicine's identity.
///
/// **Where the rules live.** The constructor throws for values no user
/// interface can produce -- a glyph outside the four that exist, a dosage
/// amount that is not a number. Everything a half-filled form can hold is
/// reported by [violation] instead, as a sentence, so a form can show it while
/// the user is still typing. `Schedule` splits its rules the same way, and the
/// repository refuses to write a Medicine whose [violation] is non-null.
final class Medicine {
  /// Creates a Medicine.
  ///
  /// [startDate] and [endDate] are truncated to their calendar date by
  /// [dateOnly]; a caller that passes a wall-clock instant gets the day it
  /// falls on rather than a silent time component that two readers would then
  /// compare differently.
  ///
  /// Throws [ArgumentError] when [glyphIndex] is not one of the glyphs that
  /// exist, or when [dosageAmount] is `NaN` or infinite. Both are programming
  /// errors: AD-22 assigns the glyph and no form can type an infinity. A
  /// non-finite amount is rejected here rather than by [violation] because it
  /// poisons every later comparison -- `NaN <= 0` is `false`, so it would slip
  /// past a range check and be stored, and SQLite has no `NaN` to read back.
  Medicine({
    required this.id,
    required this.name,
    this.condition,
    required this.glyphIndex,
    required this.form,
    required this.dosageAmount,
    required this.dosageUnit,
    this.instructions,
    required DateTime startDate,
    DateTime? endDate,
    this.active = true,
  }) : startDate = dateOnly(startDate),
       endDate = endDate == null ? null : dateOnly(endDate) {
    if (glyphIndex < 0 || glyphIndex >= glyphCount) {
      throw ArgumentError.value(
        glyphIndex,
        'glyphIndex',
        'must be 0 through ${glyphCount - 1}: AD-22 assigns it as '
            'count(existing medicines) mod $glyphCount, and every surface '
            'renders it through one lookup of that size',
      );
    }
    if (dosageAmount.isNaN || dosageAmount.isInfinite) {
      throw ArgumentError.value(
        dosageAmount,
        'dosageAmount',
        'must be a finite number',
      );
    }
  }

  /// UUID v4, as text (the spine's Identifiers convention).
  final String id;

  /// What the user calls it. Required by FR-1.
  final String name;

  /// What it is for, in the user's own words. Optional.
  ///
  /// Free text, displayed and never interpreted: the PRD forbids validating it,
  /// looking it up, or deriving anything from it. It is a memory aid, not a
  /// clinical field.
  final String? condition;

  /// Which of the design system's glyphs represents this Medicine (AD-22).
  ///
  /// Assigned once at creation by `glyphIndexForNewMedicine`, persisted, and
  /// never recomputed. The user does not choose it and no UI exposes it.
  final int glyphIndex;

  /// Tablet, capsule, drops, and so on. Required by FR-1.
  ///
  /// Free text with no closed vocabulary, deliberately: FR-1 defines a fixed
  /// set for the dosage *unit* (see `dosageUnits`) and says nothing about the
  /// form, so a set here would be an invented requirement. Validated as
  /// non-blank and no further.
  final String form;

  /// How much is taken per dose by default. Required by FR-1.
  ///
  /// A `double` because half a tablet and 2.5 ml are both ordinary. A
  /// `Schedule` may override it per occurrence.
  final double dosageAmount;

  /// The unit [dosageAmount] is counted in -- tablets, ml, mg. Required by
  /// FR-1, which offers `dosageUnits` and permits free text behind its
  /// `other` option, so this is not restricted to that set.
  final String dosageUnit;

  /// Anything else the user wants to remember -- "with food". Optional, and
  /// deliberately not captured by the Story 1.5 add flow.
  final String? instructions;

  /// The calendar day the regimen begins. Never has a time component.
  ///
  /// FR-1 says a new Medicine defaults to "a start date of today", and this
  /// class does not know what today is: AD-5 confines the ambient clock to the
  /// adapter under `lib/platform/clock/`, and neither this model nor
  /// `MedicineRepository` reads it. Answering "today" is the *caller's* job --
  /// Story 1.5's form, through the `Clock` port Story 1.6 introduces for dose
  /// resolution. Deliberately not introduced here: a port with no consumer
  /// would be a placeholder, and Story 1.6 owns the shape it needs (a
  /// `TZDateTime` in the dose's own zone, not a bare `DateTime`).
  final DateTime startDate;

  /// The calendar day the regimen ends, inclusive, or `null` for open-ended.
  /// Never has a time component.
  final DateTime? endDate;

  /// Whether the Medicine is currently being taken.
  ///
  /// Dose generation honours this. It is separate from deletion because
  /// stopping a medicine must not erase the history of having taken it.
  final bool active;

  /// [moment] with its time of day discarded, keeping the local calendar date.
  ///
  /// Not `toUtc()` and not a UTC midnight: at 01:00 in Asia/Colombo those are
  /// the previous day, and a Medicine started today would read as started
  /// yesterday. The date is taken in whatever zone [moment] is already in.
  static DateTime dateOnly(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// Why this Medicine may not be saved, or `null` when it may.
  ///
  /// Returned as a message rather than thrown so that a form can show it while
  /// the user is still filling it in -- the same split `Schedule` uses for its
  /// frequency pairing. `MedicineRepository` refuses any Medicine for which
  /// this is non-null, so the rule is enforced once and stated once.
  ///
  /// FR-1: a Medicine cannot be saved without a name and a dosage amount with
  /// unit. FR-2 gives the end date real behaviour, which an end date before
  /// the start date cannot have -- it would describe a regimen with no days in
  /// it, and dose generation would silently produce nothing.
  String? violation() {
    if (name.trim().isEmpty) {
      return 'Enter the name of the medicine.';
    }
    if (dosageAmount <= 0) {
      return 'Enter how much is taken, as a number above zero.';
    }
    if (dosageUnit.trim().isEmpty) {
      return 'Choose the unit the dose is measured in.';
    }
    if (form.trim().isEmpty) {
      return 'Choose the form the medicine comes in.';
    }
    final DateTime? end = endDate;
    if (end != null && end.isBefore(startDate)) {
      return 'The end date is before the start date.';
    }
    return null;
  }

  /// A copy with the given fields replaced.
  ///
  /// [id] and [glyphIndex] are absent by design: an edit may not move a
  /// Medicine's identity, and AD-22 forbids recomputing its glyph. Nullable
  /// fields cannot be cleared through this method -- passing `null` keeps the
  /// current value, because `null` is indistinguishable from "not supplied" --
  /// so clearing one is done by constructing the Medicine directly.
  Medicine copyWith({
    String? name,
    String? condition,
    String? form,
    double? dosageAmount,
    String? dosageUnit,
    String? instructions,
    DateTime? startDate,
    DateTime? endDate,
    bool? active,
  }) => Medicine(
    id: id,
    name: name ?? this.name,
    condition: condition ?? this.condition,
    glyphIndex: glyphIndex,
    form: form ?? this.form,
    dosageAmount: dosageAmount ?? this.dosageAmount,
    dosageUnit: dosageUnit ?? this.dosageUnit,
    instructions: instructions ?? this.instructions,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    active: active ?? this.active,
  );

  /// Value equality over every field.
  ///
  /// Not identity: from Story 1.5 a Medicine is held in a Riverpod provider,
  /// and under identity equality every rebuild would see a "new" value and
  /// repaint every surface showing it. It also means a test can compare two
  /// Medicines with one `expect` instead of field by field, so a field added
  /// without being carried through `copyWith` or the adapter's mapping shows up
  /// as an inequality rather than as a field nobody thought to assert.
  @override
  bool operator ==(Object other) =>
      other is Medicine &&
      other.id == id &&
      other.name == name &&
      other.condition == condition &&
      other.glyphIndex == glyphIndex &&
      other.form == form &&
      other.dosageAmount == dosageAmount &&
      other.dosageUnit == dosageUnit &&
      other.instructions == instructions &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    condition,
    glyphIndex,
    form,
    dosageAmount,
    dosageUnit,
    instructions,
    startDate,
    endDate,
    active,
  );

  @override
  String toString() =>
      'Medicine($id, $name, glyph $glyphIndex, '
      '$dosageAmount $dosageUnit $form)';
}
