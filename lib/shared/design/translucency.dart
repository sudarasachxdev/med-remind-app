// The product's translucent overlay colours.
//
// Transcribed from the `translucency:` frontmatter of `DESIGN.md`, which is the
// source of truth.
//
// These live apart from `MTColors` deliberately. Every token in `MTColors` is
// opaque and self-sufficient: `MTColors.accent` is that colour wherever it is
// painted. Every token here is a *film* whose result depends entirely on what
// it is painted over — `glass` over the accent is a pale violet, and over the
// app surface it is invisible. Mixing the two scales into one namespace invites
// the error of reaching for a film where a colour was wanted, which produces a
// widget that looks correct on the screen it was built for and vanishes on the
// next one.
//
// Each token's name says what it must sit on. `chip-on-accent` and
// `hairline-on-ink` say so outright; `glass` and `glass-quiet` are white films
// and so are only visible over the accent surfaces. `scrim` is the exception —
// it goes over the whole app, which is its entire job.

import 'package:flutter/painting.dart';

/// The five translucencies declared by `DESIGN.md`.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTTranslucency {
  /// `translucency/scrim` — the modal backdrop behind the action sheet.
  ///
  /// Violet-black rather than neutral black, so the dimmed app underneath stays
  /// recognisably this product rather than turning grey.
  static const Color scrim = Color.fromRGBO(14, 12, 32, 0.4);

  /// `translucency/glass` — a white film over an accent surface, used for a
  /// raised region inside an accent-filled card.
  static const Color glass = Color.fromRGBO(255, 255, 255, 0.14);

  /// `translucency/glass-quiet` — [glass] at lower strength, for a region that
  /// should separate from its accent background without asking to be read as a
  /// control.
  static const Color glassQuiet = Color.fromRGBO(255, 255, 255, 0.09);

  /// `translucency/chip-on-accent` — the fill behind a chip sitting on an
  /// accent surface, where `MTColors.surfaceMuted` would be an opaque grey
  /// patch.
  static const Color chipOnAccent = Color.fromRGBO(255, 255, 255, 0.16);

  /// `translucency/hairline-on-ink` — a divider tinted with the ink rather than
  /// with grey, so a 1px rule reads as a seam in the surface instead of as a
  /// drawn line.
  static const Color hairlineOnInk = Color.fromRGBO(22, 22, 29, 0.06);
}
