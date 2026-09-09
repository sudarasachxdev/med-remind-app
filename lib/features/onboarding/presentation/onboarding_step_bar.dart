// Onboarding's use of the shared step progress bar.
//
// The bar itself moved to `lib/shared/widgets/mt_step_progress_bar.dart` in
// Story 1.5, which is the second caller this file's own comment said would
// shape it: "It lives beside the panels rather than in `shared/widgets/`
// because add-medicine, the other user, is Story 1.5. Promoting it then -- with
// two real callers to shape it -- beats guessing its parameters now."
//
// What is left here is the one thing that is onboarding's and not shared: the
// translation from an [OnboardingPanel] to a position, a total and the
// sentence a screen reader hears. The shared widget deliberately knows about
// none of those, because a bar that knew about `OnboardingPanel` could not
// also serve `AddMedicineStep`.
//
// The wrapper is kept rather than being replaced at the call site so that the
// panel-to-position mapping stays a named, testable thing --
// `onboarding_screen_test.dart` finds the bar by this type and counts its
// filled segments.

import 'package:flutter/material.dart';

import '../../../shared/widgets/mt_step_progress_bar.dart';
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
    return MTStepProgressBar(
      step: panel.step,
      total: OnboardingPanel.count,
      semanticsLabel: OnboardingCopy.stepLabel(
        panel.step,
        OnboardingPanel.count,
      ),
    );
  }
}
