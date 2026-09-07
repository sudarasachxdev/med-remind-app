// The binding between the onboarding-state port and whatever implements it.
//
// Declared with no implementation on purpose. `lib/main.dart` overrides it with
// the Drift adapter over the single `AppDatabase` this process opens (AD-3);
// widget tests override it with a fake. A default that quietly constructed a
// real database would open a second connection from inside a test the moment
// something read this provider, which is the failure AD-3 exists to prevent.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/onboarding_state_store.dart';

/// The [OnboardingStateStore] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read rather than silently returning a
/// store that answers for nobody.
final Provider<OnboardingStateStore> onboardingStateStoreProvider =
    Provider<OnboardingStateStore>((ref) {
      throw UnimplementedError(
        'onboardingStateStoreProvider must be overridden at the composition '
        'root. lib/main.dart binds it to DriftOnboardingStateStore over the '
        'one AppDatabase this process opens (AD-3).',
      );
    });
