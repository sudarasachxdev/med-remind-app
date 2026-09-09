// The app's routes, and the one decision about what it opens onto.
//
// `go_router` with named routes, per the spine's conventions table. Three
// routes exist: onboarding, Home, and the add-medicine flow Story 1.5 added.
// All three are full-screen; the tab bar arrives with the other three tabs in
// Epic 4.
//
// ADD-MEDICINE IS A SIBLING OF HOME, not a route beneath it. Both of its exits
// -- Save and Cancel -- are a `go` to Home, and a nested route would leave the
// flow on the stack underneath: a back gesture on Home would return to a step 3
// whose medicine has already been written, offering Save again.
//
// ONE PLACE DECIDES THE FIRST SCREEN. [buildRouter] takes the persisted
// onboarding flag and turns it into an initial location, and nothing else in
// the app looks at that flag to choose a screen. The alternative -- a redirect
// that consults an in-flight read -- would have to render *something* while the
// read was outstanding, and the only honest something is one of the two answers
// it does not have yet. A returning user would see a frame of panel 1, which the
// story's matrix rules out ("Home directly, no onboarding frame"). So the flag
// is resolved before `runApp`, in `lib/main.dart`, and arrives here as a value.

import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/add_medicine/presentation/add_medicine_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

/// The `dart:developer` log source for routing. Local-only: NFR-6 forbids a
/// crash reporter.
const String routerLogName = 'meditracker.router';

/// The named routes of the app.
///
/// Names and paths together: `go_router`'s named navigation needs the name, and
/// `initialLocation` needs the path, so keeping the pair adjacent is what stops
/// the two from drifting apart.
abstract final class MTRoutes {
  /// The onboarding panels. Shown once, on first launch.
  static const String onboarding = 'onboarding';

  /// [onboarding]'s location.
  static const String onboardingPath = '/onboarding';

  /// Today's plan. The app's home, and every completed onboarding's
  /// destination.
  static const String home = 'home';

  /// [home]'s location.
  static const String homePath = '/';

  /// The three-step add-medicine flow (Story 1.5).
  ///
  /// A sibling of [home] rather than a child of it -- see the file comment.
  static const String addMedicine = 'addMedicine';

  /// [addMedicine]'s location.
  static const String addMedicinePath = '/add-medicine';
}

/// Builds the router, opening onto Home when [onboardingCompleted] and onto the
/// onboarding panels otherwise.
///
/// [onboardingCompleted] is `false` whenever the answer is not a confirmed yes —
/// including when the store could not be read. Showing the panels again to
/// someone who has seen them costs thirty seconds; hiding them from someone who
/// has not costs the whole point of the screen.
GoRouter buildRouter({required bool onboardingCompleted}) {
  final String initialLocation = onboardingCompleted
      ? MTRoutes.homePath
      : MTRoutes.onboardingPath;

  return GoRouter(
    initialLocation: initialLocation,
    // Without this, `initialLocation` is only a fallback: go_router prefers the
    // platform's default route whenever the platform supplies one that is not
    // `/`. A notification tap (Epic 3 routes against MTRoutes), a deep link, or
    // Android activity restoration all supply one -- and on any of those
    // launches the persisted flag would stop deciding the first screen, which
    // is the one decision this file exists to own.
    overridePlatformDefaultLocation: true,
    // An unmatched location lands on Home instead of go_router's default error
    // page, which renders raw exception text, unthemed, in a health app.
    //
    // `onException` rather than `errorBuilder` deliberately: `errorBuilder`
    // renders a replacement page while LEAVING the location at the unmatched
    // URI, so the app sits on a valid-looking screen whose address is still
    // wrong and the next relative navigation resolves against nonsense.
    // Redirecting repairs the location. Home is the recovery surface because it
    // is the app's root and always valid -- the spine asks for "a recoverable
    // surface rather than a blank screen", and inventing an error page here
    // would mean inventing copy the design has not written. The real
    // unreadable-records surface (MT-204) is Story 4.7's.
    onException: (BuildContext context, GoRouterState state, GoRouter router) {
      developer.log(
        'No route matched "${state.uri}". Recovering to Home.',
        name: routerLogName,
        level: 900,
      );
      router.go(MTRoutes.homePath);
    },
    // Onboarding is shown once. On a launch where the flag was already set,
    // any arrival at /onboarding -- a deep link, a restored activity, a stale
    // task-switcher entry -- is redirected to Home. This is possible now only
    // because the flag is a launch-time constant: an earlier design read it
    // asynchronously, and a redirect over an in-flight read would have had to
    // guess, which is what would have flashed panel 1 at a returning user.
    redirect: (BuildContext context, GoRouterState state) {
      if (onboardingCompleted &&
          state.matchedLocation == MTRoutes.onboardingPath) {
        return MTRoutes.homePath;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: MTRoutes.homePath,
        name: MTRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: MTRoutes.onboardingPath,
        name: MTRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: MTRoutes.addMedicinePath,
        name: MTRoutes.addMedicine,
        builder: (context, state) => const AddMedicineScreen(),
      ),
    ],
  );
}
