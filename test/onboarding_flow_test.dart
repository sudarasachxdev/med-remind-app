// The panel-state provider: what it holds, and what it refuses to hold.
//
// AD-13 -- a provider carries state, never a rule. Tested through a
// `ProviderContainer` with no widgets, because that is the whole of it: three
// panels, two moves, one write.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/onboarding_state_store_provider.dart';
import 'package:med_remind_app/features/onboarding/onboarding_panel.dart';
import 'package:med_remind_app/features/onboarding/providers/onboarding_flow_provider.dart';

import 'support/fake_onboarding_state_store.dart';

void main() {
  ({ProviderContainer container, FakeOnboardingStateStore store}) harness({
    Object? writeFailure,
  }) {
    final store = FakeOnboardingStateStore(writeFailure: writeFailure);
    final container = ProviderContainer(
      overrides: <Override>[
        onboardingStateStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, store: store);
  }

  group('OnboardingPanel', () {
    test('there are exactly three panels, in the designed order', () {
      expect(
        OnboardingPanel.values,
        equals(<OnboardingPanel>[
          OnboardingPanel.value,
          OnboardingPanel.escalation,
          OnboardingPanel.permission,
        ]),
        reason: 'value -> escalation explainer -> notification permission',
      );
      expect(OnboardingPanel.count, 3);
    });

    test('steps are 1-based, and only the ends are ends', () {
      expect(
        OnboardingPanel.values.map((OnboardingPanel p) => p.step),
        equals(<int>[1, 2, 3]),
      );
      expect(OnboardingPanel.value.isFirst, isTrue);
      expect(OnboardingPanel.value.isLast, isFalse);
      expect(OnboardingPanel.escalation.isFirst, isFalse);
      expect(OnboardingPanel.escalation.isLast, isFalse);
      expect(OnboardingPanel.permission.isLast, isTrue);
    });

    test('the ends have nothing beyond them', () {
      expect(OnboardingPanel.value.previous, isNull);
      expect(OnboardingPanel.permission.next, isNull);
      expect(OnboardingPanel.value.next, OnboardingPanel.escalation);
      expect(OnboardingPanel.permission.previous, OnboardingPanel.escalation);
    });
  });

  group('onboardingFlowProvider', () {
    test('starts on panel 1', () {
      final h = harness();

      expect(h.container.read(onboardingFlowProvider), OnboardingPanel.value);
    });

    test('advances one panel at a time', () {
      final h = harness();
      final OnboardingFlow flow = h.container.read(
        onboardingFlowProvider.notifier,
      );

      flow.next();
      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.escalation,
      );

      flow.next();
      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.permission,
      );
    });

    test('does not advance past the last panel', () {
      final h = harness();
      final OnboardingFlow flow = h.container.read(
        onboardingFlowProvider.notifier,
      );

      flow.next();
      flow.next();
      flow.next();

      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.permission,
      );
    });

    test('retreats one panel at a time', () {
      final h = harness();
      final OnboardingFlow flow = h.container.read(
        onboardingFlowProvider.notifier,
      );

      flow.next();
      flow.next();
      flow.back();
      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.escalation,
      );

      flow.back();
      expect(h.container.read(onboardingFlowProvider), OnboardingPanel.value);
    });

    test('back on panel 1 is inert', () {
      // The matrix's "Back from 1" row at the state layer: there is nothing
      // beneath panel 1, so the move must be a no-op rather than an
      // out-of-range index or an exit.
      final h = harness();
      final OnboardingFlow flow = h.container.read(
        onboardingFlowProvider.notifier,
      );

      flow.back();
      flow.back();

      expect(h.container.read(onboardingFlowProvider), OnboardingPanel.value);
    });

    test('moving between panels never writes the flag', () {
      // The flag is written when the user reaches HOME, not per panel. This is
      // what makes "app killed on panel 2" show the panels again.
      final h = harness();
      final OnboardingFlow flow = h.container.read(
        onboardingFlowProvider.notifier,
      );

      flow.next();
      flow.next();
      flow.back();

      expect(h.store.writes, 0);
      expect(h.store.completed, isFalse);
    });

    test('markComplete persists completion', () async {
      final h = harness();

      await h.container.read(onboardingFlowProvider.notifier).markComplete();

      expect(h.store.writes, 1);
      expect(h.store.completed, isTrue);
    });

    test('the panel does not outlive its last listener', () async {
      // autoDispose. Without it the notifier is kept alive by the root scope
      // for the whole session, and a second arrival at /onboarding -- which
      // buildRouter also guards -- would resume on whichever panel the first
      // visit left showing rather than start at panel 1.
      final h = harness();

      final ProviderSubscription<OnboardingPanel> subscription = h.container
          .listen<OnboardingPanel>(
            onboardingFlowProvider,
            (_, _) {},
            fireImmediately: true,
          );
      h.container.read(onboardingFlowProvider.notifier).next();
      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.escalation,
      );

      subscription.close();
      // Riverpod disposes an unlistened autoDispose provider on a scheduled
      // task, not synchronously, so the check has to come after one turn of
      // the event loop.
      await Future<void>.delayed(Duration.zero);

      expect(
        h.container.read(onboardingFlowProvider),
        OnboardingPanel.value,
        reason:
            'with nothing listening the notifier is disposed, so the next '
            'read rebuilds it at panel 1',
      );
    });

    test('a failed write does not throw at the call site', () async {
      // The caller navigates to Home immediately afterwards. A throw here
      // would strand the user on panel 3 over a boolean, trading a repeated
      // explanation for a dead end -- and the next launch showing the panels
      // again is a visible, recoverable outcome that needs no dialog.
      final h = harness(writeFailure: StateError('disk full'));

      await expectLater(
        h.container.read(onboardingFlowProvider.notifier).markComplete(),
        completes,
      );
      expect(h.store.writes, 1, reason: 'it was attempted');
      expect(h.store.completed, isFalse);
    });
  });
}
