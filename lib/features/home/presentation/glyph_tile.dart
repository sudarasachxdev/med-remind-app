// AD-22's tint-and-shape lookup, rendered.
//
// `lib/domain/policy/glyph_policy.dart` owns the ARITHMETIC -- the
// `glyphIndex` a new Medicine is assigned -- but it cannot own this half: a
// tint is a `Color` and a shape is drawn with Flutter widgets, and AD-1 bans
// both under `lib/domain/`. This is the one place both halves of AD-22's fixed
// order come together: `0` pill on `state-taken-tile`, `1` ring on
// `accent-wash`, `2` square on `state-info-tile`, `3` diamond on
// `state-late-tile` -- DESIGN.md's Components section, transcribed exactly,
// with three of the four families reading their "glyph" ink from the token
// already named for it (`stateTakenGlyph`, `stateInfoGlyph`, `stateLateGlyph`)
// and the accent-wash family reading its own base `accent`, which is already
// the saturated partner `accentWash` is the pale one of -- no fifth
// "accent-glyph" token exists because none is needed.
//
// Story 1.5 did not extract this: its own step-3 summary tile is explicitly
// NOT the per-medicine glyph ("the tile is accentWash with an accent glyph...
// that index is minted inside the repository at the moment of the write, so
// nothing before Save can know it"). This is the first widget that reads a
// real, stored `glyphIndex`.
//
// Stable across every screen it appears on (Home, Schedule, History) because
// there is exactly one lookup, here, and every caller reads the same stored
// index through it -- the whole point AD-22 exists to protect.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';

/// The 52px tinted tile carrying one of AD-22's four geometric marks, chosen
/// by a Medicine's stored `glyphIndex`.
class GlyphTile extends StatelessWidget {
  /// Creates the tile for [glyphIndex] -- `Medicine.glyphIndex`, already
  /// validated to `0`..`glyphCount - 1` by the Medicine that carries it.
  const GlyphTile({required this.glyphIndex, super.key});

  /// Which of the four glyphs to draw.
  final int glyphIndex;

  /// Single-use measurements for the four marks, per DESIGN.md's Components
  /// section -- pill 24x11, ring 20x20, square 19x19 radius 6, diamond 17x17
  /// radius 4. None is on the shared token scale: each is one number used in
  /// exactly one place, which `dimensions.dart`'s own doc comment reserves for
  /// "the component that needs it" rather than a thirty-sixth shared entry.
  static const double _pillWidth = 24;
  static const double _pillHeight = 11;
  static const double _ringSize = 20;
  static const double _ringStrokeWidth = 3;
  static const double _squareSize = 19;
  static const double _squareRadius = 6;
  static const double _diamondSize = 17;
  static const double _diamondRadius = 4;

  /// A diamond is a square rotated a quarter-turn's half -- 45 degrees.
  static const double _diamondRotation = math.pi / 4;

  @override
  Widget build(BuildContext context) {
    final (Color tile, Color mark) = _colorsFor(glyphIndex);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tile,
        borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
      ),
      child: SizedBox(
        width: MTDimensions.tileMd,
        height: MTDimensions.tileMd,
        child: Center(child: _markFor(glyphIndex, mark)),
      ),
    );
  }

  /// The tile fill and the mark's own ink, by [glyphIndex] mod the four
  /// glyphs that exist -- mirroring `glyphIndexForNewMedicine`'s own modulus
  /// rather than trusting every caller to have already validated the range.
  static (Color, Color) _colorsFor(int glyphIndex) => switch (glyphIndex % 4) {
    0 => (MTColors.stateTakenTile, MTColors.stateTakenGlyph),
    1 => (MTColors.accentWash, MTColors.accent),
    2 => (MTColors.stateInfoTile, MTColors.stateInfoGlyph),
    _ => (MTColors.stateLateTile, MTColors.stateLateGlyph),
  };

  static Widget _markFor(int glyphIndex, Color mark) => switch (glyphIndex %
      4) {
    0 => DecoratedBox(
      decoration: BoxDecoration(
        color: mark,
        borderRadius: const BorderRadius.all(Radius.circular(MTRadius.pill)),
      ),
      child: const SizedBox(width: _pillWidth, height: _pillHeight),
    ),
    1 => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: mark, width: _ringStrokeWidth),
      ),
      child: const SizedBox(width: _ringSize, height: _ringSize),
    ),
    2 => DecoratedBox(
      decoration: BoxDecoration(
        color: mark,
        borderRadius: const BorderRadius.all(Radius.circular(_squareRadius)),
      ),
      child: const SizedBox(width: _squareSize, height: _squareSize),
    ),
    _ => Transform.rotate(
      angle: _diamondRotation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mark,
          borderRadius: const BorderRadius.all(Radius.circular(_diamondRadius)),
        ),
        child: const SizedBox(width: _diamondSize, height: _diamondSize),
      ),
    ),
  };
}
