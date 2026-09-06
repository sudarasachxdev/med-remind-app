// The product's radius and spacing scales.
//
// Transcribed from the `rounded:` and `spacing:` frontmatter of `DESIGN.md`,
// which is the source of truth for both the names and the values. These exist
// so that 14 and 16 are never chosen by feel: a widget picks a step on the
// scale, and the scale is the same everywhere.
//
// Both are plain `double` logical pixels rather than `BorderRadius` or
// `EdgeInsets`. This story ships values, not UI; the widgets that wrap them
// belong to Story 1.3 onward.

/// The six corner radii declared by `DESIGN.md`.
///
/// Nothing in the product is square-cornered. The impression should be
/// soft-edged without being bubbly.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTRadius {
  /// `rounded/xs` — glyph marks and the smallest inset elements.
  static const double xs = 6;

  /// `rounded/sm` — small inset elements.
  static const double sm = 9;

  /// `rounded/md` — glyph tiles, inputs, and the next-dose chip.
  static const double md = 14;

  /// `rounded/lg` — dose and medicine cards.
  static const double lg = 18;

  /// `rounded/xl` — the action sheet's top corners and the progress card.
  static const double xl = 20;

  /// `rounded/pill` — chips, day pills, toggles, buttons and the progress ring.
  ///
  /// A sentinel large enough to round any height into a capsule, not a measured
  /// radius.
  static const double pill = 999;
}

/// The seven spacing steps declared by `DESIGN.md`: 4 / 8 / 12 / 16 / 20 / 26 /
/// 34 logical pixels.
///
/// The frontmatter names the steps `1`–`7`. A Dart identifier cannot be a bare
/// digit, so each is prefixed with `s`: frontmatter `3` is [s3]. The mapping is
/// mechanical, and the step number — not the pixel value — is the name, so the
/// scale can be read as a scale.
///
/// Screen gutters are [s4] on content screens and [s6] on onboarding, which is
/// deliberately airier. Cards sit [s3] apart in a list.
///
/// `DESIGN.md`'s prose gives two of those as ranges — gutters "16–18px", cards
/// "10–12px". The steps above are the ones inside those ranges; the off-scale
/// ends (18, 10) are deliberately not quoted here, because a doc comment that
/// names a number outside the scale licenses exactly the by-feel choice the
/// scale exists to prevent. If a screen genuinely needs 18, the answer is a new
/// step in `DESIGN.md`, not a literal in a widget.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTSpacing {
  /// Step 1 — 4px.
  static const double s1 = 4;

  /// Step 2 — 8px.
  static const double s2 = 8;

  /// Step 3 — 12px.
  static const double s3 = 12;

  /// Step 4 — 16px.
  static const double s4 = 16;

  /// Step 5 — 20px.
  static const double s5 = 20;

  /// Step 6 — 26px.
  static const double s6 = 26;

  /// Step 7 — 34px.
  static const double s7 = 34;
}
