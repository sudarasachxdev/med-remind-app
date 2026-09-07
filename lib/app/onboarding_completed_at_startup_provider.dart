// Whether onboarding had already been completed when the app launched.
//
// A plain value, resolved once before the first frame and never re-read. It is
// not a `FutureProvider`: the router needs the answer synchronously to pick an
// initial location, and a provider that is still loading would force the first
// frame to guess.
//
// The value is deliberately NOT updated when the user finishes onboarding. It
// describes the launch, not the present, and the navigation to Home is what
// moves the user -- so nothing here needs to change and nothing rebuilds the
// router underneath a live screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the persisted onboarding flag was set at launch.
///
/// Defaults to `false`, which is the safe answer in every uncertain case: a
/// fresh install, a store that could not be read, and a widget test that has
/// not overridden it all show the panels. "I could not tell" must never resolve
/// to "already seen".
final Provider<bool> onboardingCompletedAtStartupProvider = Provider<bool>(
  (ref) => false,
);
