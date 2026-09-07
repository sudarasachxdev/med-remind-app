// The onboarding surface: one route, three panels, one step bar.
//
// Full-screen and no tab bar, per EXPERIENCE.md's information architecture.
// The 26px gutter (`MTSpacing.s6`) is onboarding's own -- deliberately airier
// than the 16-18px content screens get.
//
// ONE ROUTE, NOT THREE. The visible panel is provider state
// (`onboardingFlowProvider`), so the OS back gesture passes through this
// screen's `PopScope` and retreats a panel instead of popping a route. On
// panel 1 it does nothing at all, which is the matrix's "Back from 1: nothing
// -- no route beneath it to pop to. Must not exit the app." Three routes would
// have made that row impossible to satisfy without fighting the navigator, and
// would have let a future deep link open panel 3 on its own.
//
// NOTHING HERE ASKS THE OS FOR ANYTHING. Panel 3 explains why notifications are
// wanted and states that declining is fine; both of its actions go to Home.
// Story 3.1 gives "Allow notifications" its real behaviour, when there are
// notifications to permit. There is no permission plugin imported anywhere in
// this feature, which is the only durable form of that promise.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/design/design.dart';
import '../onboarding_panel.dart';
import '../providers/onboarding_flow_provider.dart';
import 'escalation_timeline.dart';
import 'onboarding_copy.dart';
import 'onboarding_step_bar.dart';

/// The onboarding panels.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingPanel panel = ref.watch(onboardingFlowProvider);
    final OnboardingFlow flow = ref.read(onboardingFlowProvider.notifier);

    return PopScope<Object?>(
      // Never pop the route. The gesture means "go back one panel", and on
      // panel 1 there is nothing to go back to -- so it is swallowed rather
      // than allowed to close the app mid-explanation.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        flow.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s6),
            // THE WHOLE PANEL SCROLLS, back control and step bar included.
            //
            // An earlier version pinned the back control and the step bar above
            // an Expanded scroll view. That reflows the copy but starves the
            // Expanded: once the pinned header is taller than the viewport --
            // a short screen at the largest accessibility text size, where the
            // back button alone is over 50 logical pixels of type -- the
            // Expanded is handed a negative height and the Column overflows,
            // which is a truncation and precisely what UX-DR20 forbids.
            //
            // ConstrainedBox(minHeight: viewport) + IntrinsicHeight is the
            // recipe that keeps both properties: when the content is shorter
            // than the screen the Column is exactly viewport-tall and the
            // Spacer pushes the actions to the bottom edge, as the mock draws
            // them; when the content is taller, the Column takes its intrinsic
            // height and the whole thing scrolls.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: MTSpacing.s5),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            // A constant minimum height on both branches, so
                            // the step bar and the title do not shift down
                            // between panel 1 and panel 2. It is a minimum,
                            // not a size: the button grows past it when the
                            // label does.
                            child: panel.isFirst
                                ? const SizedBox(
                                    height: kMinInteractiveDimension,
                                  )
                                : TextButton(
                                    onPressed: flow.back,
                                    child: const Text(
                                      OnboardingCopy.actionBack,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: MTSpacing.s4),
                          OnboardingStepBar(panel: panel),
                          const SizedBox(height: MTSpacing.s7),
                          _PanelBody(panel: panel),
                          const SizedBox(height: MTSpacing.s7),
                          const Spacer(),
                          _PanelActions(panel: panel),
                          const SizedBox(height: MTSpacing.s6),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The copy of one panel.
class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.panel});

  final OnboardingPanel panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: switch (panel) {
        OnboardingPanel.value => <Widget>[
          // `headingXl` is the onboarding lead and nothing else in the
          // product -- DESIGN.md reserves it for this one string.
          const _PanelTitle(
            OnboardingCopy.panel1Title,
            style: MTTypography.headingXl,
          ),
          const SizedBox(height: MTSpacing.s5),
          const _PanelParagraph(OnboardingCopy.panel1BodyWhatItIs),
          const SizedBox(height: MTSpacing.s3),
          const _PanelParagraph(OnboardingCopy.panel1BodyPrivacy),
        ],
        OnboardingPanel.escalation => <Widget>[
          const _PanelTitle(OnboardingCopy.panel2Title),
          const SizedBox(height: MTSpacing.s5),
          const _PanelParagraph(OnboardingCopy.panel2Body),
          const SizedBox(height: MTSpacing.s6),
          const EscalationTimeline(),
        ],
        OnboardingPanel.permission => <Widget>[
          const _PanelTitle(OnboardingCopy.panel3Title),
          const SizedBox(height: MTSpacing.s5),
          const _PanelParagraph(OnboardingCopy.panel3BodyWhy),
          const SizedBox(height: MTSpacing.s3),
          // Same type, same ink as the line above. A consequence set smaller
          // and greyer than the pitch is a consequence being hidden, and
          // declining must not read as the lesser choice.
          const _PanelParagraph(OnboardingCopy.panel3BodyDecline),
        ],
      },
    );
  }
}

/// A panel title. `headingLg` unless overridden -- panels 2 and 3 are screen
/// titles; panel 1 is the lead.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text, {this.style = MTTypography.headingLg});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: style.copyWith(color: MTColors.inkPrimary)),
    );
  }
}

/// A paragraph of explanatory copy.
///
/// TOKENS. `MTTypography.body` on `MTColors.inkFaint`.
///
/// The ink is the mock's `#71718A`, which every onboarding body line uses. No
/// token is that value; the nearest is `inkFaint` `#6F6F8A`, one step off in
/// each channel, and it clears AA on the page at 4.55:1 -- `_contrastPairs`
/// already asserts that pair. An earlier version used `inkTertiary`, which
/// `colors.dart` documents as "metadata rows": darker than the design asks
/// for, and named for a different job. `inkTertiary` and `inkFaint` sit within
/// about 1% luminance of each other (DESIGN.md's "one honest consequence"), so
/// this is a naming correction more than a visual one -- but the name is the
/// part a later reader trusts.
///
/// The type size is a known gap, not a choice: the mock sets these at 17px on
/// panel 1 and 16px on panels 2 and 3, and the scale's `body` is 15px. Adding a
/// size is the UX owner's call, in the same class as the heading-scale
/// correction of 2026-09-06, so this takes the scale as it stands.
class _PanelParagraph extends StatelessWidget {
  const _PanelParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // No maxLines and no overflow: at the largest text size this must wrap to
    // as many lines as it needs, and the panel scrolls to accommodate it.
    return Text(
      text,
      style: MTTypography.body.copyWith(color: MTColors.inkFaint),
    );
  }
}

/// A panel's primary and secondary actions.
///
/// Stateful for one reason: the trip to Home is asynchronous -- the completion
/// flag is written before navigating -- and both controls stay on screen while
/// that write is in flight. Without a guard, a double tap, or a tap on the
/// primary followed by one on the secondary, issues two writes and two
/// navigations. The tests that asserted `writes == 1` passed anyway, because
/// they tapped once.
class _PanelActions extends ConsumerStatefulWidget {
  const _PanelActions({required this.panel});

  final OnboardingPanel panel;

  @override
  ConsumerState<_PanelActions> createState() => _PanelActionsState();
}

class _PanelActionsState extends ConsumerState<_PanelActions> {
  /// Whether a trip to Home is already under way.
  bool _leaving = false;

  /// Records completion and leaves for Home.
  ///
  /// The flag is written HERE, on the way to Home, and not once per panel: a
  /// launch interrupted on panel 2 shows the panels again, which costs a short
  /// explanation rather than the whole point of the screen.
  Future<void> _reachHome() async {
    // Checked as well as reflected in `onPressed`. Two taps inside one frame
    // both run this handler -- the widget has not rebuilt in between -- so the
    // disabled button alone would not stop the second one.
    if (_leaving) return;
    setState(() => _leaving = true);

    await ref.read(onboardingFlowProvider.notifier).markComplete();
    if (!mounted) return;
    context.go(MTRoutes.homePath);
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingFlow flow = ref.read(onboardingFlowProvider.notifier);
    final bool isLastPanel = widget.panel.isLast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          // On the last panel the primary reads "Allow notifications" and
          // advances to Home. It does not show the OS dialog -- Story 3.1
          // does, when notifications exist.
          onPressed: _leaving ? null : (isLastPanel ? _reachHome : flow.next),
          child: Text(
            isLastPanel
                ? OnboardingCopy.actionAllowNotifications
                : OnboardingCopy.actionContinue,
          ),
        ),
        const SizedBox(height: MTSpacing.s2),
        TextButton(
          // "Skip intro" on panels 1 and 2, "Not now" on panel 3. All three
          // reach the same Home with the flag persisted -- in this story the
          // two panel-3 actions are behaviourally identical, and the copy is
          // the only thing that distinguishes them.
          onPressed: _leaving ? null : _reachHome,
          child: Text(
            isLastPanel
                ? OnboardingCopy.actionNotNow
                : OnboardingCopy.actionSkipIntro,
          ),
        ),
      ],
    );
  }
}
