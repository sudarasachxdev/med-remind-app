// Everything `main()` does before the first frame, in one testable place.
//
// `main()` itself cannot be called from `flutter test`, so anything written
// inline there is the one part of the app that nothing exercises. That matters
// here more than anywhere else: this file decides which screen a launch opens
// onto, and it guards the story's sharpest edge -- a store that cannot be read
// must never be mistaken for a store that says "already completed".
//
// So `main()` is reduced to three calls into this file, and the file is under
// test. A review pass demonstrated why: inverting one boolean in `main()` --
// showing panel 1 to returning users and skipping the escalation explainer for
// first-time ones -- passed the entire suite, because nothing looked at the
// wiring.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../domain/port/clock.dart';
import '../domain/port/dose_repository.dart';
import '../domain/port/medicine_repository.dart';
import '../domain/port/onboarding_state_store.dart';
import '../platform/clock/system_clock.dart';
import 'clock_provider.dart';
import 'dose_repository_provider.dart';
import 'medicine_repository_provider.dart';
import 'onboarding_completed_at_startup_provider.dart';
import 'onboarding_state_store_provider.dart';

/// The `dart:developer` log source for startup. Logging is local-only (NFR-6
/// forbids a crash reporter), so this name is how a developer finds it.
const String startupLogName = 'meditracker.startup';

/// How long the pre-frame read of the onboarding flag may take.
///
/// The read is awaited before `runApp`, which means it happens with the native
/// splash on screen and no Flutter frame to show anything in. Without a
/// deadline, a database that is locked, on a stalled filesystem, or waiting on
/// a lock held by a previous process would hang there indefinitely, and the
/// user would see a frozen splash with nothing the app could say about it.
///
/// Two seconds is a hang-breaker, not a performance target. Reading one indexed
/// row from a local SQLite file is a single-digit-millisecond operation, so this
/// is roughly two hundred times the expected cost -- generous enough that a
/// cold, slow, encrypted-filesystem first open on a mid-tier Android device
/// will not trip it, and short enough that nobody stares at an unexplained
/// splash for longer than that. Tripping it costs a returning user one repeated
/// explanation, which this story already names as the acceptable failure.
const Duration startupReadTimeout = Duration(seconds: 2);

/// Reads the persisted onboarding flag for the composition root.
///
/// Returns `true` only when [store] answered `true` within
/// [startupReadTimeout]. A failure -- a throw or a timeout -- resolves to
/// `false`, so the panels are shown, and is **surfaced twice**, because neither
/// channel alone is enough:
///
/// * `developer.log` is the spine's local-only record. It is what a developer
///   attached to the running app sees, and it is the only channel that survives
///   into a release build.
/// * `FlutterError.reportError` puts the failure on the framework's error
///   channel, where a debug build shows it and a test can observe it. Without
///   it, "the failure surfaces" would be a claim no test could check.
///
/// What it never does is rethrow. There is nowhere to throw to: `main()` has no
/// frame yet, and an app that refuses to launch because it could not read a
/// boolean is worse than an app that explains itself one extra time.
Future<bool> readOnboardingCompletedAtStartup(
  OnboardingStateStore store, {
  Duration timeout = startupReadTimeout,
}) async {
  try {
    return await store.isOnboardingComplete().timeout(timeout);
  } on Object catch (error, stackTrace) {
    const String message =
        'Could not read the onboarding flag. Showing onboarding. This is NOT '
        '"already completed" -- the store did not answer.';
    developer.log(
      message,
      name: startupLogName,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: startupLogName,
        context: ErrorDescription(message),
      ),
    );
    return false;
  }
}

/// Resolves the device's IANA zone for the composition root.
///
/// Returns a [SystemClock] over the resolved zone, or an [UnresolvedZoneClock]
/// when the platform cannot name it. The fallback still answers `now()`, so the
/// app launches and Home renders; it throws only on `ianaTimezone`, which is
/// exactly the read that would otherwise persist a wrong zone.
///
/// The failure is surfaced on both channels, for the reasons
/// [readOnboardingCompletedAtStartup] gives. What it never does is rethrow:
/// refusing to launch over a zone the user may not need today is worse than
/// launching without it.
///
/// AD-6 is why there is no third option. A placeholder zone would let the save
/// button work and store something false -- and unlike a missed onboarding
/// panel, that error is permanent and is read back as truth by Dose
/// resolution.
Future<Clock> resolveClockAtStartup({
  Duration timeout = startupReadTimeout,
}) async {
  try {
    return await SystemClock.resolve().timeout(timeout);
  } on Object catch (error, stackTrace) {
    final ClockZoneUnavailable cause = error is ClockZoneUnavailable
        ? error
        : ClockZoneUnavailable('$error');
    const String message =
        'Could not resolve the device timezone. The app will run, but saving a '
        'Schedule will fail rather than store a zone we had to guess (AD-6).';
    developer.log(
      message,
      name: startupLogName,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: startupLogName,
        context: ErrorDescription(message),
      ),
    );
    return UnresolvedZoneClock(cause);
  }
}

/// The provider bindings the app is launched with.
///
/// This is the composition root's whole output, extracted from `main()` so it
/// can be fed fakes and read back out of a `ProviderContainer`. Every override
/// is required in production and every one is easy to get silently wrong --
/// dropping the store binding is invisible until a user taps something, and
/// inverting [completed] inverts the story -- so none is written at a call site
/// that no test can reach.
///
/// The parameters are NAMED, and were positional until Story 1.5 took the count
/// from two to four. Four positional arguments, two of them interchangeable
/// object types, is how a binding ends up swapped: the compiler cannot tell a
/// store from a repository at the call site, and a test that swapped them would
/// still read plausibly. Named arguments make the swap unwriteable.
///
/// [doseRepository] is Story 1.8's own addition, the fifth binding. Unlike
/// [medicineRepository] and [clock], it has no derived sibling bound alongside
/// it here: `doseGeneratorProvider` composes [medicineRepository] and
/// [doseRepository] itself once both are bound, the same way `routerProvider`
/// composes `onboardingCompletedAtStartupProvider` rather than being listed
/// here.
List<Override> startupOverrides({
  required OnboardingStateStore store,
  required bool completed,
  required MedicineRepository medicineRepository,
  required Clock clock,
  required DoseRepository doseRepository,
}) {
  return <Override>[
    onboardingStateStoreProvider.overrideWithValue(store),
    onboardingCompletedAtStartupProvider.overrideWithValue(completed),
    medicineRepositoryProvider.overrideWithValue(medicineRepository),
    clockProvider.overrideWithValue(clock),
    doseRepositoryProvider.overrideWithValue(doseRepository),
  ];
}

/// Closes [database] when the OS detaches the app.
///
/// The listener registers itself with the `WidgetsBinding` in its own
/// constructor, and the binding holds observers strongly -- so it survives for
/// the life of the process without anyone storing it. It is still *returned*,
/// for the tests, which need something to dispose so a listener does not leak
/// from one test into the next.
///
/// `detached` is the last state a Flutter app sees before the engine is torn
/// down. Closing there releases the SQLite connection and its write-ahead log
/// deliberately instead of leaving the OS to reclaim them, which is what makes
/// the next open a clean one rather than a recovery.
AppLifecycleListener closeDatabaseOnDetach(AppDatabase database) {
  return AppLifecycleListener(onDetach: databaseDetachHandler(database));
}

/// The callback [closeDatabaseOnDetach] installs.
///
/// Separate from the listener because `AppLifecycleListener.onDetach` cannot be
/// invoked from a test, and an uncalled teardown is the same as no teardown.
VoidCallback databaseDetachHandler(AppDatabase database) {
  return () {
    developer.log('Detaching: closing the database.', name: startupLogName);
    // Unawaited on purpose. `detached` gives no opportunity to await anything;
    // the close is issued and the process goes away.
    unawaited(
      database.close().onError<Object>((Object error, StackTrace stackTrace) {
        developer.log(
          'The database did not close cleanly on detach.',
          name: startupLogName,
          error: error,
          stackTrace: stackTrace,
          level: 1000,
        );
      }),
    );
  };
}
