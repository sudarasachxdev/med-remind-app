// The composition root.
//
// This is the one file permitted to know which adapter implements which port
// (the spine's dependency diagram marks exactly those edges as belonging here).
// It opens the single database this process owns (AD-3), binds the onboarding
// port to its Drift adapter, resolves the one value the first frame needs, and
// hands the rest to `lib/app/`.
//
// Every decision it makes is one call into `lib/app/startup.dart`, which is
// under test. Nothing that matters is expressed only here: `main()` cannot be
// called from `flutter test`, so logic written inline would be the one part of
// the app that no test can reach -- and a review pass proved the cost by
// inverting a boolean here and watching the whole suite stay green.
//
// The onboarding flag is resolved BEFORE `runApp` rather than inside a
// provider, because the router needs it synchronously: a returning user must
// land on Home with no onboarding frame in between, and a read still in flight
// would force the first frame to guess. One indexed row from a local SQLite
// file is the smallest possible amount of pre-frame work, it is work the first
// frame genuinely needs -- which is the line AD-21 draws -- and it is bounded
// by `startupReadTimeout` so a stalled store cannot hold the splash for ever.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app/router_provider.dart';
import 'app/startup.dart';
import 'app/theme.dart';
import 'data/db/app_database.dart';
import 'data/repository/drift_dose_repository.dart';
import 'data/repository/drift_medicine_repository.dart';
import 'data/repository/drift_onboarding_state_store.dart';
import 'data/repository/drift_reconciliation_state_store.dart';
import 'domain/port/clock.dart';
import 'domain/port/dose_notifier.dart';
import 'domain/port/dose_repository.dart';
import 'domain/port/medicine_repository.dart';
import 'domain/port/onboarding_state_store.dart';
import 'domain/port/permission_gateway.dart';
import 'domain/port/reconciliation_state_store.dart';
import 'features/home/application/home_plan_controller.dart';
import 'platform/notifications/flutter_local_notifications_dose_notifier.dart';
import 'platform/permissions/flutter_local_notifications_permission_gateway.dart';

Future<void> main() async {
  // Needed before any plugin channel is used, and `driftDatabase` reaches
  // path_provider to find the application documents directory.
  WidgetsFlutterBinding.ensureInitialized();

  // AD-3's one-process rule puts this in the composition root, and nowhere
  // else. Every `Dose` construction resolves its zone through
  // `tz.getLocation` (`Dose._asInstant`), which throws
  // `LocationNotFoundException` until this has run -- and a Dose can be
  // constructed as early as the first `HomePlanController.build()`, well
  // before `resolveClockAtStartup()` below returns. Independent of that read
  // (this is synchronous and touches no port), so the two are not sequenced
  // against one another -- only both must land before `runApp`.
  tzdata.initializeTimeZones();

  // One database per process (AD-3). Constructed here and nowhere else.
  final AppDatabase database = AppDatabase();
  final OnboardingStateStore store = DriftOnboardingStateStore(database);
  final MedicineRepository medicineRepository = DriftMedicineRepository(
    database,
  );
  final DoseRepository doseRepository = DriftDoseRepository(database);
  // Story 3.5: the same `app_settings` row `store` above reads its own column
  // on, through a second, targeted adapter -- see that adapter's own comment
  // for why this is a new port rather than a second method on
  // `OnboardingStateStore`.
  final ReconciliationStateStore reconciliationStateStore =
      DriftReconciliationStateStore(database);
  // AD-17's sole authority for notification/exact-alarm permission. Owns
  // nothing and opens nothing (unlike `database` above), so it is
  // constructed here with everything else rather than resolved asynchronously
  // alongside `clock`.
  const PermissionGateway permissionGateway =
      FlutterLocalNotificationsPermissionGateway();
  // AD-6/AD-7's real notification adapter (Story 3.2), reading exact-alarm
  // permission from `permissionGateway` on every schedule call (AD-14, Story
  // 3.3). Owns nothing and opens nothing, exactly like `permissionGateway`
  // above.
  final DoseNotifier doseNotifier = FlutterLocalNotificationsDoseNotifier(
    permissionGateway: permissionGateway,
  );

  // Closes the database when the OS tears the app down. The return value is
  // discarded on purpose: the listener registers itself with the
  // WidgetsBinding, which holds it for the life of the process. Only tests
  // need the handle, so they can dispose it.
  closeDatabaseOnDetach(database);

  // Both pre-frame reads, together. The onboarding flag is what the router
  // needs synchronously; the zone is what AD-6 forbids guessing. Awaited
  // concurrently because neither depends on the other and the splash is on
  // screen for the duration of the slower one, not the sum.
  final (bool onboardingCompleted, Clock clock) = await (
    readOnboardingCompletedAtStartup(store),
    resolveClockAtStartup(),
  ).wait;

  runApp(
    MediTrackerApp(
      overrides: startupOverrides(
        store: store,
        completed: onboardingCompleted,
        medicineRepository: medicineRepository,
        clock: clock,
        doseRepository: doseRepository,
        permissionGateway: permissionGateway,
        doseNotifier: doseNotifier,
        reconciliationStateStore: reconciliationStateStore,
      ),
    ),
  );
}

/// The root widget: the provider scope, the theme, and the router.
///
/// It owns the `ProviderScope` rather than being wrapped in one by `main()` so
/// that a test can pump the whole app -- including its routing -- with its own
/// bindings, in one expression. [overrides] is the seam: `main()` passes
/// `startupOverrides`, a test passes a fake, and with neither the app still
/// builds and shows onboarding, because
/// `onboardingCompletedAtStartupProvider` defaults to `false`.
class MediTrackerApp extends StatelessWidget {
  const MediTrackerApp({super.key, this.overrides = const <Override>[]});

  /// Provider bindings for this scope. See the class doc.
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _MediTrackerAppView(),
    );
  }
}

/// AD-9, Story 3.5: foreground is one of the three reconciliation triggers.
/// `ConsumerStatefulWidget` mixing in `WidgetsBindingObserver` is what lets
/// this widget hear `AppLifecycleState.resumed` at all -- a `ConsumerWidget`
/// has no lifecycle hook of its own, and `AppLifecycleListener` (the
/// callback-based alternative `startup.dart`'s `closeDatabaseOnDetach` uses
/// for `detached`) is a poorer fit here because this class already needs
/// `State` for `initState`/`dispose` to register and unregister the observer.
///
/// On resume, this invalidates `homePlanControllerProvider` rather than
/// calling `Reconciler.run()` itself -- AD-9's "nothing else in the codebase
/// re-registers notifications" is kept true by funnelling every trigger
/// through the one provider whose `build()` calls `Reconciler.run()`
/// (`home_plan_controller.dart`'s own file comment), rather than adding a
/// second call site here.
class _MediTrackerAppView extends ConsumerStatefulWidget {
  const _MediTrackerAppView();

  @override
  ConsumerState<_MediTrackerAppView> createState() =>
      _MediTrackerAppViewState();
}

class _MediTrackerAppViewState extends ConsumerState<_MediTrackerAppView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(homePlanControllerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MediTracker',
      // One theme. No `darkTheme`, no `themeMode`: UX-DR22 puts dark mode out
      // of scope for V1, and half of one is worse than none.
      theme: MTTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
