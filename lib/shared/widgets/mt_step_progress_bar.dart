// The three-segment step progress bar, promoted to `shared/` for its second
// caller.
//
// It arrived in Story 1.3 as `OnboardingStepBar`, whose own file said why it
// was not shared yet: "It lives beside the panels rather than in
// `shared/widgets/` because add-medicine, the other user, is Story 1.5.
// Promoting it then -- with two real callers to shape it -- beats guessing its
// parameters now." Story 1.5 is that caller, so this is that promotion, and the
// two callers between them shaped the parameters: a 1-based position, a total,
// and the sentence a screen reader hears. Neither caller's own enum appears
// here, because a widget that knew about `OnboardingPanel` could not serve
// `AddMedicineStep`.
//
// DESIGN.md's component spec is "flat 4px segments, filled `accent` as steps
// complete. Used in onboarding (3) and add-medicine (3)." The height comes from
// `MTSpacing.s1`, which *is* 4, so the number appears nowhere.
//
// The unfilled segment is `MTColors.borderHairline`. The mock's onboarding
// block sets it with `onb2`/`onb3` and the add block with `s2`/`s3`, and all
// four resolve to `#EDECF5` when the step is not yet reached -- which is
// exactly `border-hairline`, in both screens, so this needs no invention and no
// approximation.
//
// Neither segment's contrast is asserted in `test/design_tokens_test.dart`'s
// `_contrastPairs`, and deliberately: neither carries a word. DESIGN.md's
// contrast note licenses exactly this -- "if a later story wants a genuinely
// lighter tone, that tone is decoration: a hairline, an inactive dot, something
// where nothing is being read." The bar's meaning is carried by
// [semanticsLabel], which a screen reader announces and which no colour is
// involved in.

import 'package:flutter/material.dart';

import '../design/design.dart';

/// A row of [total] flat segments, the first [step] of them filled.
class MTStepProgressBar extends StatelessWidget {
  /// Creates the bar. [step] is 1-based, so `step: 1` fills one segment.
  const MTStepProgressBar({
    required this.step,
    required this.total,
    required this.semanticsLabel,
    super.key,
  });

  /// The step showing, counted from one. Its own segment is filled.
  final int step;

  /// How many segments there are.
  final int total;

  /// The sentence a screen reader hears -- `Step 2 of 3`.
  ///
  /// Passed in rather than composed here: both callers already own their copy,
  /// and a widget that wrote this string would be the one place in the product
  /// where user-facing words live outside a copy file.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      // The segments say nothing; the label above says all of it. Without this
      // a screen reader would announce three anonymous containers.
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int segment = 1; segment <= total; segment++) ...<Widget>[
            if (segment > 1) const SizedBox(width: MTSpacing.s2),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: segment <= step
                      ? MTColors.accent
                      : MTColors.borderHairline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(MTRadius.pill),
                  ),
                ),
                child: const SizedBox(height: MTSpacing.s1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
