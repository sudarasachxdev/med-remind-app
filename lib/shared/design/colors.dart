// The product's entire colour vocabulary.
//
// Transcribed from the `colors:` frontmatter of
// `_bmad-output/planning-artifacts/ux-designs/ux-medi_tracker-2026-08-24/DESIGN.md`,
// which is the source of truth for BOTH the names and the values. Names are the
// frontmatter's keys, lower-camelled: `surface-app` becomes `surfaceApp`,
// `state-taken-tile` becomes `stateTakenTile`. The mapping is mechanical so
// that a reviewer can diff the two lists by eye.
//
// Every colour DECLARED BY THE FRONTMATTER is here, and the frontmatter is
// what widgets build from. It is not every colour that will ever appear in the
// product: `DESIGN.md`'s prose also describes the lock-screen gradient
// (`#1B1636` -> `#0C0B17`), its translucent white glass, the toast's dark pill
// and the next-dose chip's white ink, none of which the frontmatter declares
// and none of which is transcribed here. The story that builds one of those
// surfaces adds its tokens to this file, in the open, rather than reaching for
// a literal.
//
// `test/architecture_test.dart` fails the build on a literal colour — a `Color`
// constructor, Flutter's `Colors`/`CupertinoColors` palettes, or an `HSLColor`
// / `HSVColor` conversion — anywhere under `lib/` except this directory, so a
// widget cannot quietly invent a thirty-first violet.
//
// Light palette only. UX-DR22 puts dark mode out of scope for V1: there is no
// dark variant, no `ThemeMode` and no brightness branching here, because a
// half-built dark theme is worse than none.
//
// UX-DR21: red appears in exactly three tokens — `stateDangerSurface`,
// `stateDangerSurfacePressed` and `stateDangerInk` — reserved for FR-3's
// *Delete medicine* control. An overdue dose is amber (`stateLate*`); a skipped
// dose is neutral (`stateNeutralTile`). Nothing else in the product is red.

import 'package:flutter/painting.dart';

/// The 30 colour tokens declared by `DESIGN.md`.
///
/// Not instantiable and not extensible: this is a namespace for values, not a
/// type. Consumers read `MTColors.accent`, never a literal.
abstract final class MTColors {
  // --- Surfaces -------------------------------------------------------------
  // The page, then everything that sits on it. `surfaceRaised` is the card
  // fill; `surfaceMuted` and `surfaceInset` carry chips and grouped rows.

  /// `surface-app` — the page behind everything.
  static const Color surfaceApp = Color(0xFFF7F7FB);

  /// `surface-raised` — cards and sheets, lifted off the page.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// `surface-sunken` — unselected option rows.
  static const Color surfaceSunken = Color(0xFFFAFAFD);

  /// `surface-muted` — grouped rows.
  static const Color surfaceMuted = Color(0xFFF4F3FA);

  /// `surface-inset` — inset elements inside a card.
  static const Color surfaceInset = Color(0xFFF1F0F7);

  // --- Ink ------------------------------------------------------------------
  // Text and marks, running from the primary reading colour down to disabled.

  /// `ink-primary` — headings and primary reading text.
  static const Color inkPrimary = Color(0xFF16161D);

  /// `ink-secondary` — supporting copy.
  static const Color inkSecondary = Color(0xFF4A4A5E);

  /// `ink-tertiary` — metadata rows.
  static const Color inkTertiary = Color(0xFF5D5D75);

  /// `ink-muted` — recessive text, and the mark on a skipped dose.
  static const Color inkMuted = Color(0xFF6B6B84);

  /// `ink-faint` — the least emphatic readable ink.
  static const Color inkFaint = Color(0xFF6F6F8A);

  /// `ink-disabled` — text in a control that cannot be used.
  static const Color inkDisabled = Color(0xFFC2C2D0);

  // --- Accent ---------------------------------------------------------------
  // The single chromatic colour that carries interaction meaning: the primary
  // action, the selected day, the active tab, the enabled toggle. Nothing else.

  /// `accent` — the one chromatic colour of interaction.
  static const Color accent = Color(0xFF6C5CE7);

  /// `accent-pressed` — the accent while a control is held.
  static const Color accentPressed = Color(0xFF5A48DE);

  /// `accent-wash` — the accent's low-emphasis partner: selected chips, glyph
  /// tiles, stepper buttons.
  static const Color accentWash = Color(0xFFEEEBFE);

  /// `accent-border` — the hairline around a selected, accent-washed control.
  static const Color accentBorder = Color(0xFFC9BFF7);

  /// `accent-ink` — accent-coloured **text**, specifically on `accentWash`.
  ///
  /// [accent] on [accentWash] measures 4.15:1, below AA for the 12px chip text
  /// that pairing is used for. Darkening [accent] itself would have changed
  /// every fill, tab and toggle in the product to fix one text case, so reading
  /// gets its own value. [accent] stays the interaction colour.
  static const Color accentInk = Color(0xFF5B4FBE);

  // --- Borders --------------------------------------------------------------
  // Cards and rows are separated by fill and hairline alone; elevation is
  // reserved for the action sheet, the toast and the selected day pill.

  /// `border-hairline` — the default separator.
  static const Color borderHairline = Color(0xFFEDECF5);

  /// `border-strong` — a firmer edge, and the off state of a toggle track.
  static const Color borderStrong = Color(0xFFE4E3EF);

  // --- Semantic state -------------------------------------------------------
  // Three states, each a tile/mark pair, so state never rests on colour alone:
  // taken (green, quiet rather than celebratory), late (amber, never red) and
  // skipped (neutral, deliberately recessive). `info` tints the glyph tile.

  /// `state-taken-tile` — the fill behind a recorded dose, and glyph tint 0.
  static const Color stateTakenTile = Color(0xFFD7F2E1);

  /// `state-taken-mark` — the ink and `✓` of a recorded dose.
  static const Color stateTakenMark = Color(0xFF117A44);

  /// `state-taken-glyph` — the glyph drawn on a taken tile.
  static const Color stateTakenGlyph = Color(0xFF159845);

  /// `state-late-tile` — the amber fill of an overdue dose, and glyph tint 3.
  static const Color stateLateTile = Color(0xFFFBEBD5);

  /// `state-late-mark` — the ink and `!` of an overdue dose.
  static const Color stateLateMark = Color(0xFF946118);

  /// `state-late-ink` — overdue body text, darker than the mark.
  static const Color stateLateInk = Color(0xFF8A5A11);

  /// `state-late-glyph` — the glyph drawn on a late tile.
  static const Color stateLateGlyph = Color(0xFFC97C1B);

  /// `state-info-tile` — glyph tint 2.
  static const Color stateInfoTile = Color(0xFFDCEBFB);

  /// `state-info-glyph` — the glyph drawn on an info tile.
  static const Color stateInfoGlyph = Color(0xFF2C7BD4);

  /// `state-neutral-tile` — a skipped dose. Recessive by design: skipping is a
  /// legitimate choice and must not look like a failure.
  static const Color stateNeutralTile = Color(0xFFEFEFF5);

  // --- Danger ---------------------------------------------------------------
  // The only reds in the product (UX-DR21). Declared here rather than invented
  // at Story 4.3 so the token layer is built once; they appear on exactly one
  // control, *Delete medicine* (FR-3).

  /// `state-danger-surface` — the fill of the delete control.
  static const Color stateDangerSurface = Color(0xFFFDF0F0);

  /// `state-danger-surface-pressed` — that fill while the control is held.
  static const Color stateDangerSurfacePressed = Color(0xFFFBE4E4);

  /// `state-danger-ink` — the label of the delete control.
  static const Color stateDangerInk = Color(0xFFC0392B);
}
