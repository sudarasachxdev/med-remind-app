// FR-1's dosage-unit vocabulary, as a named constant.
//
// AD-1: pure Dart, no imports.
//
// FR-1: "Dosage unit is selected from a defined set (tablet, capsule, ml, drop,
// other); selecting 'other' permits a free-text unit." That set is a product
// decision, so it lives in `domain/policy/` with the escalation defaults and
// the glyph count -- the spine's Constants convention -- rather than as five
// string literals inside the Story 1.5 option list, where the picker and every
// later reader of a stored row would each hold their own copy.
//
// `form` deliberately has NO set here. FR-1 defines the vocabulary for the
// dosage unit only; the form is free text captured in the same step, and
// inventing a closed set for it would be this file guessing at a requirement
// nobody wrote. It is validated as non-empty and no further.

/// The dosage units FR-1 offers, in the order the picker shows them.
///
/// A `List` rather than a `Set` because the order is part of the requirement --
/// FR-1 names them in this order and Story 1.5's option rows follow it -- and
/// because [dosageUnitOther] has to be last: it is the escape hatch, not a
/// unit.
const List<String> dosageUnits = <String>[
  'tablet',
  'capsule',
  'ml',
  'drop',
  dosageUnitOther,
];

/// The FR-1 option that permits a free-text unit.
///
/// A Medicine stores the unit the user ended up with, never this sentinel: a
/// row reading `other` would render as "1 other" on every dose card. Story 1.5
/// swaps it for what the user typed, and this exists so that the picker and the
/// validation agree on which option opens the text field.
const String dosageUnitOther = 'other';

/// Whether [unit] is one of FR-1's fixed options.
///
/// `false` for a free-text unit, which is legitimate -- FR-1 permits one when
/// the user chooses [dosageUnitOther] -- so this is a question about the
/// picker, not a validation rule. `Medicine` requires only that the unit is
/// not blank.
bool isFixedDosageUnit(String unit) => dosageUnits.contains(unit);
