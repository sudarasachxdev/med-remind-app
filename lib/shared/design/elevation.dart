// The product's shadow scale.
//
// Transcribed from the `elevation:` frontmatter of `DESIGN.md`, which is the
// source of truth. The delivered screens carry fourteen distinct box-shadows;
// they reduce to the six below because they were never fourteen decisions —
// they are two families and two singletons.
//
// The two families are the point. A card on the app surface casts an
// *ink-tinted* shadow — `rgba(30,26,80,…)`, the violet-black of the ink scale —
// so the shadow reads as the same material as the text above it. An accent
// surface casts an *accent-tinted* shadow — `rgba(108,92,231,…)`, the accent
// itself — so the glow belongs to the button rather than to generic black.
// Swapping one family for the other is the mistake this file exists to prevent:
// a violet glow under a white card looks like a bug, and a black shadow under
// the primary button makes it look switched off.
//
// A note on the blur number. CSS and Flutter both call it a blur radius but
// arrive at the Gaussian sigma differently, so a value transcribed 1:1 is
// visually very close, not identical. The number is transcribed rather than
// re-tuned: the contract owns it, and a widget that adjusts it by feel has
// forked the contract silently.

import 'package:flutter/painting.dart';

/// The six shadows declared by `DESIGN.md`.
///
/// Each is a single [BoxShadow] because each declares a single shadow. A
/// consumer wraps it in a list at the use site — `boxShadow: const
/// [MTElevation.raised]` — rather than this file guessing at stacks nothing has
/// asked for.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTElevation {
  /// `elevation/raised` — the resting shadow under a white card on the app
  /// surface: dose cards, medicine rows, the record card.
  static const BoxShadow raised = BoxShadow(
    color: Color.fromRGBO(30, 26, 80, 0.05),
    offset: Offset(0, 2),
    blurRadius: 10,
  );

  /// `elevation/raised-strong` — the same family, lifted: a sheet or a card
  /// that must read as sitting above its neighbours rather than beside them.
  static const BoxShadow raisedStrong = BoxShadow(
    color: Color.fromRGBO(30, 26, 80, 0.09),
    offset: Offset(0, 6),
    blurRadius: 20,
  );

  /// `elevation/accent` — the resting glow under an accent-filled surface.
  ///
  /// Tinted with the accent, not with black. See the file comment.
  static const BoxShadow accent = BoxShadow(
    color: Color.fromRGBO(108, 92, 231, 0.28),
    offset: Offset(0, 6),
    blurRadius: 16,
  );

  /// `elevation/accent-strong` — the primary action at its most prominent: the
  /// one button on the screen the eye should land on first.
  static const BoxShadow accentStrong = BoxShadow(
    color: Color.fromRGBO(108, 92, 231, 0.30),
    offset: Offset(0, 10),
    blurRadius: 22,
  );

  /// `elevation/overlay` — the toast, which floats over arbitrary content and
  /// so cannot borrow either tint.
  static const BoxShadow overlay = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.25),
    offset: Offset(0, 10),
    blurRadius: 26,
  );

  /// `elevation/knob` — the toggle knob. Tight and nearly black, because at
  /// 27px a tinted blur reads as a smudge rather than as a lift.
  static const BoxShadow knob = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.2),
    offset: Offset(0, 1),
    blurRadius: 3,
  );
}
