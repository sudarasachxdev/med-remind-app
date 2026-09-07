// The accessibility floor, checked on the real panels.
//
// EXPERIENCE.md's floor for this screen is three things: every panel's
// explanation is reachable and readable by a screen reader, actions are
// individually labelled controls, and Dynamic Type is honoured by reflowing
// vertically rather than truncating -- with every action still at least
// 44pt/48dp.
//
// The Dynamic Type half is the one that is easy to claim and hard to hold. It
// is checked at the largest accessibility scale, on all three panels, by
// pumping and then reading back the exceptions: a `RenderFlex` overflow or a
// clipped paragraph reports through `FlutterError`, so a truncating layout
// fails here rather than being noticed on someone's phone.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/onboarding_completed_at_startup_provider.dart';
import 'package:med_remind_app/app/onboarding_state_store_provider.dart';
import 'package:med_remind_app/features/onboarding/onboarding_panel.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_copy.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:med_remind_app/main.dart';

import 'support/fake_onboarding_state_store.dart';

/// The design's reference device frame: 402 x 874 logical pixels (iOS).
const Size _referenceFrame = Size(402, 874);

/// iOS's largest accessibility text size, as a scale factor. Bigger than any
/// setting a user can actually choose, which is the point: the layout should
/// have no cliff just past the real maximum either.
const double _largestTextScale = 3;

/// The prose of each panel -- what a screen reader has to be able to reach.
List<String> _copyOf(OnboardingPanel panel) => switch (panel) {
  OnboardingPanel.value => <String>[
    OnboardingCopy.panel1Title,
    OnboardingCopy.panel1BodyWhatItIs,
    OnboardingCopy.panel1BodyPrivacy,
  ],
  OnboardingPanel.escalation => <String>[
    OnboardingCopy.panel2Title,
    OnboardingCopy.panel2Body,
  ],
  OnboardingPanel.permission => <String>[
    OnboardingCopy.panel3Title,
    OnboardingCopy.panel3BodyWhy,
    OnboardingCopy.panel3BodyDecline,
  ],
};

/// The button carrying [label].
///
/// `find.byType(ButtonStyleButton)` does not work: `byType` matches the exact
/// runtime type, and the buttons are `FilledButton` and `TextButton`. The
/// predicate matches the shared supertype, which is what makes one assertion
/// cover both actions.
Finder _actionButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
);

/// The primary and secondary action labels of each panel.
(String, String) _actionsOf(OnboardingPanel panel) => panel.isLast
    ? (OnboardingCopy.actionAllowNotifications, OnboardingCopy.actionNotNow)
    : (OnboardingCopy.actionContinue, OnboardingCopy.actionSkipIntro);

void main() {
  group('Dynamic Type at the largest accessibility size', () {
    for (final OnboardingPanel panel in OnboardingPanel.values) {
      testWidgets('panel ${panel.step} renders without truncating', (
        tester,
      ) async {
        await _pumpPanel(tester, panel, textScale: _largestTextScale);

        expect(
          tester.takeException(),
          isNull,
          reason:
              'An overflow or a clip at this size is a truncation. The panel '
              'must reflow vertically instead, which is what the scroll view '
              'around the copy and the actions is for.',
        );

        // Every string is still in the tree -- nothing was dropped to make
        // room -- and every one can be scrolled to.
        for (final String copy in _copyOf(panel)) {
          expect(find.text(copy), findsOneWidget, reason: copy);
          await tester.ensureVisible(find.text(copy));
        }
      });

      testWidgets('panel ${panel.step} keeps its actions above the floor', (
        tester,
      ) async {
        await _pumpPanel(tester, panel, textScale: _largestTextScale);

        final (String primary, String secondary) = _actionsOf(panel);
        for (final String label in <String>[primary, secondary]) {
          await tester.ensureVisible(find.text(label));
          final Size size = tester.getSize(_actionButton(label));
          expect(
            size.height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason:
                '"$label" is ${size.height}pt high; the floor is 44pt/48dp '
                'and it applies at every text size, not just the default',
          );
        }
      });

      testWidgets('panel ${panel.step} keeps its actions above the floor at '
          'the default size too', (tester) async {
        await _pumpPanel(tester, panel);

        final (String primary, String secondary) = _actionsOf(panel);
        for (final String label in <String>[primary, secondary]) {
          final Size size = tester.getSize(_actionButton(label));
          expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
          expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        }
      });
    }

    for (final OnboardingPanel panel in OnboardingPanel.values) {
      testWidgets('panel ${panel.step} survives a short viewport at the '
          'largest size', (tester) async {
        // The failure this catches: an earlier layout pinned the back control
        // and the step bar above an `Expanded` scroll view. That reflows the
        // copy, but once the pinned header is taller than the viewport -- a
        // short screen at the largest accessibility text size, where the back
        // button alone is over 50 logical pixels of type -- the `Expanded` is
        // handed a negative height and the Column overflows. An overflow is a
        // truncation, which is what UX-DR20 forbids.
        //
        // 402 x 420 is not a phone; it is the smallest viewport the layout has
        // to survive, and it stands in for a small handset in landscape and for
        // a keyboard-inset portrait screen.
        await _pumpPanel(
          tester,
          panel,
          textScale: _largestTextScale,
          viewport: const Size(402, 420),
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'the whole panel scrolls -- back control and step bar included '
              '-- so nothing is pinned above a starved Expanded',
        );

        // And it is genuinely all still reachable, not merely unexceptional.
        final (String primary, String secondary) = _actionsOf(panel);
        for (final String label in <String>[
          _copyOf(panel).first,
          primary,
          secondary,
        ]) {
          await tester.ensureVisible(find.text(label));
          expect(find.text(label), findsOneWidget, reason: label);
        }
      });
    }

    testWidgets('the actions sit at the bottom when the copy is short', (
      tester,
    ) async {
      // The other half of the scroll change. On a tall screen the actions must
      // still be pushed to the bottom edge, as the mock draws them, rather than
      // floating up under the copy -- which is what a plain scroll view without
      // the minHeight/IntrinsicHeight pairing would have done.
      await _pumpPanel(
        tester,
        OnboardingPanel.value,
        viewport: const Size(402, 874),
      );

      final double screenBottom = tester.getSize(find.byType(Scaffold)).height;
      final double actionBottom = tester
          .getRect(_actionButton(OnboardingCopy.actionSkipIntro))
          .bottom;

      expect(
        actionBottom,
        greaterThan(screenBottom * 0.7),
        reason:
            'the actions belong on the bottom edge, not directly beneath the '
            'copy: found $actionBottom of $screenBottom',
      );
    });

    testWidgets('no copy on any panel is capped or ellipsised', (tester) async {
      // The structural half of the same rule. A `maxLines` or an
      // `TextOverflow.ellipsis` would make the overflow check above pass by
      // truncating instead of reflowing -- which is exactly the failure it is
      // meant to catch, so the absence is asserted directly.
      for (final OnboardingPanel panel in OnboardingPanel.values) {
        await _pumpPanel(tester, panel);

        final Iterable<Text> texts = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(OnboardingScreen),
            matching: find.byType(Text),
          ),
        );
        expect(texts, isNotEmpty);
        for (final Text text in texts) {
          expect(
            text.maxLines,
            isNull,
            reason: 'panel ${panel.step}: "${text.data}" caps its lines',
          );
          expect(
            text.overflow,
            anyOf(isNull, TextOverflow.visible),
            reason: 'panel ${panel.step}: "${text.data}" can be clipped',
          );
        }
      }
    });
  });

  group('screen reader', () {
    testWidgets('every panel title is announced as a heading', (tester) async {
      await _withSemantics(tester, () async {
        for (final OnboardingPanel panel in OnboardingPanel.values) {
          await _pumpPanel(tester, panel);

          final String title = _copyOf(panel).first;
          final SemanticsNode node = tester.getSemantics(find.text(title));
          expect(node.label, title);
          expect(
            node.flagsCollection.isHeader,
            isTrue,
            reason: 'panel ${panel.step}: the title should be a heading',
          );
        }
      });
    });

    testWidgets('every panel explanation is reachable and readable', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        for (final OnboardingPanel panel in OnboardingPanel.values) {
          await _pumpPanel(tester, panel);

          for (final String copy in _copyOf(panel)) {
            expect(
              find.bySemanticsLabel(copy),
              findsOneWidget,
              reason:
                  'panel ${panel.step}: "$copy" is not in the semantics tree',
            );
          }
        }
      });
    });

    testWidgets('the actions are separate, individually labelled controls', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        for (final OnboardingPanel panel in OnboardingPanel.values) {
          await _pumpPanel(tester, panel);

          final (String primary, String secondary) = _actionsOf(panel);
          for (final String label in <String>[primary, secondary]) {
            final SemanticsNode node = tester.getSemantics(
              _actionButton(label),
            );
            expect(node.label, label);
            expect(node.flagsCollection.isButton, isTrue);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
          }

          expect(
            primary,
            isNot(secondary),
            reason: 'two controls with one label are one control to a reader',
          );
        }
      });
    });

    testWidgets('the step bar says which step this is', (tester) async {
      await _withSemantics(tester, () async {
        for (final OnboardingPanel panel in OnboardingPanel.values) {
          await _pumpPanel(tester, panel);

          expect(
            find.bySemanticsLabel(
              OnboardingCopy.stepLabel(panel.step, OnboardingPanel.count),
            ),
            findsOneWidget,
            reason:
                'three flat segments say nothing out loud; the label is the '
                'only thing that tells a reader where they are',
          );
        }
      });
    });

    testWidgets('each timeline row is announced as one sentence', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        await _pumpPanel(tester, OnboardingPanel.escalation);

        for (final EscalationStep step in EscalationStep.values) {
          expect(
            find.bySemanticsLabel(step.semanticsLabel),
            findsOneWidget,
            reason:
                'a time, a phrase and an unlabelled dot as three nodes read '
                'as fragments: "${step.semanticsLabel}"',
          );
        }
      });
    });

    testWidgets('the timeline dots are not announced on their own', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        await _pumpPanel(tester, OnboardingPanel.escalation);

        // The row's own words are inside its merged label, so the individual
        // Text nodes must not also be announced -- otherwise "12:40" is read
        // twice.
        expect(find.bySemanticsLabel(EscalationStep.taken.time), findsNothing);
        expect(find.bySemanticsLabel(EscalationStep.taken.label), findsNothing);
      });
    });
  });
}

/// Runs [body] with the semantics tree built.
///
/// The handle is disposed inside the test body, not in a tear-down:
/// `flutter_test` checks for leaked `SemanticsHandle`s *before* tear-downs run,
/// so `addTearDown(handle.dispose)` fails every test that uses it.
Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// Pumps the app, advances to [panel], and settles.
Future<void> _pumpPanel(
  WidgetTester tester,
  OnboardingPanel panel, {
  double? textScale,
  Size viewport = _referenceFrame,
}) async {
  tester.view.physicalSize = viewport * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  // A fresh element tree each time. Re-pumping `MediTrackerApp` over an
  // existing one reuses its element, and with it the `ProviderScope`'s
  // container -- so a loop over the three panels would inherit whichever panel
  // the previous iteration left showing.
  await tester.pumpWidget(const SizedBox.shrink());

  await tester.pumpWidget(
    MediTrackerApp(
      overrides: <Override>[
        onboardingStateStoreProvider.overrideWithValue(
          FakeOnboardingStateStore(),
        ),
        onboardingCompletedAtStartupProvider.overrideWithValue(false),
      ],
    ),
  );

  // The panels are provider state, so getting to panel 3 means tapping
  // Continue twice -- the same path a user takes.
  for (int step = 1; step < panel.step; step++) {
    await tester.ensureVisible(find.text(OnboardingCopy.actionContinue));
    await tester.tap(find.text(OnboardingCopy.actionContinue));
    await tester.pumpAndSettle();
  }
}
