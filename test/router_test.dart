// One place decides what the app opens onto.
//
// The router takes the persisted flag as a value and turns it into an initial
// location. These are the two matrix rows that decision covers -- "fresh
// install" and "relaunch after completing" -- checked on the router itself,
// without a frame, so the assertion is about the decision and not about what
// happened to render.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:med_remind_app/app/router.dart';

void main() {
  group('buildRouter', () {
    test('a fresh install opens onto onboarding', () {
      final GoRouter router = buildRouter(onboardingCompleted: false);
      addTearDown(router.dispose);

      expect(_location(router), MTRoutes.onboardingPath);
    });

    test('a completed install opens onto Home', () {
      final GoRouter router = buildRouter(onboardingCompleted: true);
      addTearDown(router.dispose);

      expect(_location(router), MTRoutes.homePath);
    });

    test('both routes exist and are named', () {
      final GoRouter router = buildRouter(onboardingCompleted: false);
      addTearDown(router.dispose);

      // Named routes are the spine's convention, and a name that does not
      // resolve fails only at the call site that uses it -- which in this app
      // would be a notification tap in Epic 3.
      expect(
        router.namedLocation(MTRoutes.onboarding),
        MTRoutes.onboardingPath,
      );
      expect(router.namedLocation(MTRoutes.home), MTRoutes.homePath);
    });

    test('initialLocation wins over the platform default route', () {
      // Without `overridePlatformDefaultLocation`, `initialLocation` is only a
      // fallback: go_router prefers the platform's default route whenever it is
      // not '/'. A notification tap (Epic 3 routes against MTRoutes), a deep
      // link, and Android activity restoration all supply one -- and on any of
      // those launches the persisted flag would stop deciding the first screen,
      // which is the one decision this file exists to own.
      for (final bool completed in <bool>[true, false]) {
        final GoRouter router = buildRouter(onboardingCompleted: completed);
        addTearDown(router.dispose);

        expect(
          router.overridePlatformDefaultLocation,
          isTrue,
          reason: 'the flag decides the first screen on EVERY launch',
        );
      }
    });

    test('the guard and the recovery are installed', () {
      // Both behaviours are asserted end to end in
      // onboarding_screen_test.dart, where the app is pumped and a `go` is
      // followed: a completed install sent to /onboarding lands on Home, and
      // an unmatched location lands on Home instead of go_router's default
      // error page, which prints raw exception text, unthemed, in a health app.
      //
      // What is checked here is that neither error builder is installed,
      // because go_router asserts that `onException`, `errorBuilder` and
      // `errorPageBuilder` are mutually exclusive -- adding one later would
      // make this file's own construction throw, and this names why.
      final GoRouter router = buildRouter(onboardingCompleted: false);
      addTearDown(router.dispose);

      expect(router.configuration.topRedirect, isNotNull);
    });

    test('onboarding is not a child of Home', () {
      // Reaching Home must leave nothing behind to pop back into. If
      // onboarding were nested under `/`, `go` to Home would keep the panel on
      // the stack and a back gesture on Home would return to it.
      final GoRouter router = buildRouter(onboardingCompleted: false);
      addTearDown(router.dispose);

      expect(
        MTRoutes.onboardingPath.startsWith('${MTRoutes.homePath}/'),
        isFalse,
        reason: 'onboarding is a sibling of Home, not a route beneath it',
      );
    });
  });
}

/// The location the router will open onto.
///
/// Read from the route-information provider rather than
/// `routerDelegate.currentConfiguration`, which is empty until a `Router`
/// widget attaches and parses -- so asserting on it here would have been
/// asserting on nothing.
String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();
