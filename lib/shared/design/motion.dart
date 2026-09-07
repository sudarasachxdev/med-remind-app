// The product's motion scale.
//
// Transcribed from the `motion:` frontmatter of `DESIGN.md`, which is the source
// of truth. Three durations and two easings — the delivered screens use no more
// than that, and a fourth duration invented at a use site is indistinguishable
// from a bug in the timing of the other three.
//
// `DESIGN.md` also declares the Reduce Motion rule as prose: "every duration
// collapses to zero; the final position renders immediately". [reduceMotion]
// below is that sentence as a value. It is a transcription, not a convenience:
// a screen that honours Reduce Motion by branching to a hand-written
// `Duration.zero` has re-decided the policy locally, and the next screen is
// free to decide it differently.
//
// Note what this file does NOT ship: an animation. Reading a duration from here
// does not make a widget accessible — the widget must still consult
// `MediaQuery.disableAnimations` and choose [reduceMotion]. Story 1.3 satisfied
// the Reduce Motion requirement by animating nothing at all, which is absence
// rather than compliance; the first screen that actually moves owes the branch.

import 'package:flutter/animation.dart';

/// The three durations and two easings declared by `DESIGN.md`.
///
/// Not instantiable and not extensible: a namespace for values, not a type.
abstract final class MTMotion {
  /// `motion/quick` — a state change on a control the finger is still touching:
  /// a press, a toggle, a chip selecting.
  static const Duration quick = Duration(milliseconds: 180);

  /// `motion/standard` — the default for anything that is not an entrance.
  static const Duration standard = Duration(milliseconds: 200);

  /// `motion/entrance` — content arriving: a sheet rising, a panel advancing.
  ///
  /// Longer than [standard] because an entrance has further to travel and a
  /// clipped one reads as a jump.
  static const Duration entrance = Duration(milliseconds: 260);

  /// `motion/reduce-motion` — the duration every one of the above collapses to
  /// when the platform asks for reduced motion.
  ///
  /// The final position renders immediately. See the file comment: this is the
  /// declared policy, not a local shortcut.
  static const Duration reduceMotion = Duration.zero;

  /// `motion/easing-standard` — `ease-out`.
  ///
  /// Decelerating: fast at the start, settling at the end. Everything that is
  /// not an entrance uses it.
  static const Curve easingStandard = Curves.easeOut;

  /// `motion/easing-entrance` — `cubic-bezier(.2,.8,.2,1)`.
  ///
  /// A sharper deceleration than [easingStandard], so an arriving surface
  /// appears to be caught rather than to coast to a halt.
  static const Curve easingEntrance = Cubic(0.2, 0.8, 0.2, 1);
}
