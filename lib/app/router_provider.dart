// The router, as a provider, so the root widget has one thing to watch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_completed_at_startup_provider.dart';
import 'router.dart';

/// The app's single [GoRouter].
///
/// Built once: its only input is [onboardingCompletedAtStartupProvider], which
/// is a launch-time constant, so this never rebuilds and the router never loses
/// its navigation stack under a live screen.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(
    onboardingCompleted: ref.watch(onboardingCompletedAtStartupProvider),
  );
  ref.onDispose(router.dispose);
  return router;
});
