// The onboarding surface, row by row against the story's I/O matrix.
//
// Pumped as the whole app -- `MediTrackerApp`, its `ProviderScope`, its theme
// and its router -- rather than as a bare `OnboardingScreen`, because half of
// what the matrix asks about is navigation: whether Home is reached, whether a
// relaunch shows a panel at all, whether a back gesture pops the route. None of
// that is observable from a widget pumped on its own.
//
// The `overrides` seam is how a store gets in. `main()` binds the Drift
// adapter; here a `FakeOnboardingStateStore` records reads and writes and can
// be told to fail.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/onboarding_completed_at_startup_provider.dart';
import 'package:med_remind_app/app/onboarding_state_store_provider.dart';
import 'package:med_remind_app/app/router.dart';
import 'package:med_remind_app/app/startup.dart';
import 'package:med_remind_app/features/home/presentation/home_screen.dart';
import 'package:med_remind_app/features/onboarding/presentation/escalation_timeline.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_copy.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_step_bar.dart';
import 'package:med_remind_app/main.dart';
import 'package:go_router/go_router.dart';
import 'package:med_remind_app/shared/design/design.dart';

import 'support/fake_onboarding_state_store.dart';
import 'support/fixed_clock.dart';
import 'support/unused_medicine_repository.dart';

/// The design's reference device frame: 402 x 874 logical pixels (iOS).
const Size _referenceFrame = Size(402, 874);

void main() {
  group('fresh install', () {
    testWidgets('opens on panel 1 with one segment filled', (tester) async {
      await _pumpApp(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(find.text(OnboardingCopy.panel1BodyPrivacy), findsOneWidget);
      expect(_filledSegments(tester), 1);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('offers no Back, because nothing sits behind panel 1', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text(OnboardingCopy.actionBack), findsNothing);
    });

    testWidgets('offers Continue and Skip intro', (tester) async {
      await _pumpApp(tester);

      expect(
        find.widgetWithText(FilledButton, OnboardingCopy.actionContinue),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, OnboardingCopy.actionSkipIntro),
        findsOneWidget,
      );
    });
  });

  group('advancing', () {
    testWidgets('Continue from panel 1 reaches panel 2, two segments', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _tap(tester, OnboardingCopy.actionContinue);

      expect(find.text(OnboardingCopy.panel2Title), findsOneWidget);
      expect(find.byType(EscalationTimeline), findsOneWidget);
      expect(_filledSegments(tester), 2);
    });

    testWidgets('Continue from panel 2 reaches panel 3, three segments', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      expect(find.text(OnboardingCopy.panel3Title), findsOneWidget);
      expect(_filledSegments(tester), 3);
    });

    testWidgets('panel 2 draws the whole escalation timeline', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);

      for (final EscalationStep step in EscalationStep.values) {
        expect(find.text(step.head), findsOneWidget, reason: step.head);
        expect(find.text(step.note), findsOneWidget, reason: step.note);
      }
      expect(
        find.text('Taken at 12:40'),
        findsOneWidget,
        reason:
            'the outcome row is one emphasised phrase, as the mock draws it -- '
            'not a muted "Taken" beside a time, which reads as a fifth '
            'pending step',
      );
      expect(
        find.text(EscalationStep.taken.note),
        findsOneWidget,
        reason: 'the last line is the one the Design Notes insist on keeping',
      );
    });

    testWidgets('panel 3 names its actions and shows no OS dialog', (
      tester,
    ) async {
      final List<String> platformCalls = _watchPermissionChannels(tester);

      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      expect(find.text(OnboardingCopy.panel3Title), findsOneWidget);
      expect(find.text(OnboardingCopy.panel3BodyDecline), findsOneWidget);
      expect(
        find.widgetWithText(
          FilledButton,
          OnboardingCopy.actionAllowNotifications,
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, OnboardingCopy.actionNotNow),
        findsOneWidget,
      );

      await _tap(tester, OnboardingCopy.actionAllowNotifications);

      expect(
        platformCalls,
        isEmpty,
        reason:
            'Panel 3 explains; it does not ask. Story 3.1 triggers the real '
            'dialog, when there are notifications to permit. Calls seen: '
            '$platformCalls',
      );
    });
  });

  group('retreating', () {
    testWidgets('Back from panel 2 returns to panel 1 and the bar retreats', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      expect(_filledSegments(tester), 2);

      await _tap(tester, OnboardingCopy.actionBack);

      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(_filledSegments(tester), 1);
    });

    testWidgets('Back from panel 3 returns to panel 2', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      await _tap(tester, OnboardingCopy.actionBack);

      expect(find.text(OnboardingCopy.panel2Title), findsOneWidget);
      expect(_filledSegments(tester), 2);
    });

    testWidgets('a system back gesture on panel 2 retreats a panel', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);

      await _systemBack(tester);

      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(_filledSegments(tester), 1);
    });

    testWidgets(
      'a system back gesture on panel 1 does nothing and does not exit',
      (tester) async {
        await _pumpApp(tester);

        await _systemBack(tester);

        // Still panel 1, still onboarding, still one segment: the gesture was
        // swallowed rather than popping the only route on the stack.
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
        expect(_filledSegments(tester), 1);
        expect(
          tester
              .widget<PopScope<Object?>>(find.byType(PopScope<Object?>))
              .canPop,
          isFalse,
          reason: 'the route must never pop -- there is nothing beneath it',
        );
      },
    );
  });

  group('reaching Home', () {
    testWidgets('Allow notifications reaches Home with the flag persisted', (
      tester,
    ) async {
      final FakeOnboardingStateStore store = await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      await _tap(tester, OnboardingCopy.actionAllowNotifications);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(store.writes, 1);
      expect(store.completed, isTrue);
    });

    testWidgets('Not now reaches Home with the flag persisted', (tester) async {
      final FakeOnboardingStateStore store = await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      await _tap(tester, OnboardingCopy.actionNotNow);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        store.completed,
        isTrue,
        reason: 'declining is not a lesser path: it ends in the same place',
      );
    });

    testWidgets(
      'Skip intro from panel 1 reaches Home with the flag persisted',
      (tester) async {
        final FakeOnboardingStateStore store = await _pumpApp(tester);

        await _tap(tester, OnboardingCopy.actionSkipIntro);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(store.completed, isTrue);
      },
    );

    testWidgets(
      'Skip intro from panel 2 reaches Home with the flag persisted',
      (tester) async {
        final FakeOnboardingStateStore store = await _pumpApp(tester);
        await _tap(tester, OnboardingCopy.actionContinue);

        await _tap(tester, OnboardingCopy.actionSkipIntro);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(store.completed, isTrue);
      },
    );

    testWidgets('Home leaves nothing behind to go back into', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionSkipIntro);

      await _systemBack(tester);
      await tester.pumpAndSettle();

      expect(
        find.byType(OnboardingScreen),
        findsNothing,
        reason: 'onboarding is replaced, not stacked under Home',
      );
    });
  });

  group('relaunching', () {
    testWidgets('after completing, Home appears with no onboarding frame', (
      tester,
    ) async {
      await _pumpApp(tester, completed: true);

      // Asserted after the FIRST frame, deliberately. The flag is resolved
      // before `runApp`, so there is no loading state in which a panel could
      // flash -- which is what "Home directly, no onboarding frame" means.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text(OnboardingCopy.panel1Title), findsNothing);
    });

    testWidgets('killed on panel 2, the next launch starts at panel 1', (
      tester,
    ) async {
      final FakeOnboardingStateStore store = await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      expect(find.text(OnboardingCopy.panel2Title), findsOneWidget);
      expect(
        store.writes,
        0,
        reason: 'nothing is written until the user reaches Home',
      );

      // A relaunch: the tree is torn down first, then a new app is built over
      // the same store, whose flag is still unset. The teardown is the point.
      // Re-pumping `MediTrackerApp` on its own would reuse the element, and
      // with it the `ProviderScope`'s container -- so the flow would still be
      // on panel 2 and the test would be asserting nothing about a relaunch.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpApp(tester, store: store);

      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(
        _filledSegments(tester),
        1,
        reason: 'partial progress is not resumed, which is the kinder failure',
      );
    });

    testWidgets('a store that cannot be read still shows onboarding', (
      tester,
    ) async {
      // Driven through the REAL launch path. An earlier version of this test
      // handed the app a failing store and a hardcoded `completed: false`,
      // which meant the failure was never triggered at all -- a reviewer probed
      // it with `expect(store.reads, 0)` and it passed. It asserted that
      // `false` shows onboarding, which the fresh-install test already covers.
      //
      // Now the flag comes from `readOnboardingCompletedAtStartup`, exactly as
      // `main()` produces it, so the read really happens, really throws, and
      // the app is launched with whatever that resolves to.
      final store = FakeOnboardingStateStore(
        readFailure: StateError('the store could not be opened'),
      );

      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final bool completed = await readOnboardingCompletedAtStartup(store);

      expect(store.reads, 1, reason: 'the launch really read the store');
      expect(reported, isNotEmpty, reason: 'and the failure really surfaced');

      await tester.pumpWidget(
        MediTrackerApp(
          overrides: startupOverrides(
            store: store,
            completed: completed,
            medicineRepository: const UnusedMedicineRepository(),
            clock: FixedClock(),
          ),
        ),
      );

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(
        find.byType(HomeScreen),
        findsNothing,
        reason: 'a read error is never treated as "already completed"',
      );
    });

    testWidgets('a store that cannot be read is not written to either', (
      tester,
    ) async {
      // The panels are shown, so nothing has been completed yet, so nothing
      // should have been persisted. A launch that "recovered" by writing the
      // flag would hide onboarding from the same user next time.
      final store = FakeOnboardingStateStore(
        readFailure: StateError('the store could not be opened'),
      );
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previous);

      final bool completed = await readOnboardingCompletedAtStartup(store);
      await tester.pumpWidget(
        MediTrackerApp(
          overrides: startupOverrides(
            store: store,
            completed: completed,
            medicineRepository: const UnusedMedicineRepository(),
            clock: FixedClock(),
          ),
        ),
      );

      expect(store.writes, 0);
    });
  });

  group('the escalation timeline previews real state colours', () {
    // The whole stated reason those four tokens were chosen over the mock's
    // undeclared hexes is that each dot previews a state the user will meet
    // later in the app. A review pass collapsed all four to `inkMuted` and the
    // suite stayed green, which meant the reason was recorded in a comment and
    // nowhere else.
    testWidgets('each dot is the state colour it stands for', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);

      expect(
        _timelineDotColors(tester),
        equals(<Color>[
          // 8:00 Reminder -- mock #6C5CE7, the interaction accent itself.
          MTColors.accent,
          // 8:15 Gentle follow-up -- mock #A99CF0, a lighter violet.
          MTColors.accentBorder,
          // 9:00 Marked overdue -- mock #E3A34C. The app's real overdue amber,
          // never red: UX-DR21 reserves red for Delete medicine alone.
          MTColors.stateLateGlyph,
          // Taken at 12:40 -- mock #16A34A, the recorded-dose green.
          MTColors.stateTakenGlyph,
        ]),
      );
    });

    testWidgets('no dot is red, and none is a neutral grey', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);

      final Set<Color> forbidden = <Color>{
        MTColors.stateDangerInk,
        MTColors.stateDangerSurface,
        MTColors.inkMuted,
        MTColors.inkTertiary,
        MTColors.borderHairline,
      };
      for (final Color color in _timelineDotColors(tester)) {
        expect(
          forbidden.contains(color),
          isFalse,
          reason:
              'a grey dot previews nothing and a red one contradicts UX-DR21',
        );
      }
    });

    testWidgets('the four dots are four different colours', (tester) async {
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);

      final List<Color> colors = _timelineDotColors(tester);
      expect(colors, hasLength(4));
      expect(colors.toSet(), hasLength(4));
    });
  });

  group('the step bar', () {
    testWidgets('unreached segments are the hairline, not the accent wash', (
      tester,
    ) async {
      // The mock's `onb2`/`onb3` resolve to #EDECF5 when the step is not yet
      // reached, and #EDECF5 is exactly `borderHairline`. An earlier version
      // used `accentWash` by analogy with the Record card's day-bars, which
      // was a guess the mock disagrees with.
      await _pumpApp(tester);

      expect(
        _segmentColors(tester),
        equals(<Color>[
          MTColors.accent,
          MTColors.borderHairline,
          MTColors.borderHairline,
        ]),
      );

      await _tap(tester, OnboardingCopy.actionContinue);
      expect(
        _segmentColors(tester),
        equals(<Color>[
          MTColors.accent,
          MTColors.accent,
          MTColors.borderHairline,
        ]),
      );

      await _tap(tester, OnboardingCopy.actionContinue);
      expect(
        _segmentColors(tester),
        equals(<Color>[MTColors.accent, MTColors.accent, MTColors.accent]),
      );
    });
  });

  group('reaching Home is not repeatable', () {
    testWidgets('a double tap writes once and navigates once', (tester) async {
      // `_reachHome` awaits the flag write with both controls still on screen.
      // Without a guard, two taps issue two writes and two navigations -- and
      // the tests that assert `writes == 1` passed anyway, because they tapped
      // once.
      final FakeOnboardingStateStore store = await _pumpApp(tester);

      // Both taps inside one frame: the widget has not rebuilt in between, so
      // the disabled button alone would not stop the second one.
      await tester.tap(find.text(OnboardingCopy.actionSkipIntro));
      await tester.tap(
        find.text(OnboardingCopy.actionSkipIntro),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        store.writes,
        1,
        reason: 'one trip to Home is one completion, however many taps',
      );
    });

    testWidgets('tapping the other action mid-flight does nothing', (
      tester,
    ) async {
      final FakeOnboardingStateStore store = await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);

      await tester.tap(find.text(OnboardingCopy.actionAllowNotifications));
      await tester.tap(
        find.text(OnboardingCopy.actionNotNow),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.writes, 1);
    });

    testWidgets('both actions are disabled once one is taken', (tester) async {
      final FakeOnboardingStateStore store = FakeOnboardingStateStore(
        writeDelay: const Duration(milliseconds: 100),
      );
      await _pumpApp(tester, store: store);

      await tester.tap(find.text(OnboardingCopy.actionSkipIntro));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, OnboardingCopy.actionContinue),
            )
            .onPressed,
        isNull,
        reason: 'Continue must not advance a panel that is on its way out',
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, OnboardingCopy.actionSkipIntro),
            )
            .onPressed,
        isNull,
      );

      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('routing recovers rather than showing an exception', () {
    testWidgets('an unmatched location lands on Home', (tester) async {
      await _pumpApp(tester);

      final GoRouter router = GoRouter.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      router.go('/there-is-no-such-screen');
      await tester.pumpAndSettle();

      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason:
            "go_router's default error page prints raw exception text, "
            'unthemed, in a health app',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a completed install cannot be sent back to onboarding', (
      tester,
    ) async {
      // Onboarding is shown once. A deep link, a restored activity or a stale
      // task-switcher entry pointing at /onboarding belongs on Home.
      await _pumpApp(tester, completed: true);
      expect(find.byType(HomeScreen), findsOneWidget);

      final GoRouter router = GoRouter.of(
        tester.element(find.byType(HomeScreen)),
      );
      router.go(MTRoutes.onboardingPath);
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a fresh install can still reach onboarding by location', (
      tester,
    ) async {
      // The guard keys on the launch-time flag, not on "onboarding was shown
      // in this session". Within a first launch the route stays reachable.
      await _pumpApp(tester);

      final GoRouter router = GoRouter.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      router.go(MTRoutes.onboardingPath);
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('re-entering onboarding starts at panel 1, not where it left', (
      tester,
    ) async {
      // `onboardingFlowProvider` is autoDispose, so the panel does not outlive
      // the screen. Kept alive, a second arrival would resume on panel 3.
      await _pumpApp(tester);
      await _tap(tester, OnboardingCopy.actionContinue);
      await _tap(tester, OnboardingCopy.actionContinue);
      expect(find.text(OnboardingCopy.panel3Title), findsOneWidget);

      final GoRouter router = GoRouter.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      router.go(MTRoutes.homePath);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.go(MTRoutes.onboardingPath);
      await tester.pumpAndSettle();

      expect(find.text(OnboardingCopy.panel1Title), findsOneWidget);
      expect(_filledSegments(tester), 1);
    });
  });

  group('the theme is wired from the tokens', () {
    testWidgets('the page is the design surface, not Material grey', (
      tester,
    ) async {
      await _pumpApp(tester);

      final ThemeData theme = Theme.of(
        tester.element(find.byType(OnboardingScreen)),
      );

      expect(theme.scaffoldBackgroundColor, MTColors.surfaceApp);
      expect(theme.colorScheme.primary, MTColors.accent);
      expect(
        theme.brightness,
        Brightness.light,
        reason: 'light palette only -- UX-DR22',
      );
    });

    testWidgets('the primary action is the accent pill, in white ink', (
      tester,
    ) async {
      // A review pass swapped the primary action to a `surfaceInset` fill with
      // `inkPrimary` ink -- a grey chip where the design has an accent pill --
      // and the suite stayed green. The `_contrastPairs` row added alongside is
      // arithmetic over two constants; it never builds a widget. So the style
      // is resolved out of the real tree, the way _filledSegments reads a real
      // BoxDecoration.
      await _pumpApp(tester);
      final ThemeData theme = Theme.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      final ButtonStyle style = theme.filledButtonTheme.style!;

      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        MTColors.accent,
        reason: 'accent is the only colour that carries interaction meaning',
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        MTColors.surfaceRaised,
        reason:
            'white on accent, the pairing _contrastPairs measures at 4.86:1',
      );
      expect(
        style.backgroundColor!.resolve(<WidgetState>{WidgetState.pressed}),
        MTColors.accentPressed,
      );
      expect(
        style.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
        MTColors.surfaceInset,
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
        MTColors.inkDisabled,
        reason:
            'WCAG exempts inactive controls, and an unavailable action should '
            'look unavailable',
      );
    });

    testWidgets('the secondary action is accent ink, not a second fill', (
      tester,
    ) async {
      // Declining must never read as the lesser choice, so the secondary keeps
      // the accent and the tap area; only the fill differs, because two filled
      // actions of equal weight leave the user without a default.
      await _pumpApp(tester);
      final ThemeData theme = Theme.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      final ButtonStyle style = theme.textButtonTheme.style!;

      expect(style.foregroundColor!.resolve(<WidgetState>{}), MTColors.accent);
      expect(
        style.foregroundColor!.resolve(<WidgetState>{WidgetState.pressed}),
        MTColors.accentPressed,
      );
      expect(
        style.backgroundColor?.resolve(<WidgetState>{}),
        anyOf(isNull, MTColors.surfaceApp),
        reason: 'no fill: one filled action per panel',
      );
    });

    testWidgets('the actions really render in those colours', (tester) async {
      // The theme is what the widgets are asked to use; this is what they end
      // up painted with, which is the claim that matters.
      await _pumpApp(tester);

      final Material primary = tester.widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(
                FilledButton,
                OnboardingCopy.actionContinue,
              ),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(primary.color, MTColors.accent);

      final Text label = tester.widget<Text>(
        find.text(OnboardingCopy.actionContinue),
      );
      expect(
        DefaultTextStyle.of(
              tester.element(find.text(OnboardingCopy.actionContinue)),
            ).style.color ??
            label.style?.color,
        MTColors.surfaceRaised,
      );
    });

    testWidgets('the product type scale reaches the Material text theme', (
      tester,
    ) async {
      // Deleting `textTheme: _textTheme` passed the whole suite. Every framework
      // widget would then fall back to Material's own type -- and every future
      // screen that reads a text-theme slot would silently get it.
      await _pumpApp(tester);
      final TextTheme text = Theme.of(
        tester.element(find.byType(OnboardingScreen)),
      ).textTheme;

      expect(text.displaySmall?.fontSize, MTTypography.headingXl.fontSize);
      expect(text.headlineLarge?.fontSize, MTTypography.headingLg.fontSize);
      expect(text.bodyMedium?.fontSize, MTTypography.body.fontSize);
      expect(text.bodySmall?.fontSize, MTTypography.meta.fontSize);
      expect(text.labelSmall?.fontSize, MTTypography.chip.fontSize);
      expect(
        text.headlineLarge?.fontWeight,
        FontWeight.w700,
        reason: 'every heading in the design is weight 700, not 600',
      );
      expect(
        text.bodyMedium?.color,
        MTColors.inkPrimary,
        reason: 'a token style carries no colour; the theme applies the ink',
      );
      // Platform-native faces only. The assertion is on the TOKEN, not on the
      // resolved theme: `ThemeData` fills in the platform's own family (Roboto
      // under `flutter test`, SF Pro on iOS) from its `typography`, which is
      // exactly the behaviour wanted. What must stay absent is a family pinned
      // by the design layer, which would override the platform everywhere.
      expect(MTTypography.body.fontFamily, isNull);
      expect(MTTypography.headingLg.fontFamily, isNull);
    });

    testWidgets('the page is the design surface at the widget, not just in the '
        'theme', (tester) async {
      await _pumpApp(tester);

      final Material surface = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surface.color, MTColors.surfaceApp);
    });

    testWidgets('there is one theme and no dark counterpart', (tester) async {
      await _pumpApp(tester);

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );

      expect(app.darkTheme, isNull);
      expect(
        app.themeMode,
        ThemeMode.system,
        reason:
            'the default, untouched: nothing offers a toggle and nothing '
            'branches on brightness',
      );
    });
  });
}

/// Pumps the whole app with a fake store bound in.
Future<FakeOnboardingStateStore> _pumpApp(
  WidgetTester tester, {
  bool completed = false,
  FakeOnboardingStateStore? store,
}) async {
  // Every test here is about a phone in portrait, which is the only shape V1
  // targets. The default 800x600 test surface is neither, and a layout that
  // only fits on a tablet-shaped canvas would pass while being wrong.
  tester.view.physicalSize = _referenceFrame * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final FakeOnboardingStateStore effective =
      store ?? FakeOnboardingStateStore(completed: completed);

  await tester.pumpWidget(
    MediTrackerApp(
      overrides: <Override>[
        onboardingStateStoreProvider.overrideWithValue(effective),
        onboardingCompletedAtStartupProvider.overrideWithValue(completed),
      ],
    ),
  );
  return effective;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Delivers the platform's back gesture, the way Android's system back arrives.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// The fill colour of each step-bar segment, in order.
List<Color> _segmentColors(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(OnboardingStepBar),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((DecoratedBox box) => (box.decoration as BoxDecoration).color!)
      .toList();
}

/// The fill colour of each timeline dot, in row order.
///
/// The dots are the circular `Container`s; the connector between them is a
/// `DecoratedBox`, so keying on `BoxShape.circle` separates the two without
/// depending on their order in the tree.
List<Color> _timelineDotColors(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(EscalationTimeline),
          matching: find.byType(Container),
        ),
      )
      .map((Container container) => container.decoration)
      .whereType<BoxDecoration>()
      .where((BoxDecoration d) => d.shape == BoxShape.circle)
      .map((BoxDecoration d) => d.color!)
      .toList();
}

/// How many step-bar segments are filled with the accent.
int _filledSegments(WidgetTester tester) {
  final Iterable<DecoratedBox> segments = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(OnboardingStepBar),
      matching: find.byType(DecoratedBox),
    ),
  );
  return segments
      .where(
        (DecoratedBox box) =>
            (box.decoration as BoxDecoration).color == MTColors.accent,
      )
      .length;
}

/// Records any call on the notification or permission platform channels.
///
/// This is how "no OS permission dialog appears" is checked rather than
/// asserted in prose. Both channels are mocked so that a call would be
/// observed here instead of failing as a missing plugin -- a missing-plugin
/// exception would also fail the test, but for the wrong reason, and would stop
/// telling us anything the day the plugin is registered in Epic 3.
List<String> _watchPermissionChannels(WidgetTester tester) {
  const List<String> channels = <String>[
    // flutter_local_notifications -- AD-17's sole authority for permission.
    'dexterous.com/flutter/local_notifications',
    // permission_handler -- forbidden as a dependency, watched anyway.
    'flutter.baseflow.com/permissions/methods',
  ];
  final List<String> calls = <String>[];

  for (final String channel in channels) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (MethodCall call) async {
        calls.add('$channel#${call.method}');
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        null,
      ),
    );
  }
  return calls;
}
