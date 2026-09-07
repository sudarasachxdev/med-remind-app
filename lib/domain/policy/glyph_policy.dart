// AD-22 — glyph assignment is deterministic and owned by creation.
//
// AD-1: pure Dart, no imports.
//
// The rule is one line of arithmetic, and it lives here rather than inside the
// repository for the reason AD-22 exists: the moment two places derive a
// Medicine's silhouette, the same Medicine wears different glyphs on Home and
// in History and the glyph stops identifying anything. There is one modulus and
// one expression of the rule, and every surface reads the *stored* index.
//
// The spine's Consistency Conventions put named constants in `domain/policy/`
// so that no magic number appears in a feature or an adapter.

/// How many distinct glyphs the design system provides.
///
/// Four tile/silhouette pairs, from DESIGN.md. Changing this changes which
/// glyph every future Medicine is assigned — and nothing reshuffles the
/// medicines already stored, so a change here permanently splits the record
/// into medicines numbered under the old modulus and medicines numbered under
/// the new one. It is a design decision, not a tuning knob.
const int glyphCount = 4;

/// The `glyphIndex` a Medicine created now must be given (AD-22).
///
/// [existingMedicineCount] is `count(existing medicines)` at the moment of
/// creation — every row in the table, active or not. The result is assigned
/// once, persisted on the Medicine row, and **never** recomputed.
///
/// After a deletion a new Medicine can be handed an index an existing Medicine
/// already wears. That is correct rather than a collision to fix: AD-22
/// promises only that *consecutive* additions differ and that no existing row
/// is ever reshuffled. Renumbering to avoid the overlap would change a
/// Medicine's identity on every surface it appears on, which is the failure the
/// decision was written to prevent.
///
/// Throws [ArgumentError] on a negative count: a count cannot be negative, and
/// Dart's `%` would return a non-negative index anyway, so the mistake would be
/// silently absorbed into a plausible-looking glyph.
int glyphIndexForNewMedicine(int existingMedicineCount) {
  if (existingMedicineCount < 0) {
    throw ArgumentError.value(
      existingMedicineCount,
      'existingMedicineCount',
      'a count of existing medicines cannot be negative',
    );
  }
  return existingMedicineCount % glyphCount;
}
