// Smoke test for the root widget, and the guard on its safe default.
//
// It pumps `MediTrackerApp` with NO overrides, which is the case worth keeping:
// the widget owns its own `ProviderScope`, and with nothing bound the app must
// still build AND show onboarding, because
// `onboardingCompletedAtStartupProvider` defaults to `false`.
//
// That default is the story's safety property in one line -- "I could not tell"
// resolves to "show the panels", never to "already seen" -- and three separate
// doc comments assert it in prose. Nothing enforced it: a review pass changed
// the default to `true` and the whole suite stayed green, because the only
// assertion here was `find.byType(Scaffold)` and `HomeScreen` is a `Scaffold`
// too. Both branches satisfied it. The screens are named now.
//
// Amended by Story 1.3. This header previously argued that `ProviderScope`
// belonged to a later story; that story is this one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/features/home/presentation/home_screen.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:med_remind_app/main.dart';

void main() {
  testWidgets('MediTrackerApp builds and renders without error', (
    tester,
  ) async {
    await tester.pumpWidget(const MediTrackerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing bound, it opens onto onboarding, not Home', (
    tester,
  ) async {
    await tester.pumpWidget(const MediTrackerApp());

    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason:
          'onboardingCompletedAtStartupProvider defaults to false, so an '
          'unbound app shows the panels',
    );
    expect(
      find.byType(HomeScreen),
      findsNothing,
      reason:
          'A default of true would hide the escalation explainer from every '
          'first-time user -- the one thing this story exists to show them.',
    );
  });
}
