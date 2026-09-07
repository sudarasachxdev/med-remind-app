// The step progress bar: flat segments that fill as steps complete.
//
// DESIGN.md's component spec is "flat 4px segments, filled `accent` as steps
// complete. Used in onboarding (3) and add-medicine (3)." Height comes from
// `MTSpacing.s1`, which *is* 4, so the number appears nowhere.
//
// The unfilled segment is `MTColors.borderHairline`. The mock's onboarding
// block sets it with `onb2`/`onb3`, which resolve to `#EDECF5` when the step is
// not yet reached -- and `#EDECF5` is exactly `border-hairline`, so this needs
// no invention and no approximation. An earlier pass used `accentWash` here by
// analogy with the Record card's day-bars; that was a guess, and the mock
// disagrees with it.
//
// Neither segment's contrast is asserted in `test/design_tokens_test.dart`'s
// `_contrastPairs`, and deliberately: neither carries a word. DESIGN.md's contrast note licenses exactly this --
// "if a later story wants a genuinely lighter tone, that tone is decoration: a
// hairline, an inactive dot, something where nothing is being read." The bar's
// meaning is carried by [OnboardingCopy.stepLabel], which a screen reader
// announces and which no colour is involved in.
//
// It lives beside the panels rather than in `shared/widgets/` because
// add-medicine, the other user, is Story 1.5. Promoting it then -- with two
// real callers to shape it -- beats guessing its parameters now.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import '../onboarding_panel.dart';
import 'onboarding_copy.dart';

/// A row of [OnboardingPanel.count] segments, filled up to and including
/// [panel].
class OnboardingStepBar extends StatelessWidget {
  const OnboardingStepBar({required this.panel, super.key});

  /// The panel currently showing. Its own segment is filled, so panel 1 shows
  /// one filled segment and panel 3 shows three.
  final OnboardingPanel panel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: OnboardingCopy.stepLabel(panel.step, OnboardingPanel.count),
      // The segments say nothing; the label above says all of it. Without this
      // a screen reader would announce three anonymous containers.
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (final OnboardingPanel segment in OnboardingPanel.values) ...[
            if (!segment.isFirst) const SizedBox(width: MTSpacing.s2),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: segment.index <= panel.index
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
