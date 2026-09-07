// Which onboarding panel is showing, and the write that ends the flow.
//
// AD-13 -- a provider carries state, never a rule. The state here is one
// [OnboardingPanel]; the ordering of the panels belongs to the enum, and the
// storage of the completion flag belongs to the port. What is left is the two
// things a caller actually asks for: move, and finish.
//
// Hand-written, per the amended AD-13: `riverpod_generator` has no resolvable
// version in this project and must not be re-added. One provider per file,
// named `<subject>Provider`, built from `NotifierProvider`.
//
// The panel is NOT a route. Three routes would put the OS back gesture in
// charge of a sequence that has to swallow it on panel 1 -- the matrix's "Back
// from 1 ... must not exit the app" -- and would let a deep link open panel 3
// alone. One route holding one value is what makes both of those impossible.

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/onboarding_state_store_provider.dart';
import '../../../domain/port/onboarding_state_store.dart';
import '../onboarding_panel.dart';

/// The `dart:developer` log source for this feature. Logging is local-only:
/// NFR-6 forbids a crash reporter, so there is nowhere else for it to go.
const String onboardingLogName = 'meditracker.onboarding';

/// The onboarding flow: the visible panel, and the completion write.
///
/// `autoDispose`, so the panel does not outlive the screen. Without it the
/// notifier is kept alive by the root scope for the whole session, and a second
/// arrival at `/onboarding` -- which `buildRouter` now also guards -- would
/// resume on whichever panel the first visit left showing rather than start at
/// panel 1. It also matches what the flag records: the flow is a one-time
/// sequence, not a piece of app-wide state.
final AutoDisposeNotifierProvider<OnboardingFlow, OnboardingPanel>
onboardingFlowProvider =
    AutoDisposeNotifierProvider<OnboardingFlow, OnboardingPanel>(
      OnboardingFlow.new,
    );

/// Holds the visible [OnboardingPanel].
class OnboardingFlow extends AutoDisposeNotifier<OnboardingPanel> {
  @override
  OnboardingPanel build() => OnboardingPanel.value;

  /// Advances one panel. Does nothing on the last one, where the actions reach
  /// Home instead.
  void next() {
    final OnboardingPanel? panel = state.next;
    if (panel != null) state = panel;
  }

  /// Retreats one panel.
  ///
  /// Does nothing on the first, which is the whole of the matrix's "Back from
  /// 1" row: there is no route beneath onboarding to pop to, so back on panel 1
  /// must be inert rather than an exit.
  void back() {
    final OnboardingPanel? panel = state.previous;
    if (panel != null) state = panel;
  }

  /// Records that onboarding is complete, so it is not shown again.
  ///
  /// Called once, when the user reaches Home -- from the last panel's actions
  /// or from `Skip intro` -- never per panel. A launch interrupted mid-flow
  /// therefore starts at panel 1 next time, which is the kinder failure of the
  /// two available.
  ///
  /// Awaited by the caller so the write has been attempted before navigation,
  /// but a failure is not rethrown. The user has finished onboarding either
  /// way, and stranding them on panel 3 because a boolean would not persist
  /// trades a repeated explanation for a dead end.
  ///
  /// The failure is logged rather than surfaced on screen. It is the one
  /// failure in this flow that announces itself: the next launch shows the
  /// panels again, which is visible, recoverable, and already the documented
  /// behaviour of an interrupted flow. Compare the launch-time *read*, where
  /// the same silence would instead hide onboarding from a first-time user --
  /// which is why that path reports through the framework as well
  /// (`lib/app/startup.dart`).
  Future<void> markComplete() async {
    final OnboardingStateStore store = ref.read(onboardingStateStoreProvider);
    try {
      await store.markOnboardingComplete();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not persist the onboarding flag. Continuing to Home; the '
        'panels will be shown again on the next launch.',
        name: onboardingLogName,
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}
