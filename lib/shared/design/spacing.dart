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

/// The nine corner radii declared by `DESIGN.md`.
///
/// Nothing in the product is square-cornered. The impression should be
/// soft-edged without being bubbly.
///
/// This was six steps until 2026-09-07. Measured against the delivered screens
/// the six covered the design badly: two of them were used nowhere at all, and
/// `16px` — the most-used radius in the whole product, carrying the primary
/// button, the text inputs and the add-medicine tiles — was not on the scale.
/// Nine steps cover all 131 uses; twenty of those shift, every one by at most
/// 2px, and the four most-used values are exact.
///
/// The frontmatter names three of the steps `2xl`, `3xl` and `4xl`. A Dart
/// identifier cannot begin with a digit, so each is transposed to [xl2], [xl3]
/// and [xl4]. The mapping is mechanical, as `spacing:`'s `1`-`7` to [MTSpacing]'s
/// `s1`-`s7` is.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTRadius {
  /// `rounded/xs` — glyph marks and the smallest inset elements.
  static const double xs = 8;

  /// `rounded/sm` — small inset elements and inline badges.
  static const double sm = 12;

  /// `rounded/md` — glyph tiles and the next-dose chip.
  static const double md = 14;

  /// `rounded/lg` — the primary button, text inputs, and the add-medicine
  /// tiles.
  ///
  /// The most-used radius in the product. If a new surface has no obvious step,
  /// this is the one it probably wants.
  static const double lg = 16;

  /// `rounded/xl` — dose and medicine cards.
  static const double xl = 18;

  /// `rounded/2xl` — the progress card and other full-width panels.
  static const double xl2 = 20;

  /// `rounded/3xl` — the action sheet's top corners.
  static const double xl3 = 26;

  /// `rounded/4xl` — the largest rounded surface: a full-bleed accent panel.
  static const double xl4 = 30;

  /// `rounded/pill` — chips, day pills, toggles and the progress ring.
  ///
  /// A sentinel large enough to round any height into a capsule, not a measured
  /// radius. `DESIGN.md` writes `999px`; the delivered screens write `99px`
  /// thirty-four times. Both round fully at every height the product uses, so
  /// the contract's value is the one transcribed here.
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
