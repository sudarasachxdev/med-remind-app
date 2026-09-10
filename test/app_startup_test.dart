// Everything `main()` does before the first frame.
//
// `flutter test` cannot call `main()`, so this covers the functions it is made
// of -- which is why they are functions. A review pass inverted one boolean in
// `main()`, turning "show the panels to first-time users" into "show them to
// returning users", and the whole suite stayed green. Nothing looked at the
// wiring. It does now.
//
// The other half is the matrix's sharpest row, "database unreadable":
// onboarding is shown, the failure surfaces rather than being swallowed, and
// "cannot read" is never treated as "completed".

// `show` rather than a bare import: drift also exports an `isNotNull`, which
// collides with matcher's.
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/onboarding_completed_at_startup_provider.dart';
import 'package:med_remind_app/app/onboarding_state_store_provider.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/dose_repository_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/app/startup.dart';
import 'package:med_remind_app/data/db/app_database.dart';

import 'support/fake_onboarding_state_store.dart';
import 'support/fixed_clock.dart';
import 'support/unused_dose_repository.dart';
import 'support/unused_medicine_repository.dart';
import 'support/recording_interceptor.dart';

void main() {
  group('readOnboardingCompletedAtStartup', () {
    test('reports a stored completion', () async {
      final store = FakeOnboardingStateStore(completed: true);

      expect(await readOnboardingCompletedAtStartup(store), isTrue);
      expect(store.reads, 1, reason: 'the flag is read once, before the frame');
    });

    test('reports a fresh install as not completed', () async {
      final store = FakeOnboardingStateStore();

      expect(await readOnboardingCompletedAtStartup(store), isFalse);
    });

    test(
      'a read failure resolves to "not completed", never "completed"',
      () async {
        final store = FakeOnboardingStateStore(
          readFailure: StateError('the store could not be opened'),
        );

        final List<FlutterErrorDetails> reported = _captureFlutterErrors();

        expect(
          await readOnboardingCompletedAtStartup(store),
          isFalse,
          reason:
              'A store that cannot answer must not be read as "already seen". '
              'Repeating a short explanation costs thirty seconds; skipping it '
              'costs the whole point of the screen.',
        );

        expect(reported, isNotEmpty, reason: 'the failure must surface');
      },
    );

    test(
      'the surfaced failure carries the original error and its stack',
      () async {
        final StateError failure = StateError('disk is on fire');
        final store = FakeOnboardingStateStore(readFailure: failure);

        final List<FlutterErrorDetails> reported = _captureFlutterErrors();

        await readOnboardingCompletedAtStartup(store);

        expect(reported, hasLength(1));
        expect(
          reported.single.exception,
          same(failure),
          reason: 'the real cause, not a re-worded one',
        );
        expect(reported.single.stack, isNotNull);
        expect(reported.single.library, startupLogName);
        // The message has to say which of the two answers this is NOT, because
        // "could not read the flag" and "the flag was false" produce the same
        // screen and only one of them is a problem.
        expect(
          reported.single.context.toString(),
          contains('NOT "already completed"'),
        );
      },
    );

    test('a successful read surfaces nothing', () async {
      final store = FakeOnboardingStateStore(completed: true);
      final List<FlutterErrorDetails> reported = _captureFlutterErrors();

      await readOnboardingCompletedAtStartup(store);

      expect(reported, isEmpty);
    });

    test('a store that never answers times out rather than hanging', () async {
      // The read happens before `runApp`, with the native splash on screen and
      // no Flutter frame to explain anything in. A locked database, or one
      // waiting on a lock a previous process still holds, would freeze there
      // for ever. The deadline turns an unbounded hang into the same safe
      // answer as any other failure.
      final store = FakeOnboardingStateStore(
        readDelay: const Duration(days: 1),
      );

      final List<FlutterErrorDetails> reported = _captureFlutterErrors();

      expect(
        await readOnboardingCompletedAtStartup(
          store,
          timeout: const Duration(milliseconds: 20),
        ),
        isFalse,
      );
      expect(
        reported,
        isNotEmpty,
        reason: 'a timeout is a failure and surfaces like one',
      );
      expect(reported.single.exception, isA<Exception>());
    });

    test('a read that answers inside the deadline is not timed out', () async {
      final store = FakeOnboardingStateStore(
        completed: true,
        readDelay: const Duration(milliseconds: 5),
      );

      expect(
        await readOnboardingCompletedAtStartup(
          store,
          timeout: const Duration(seconds: 5),
        ),
        isTrue,
      );
    });

    test('the shipped deadline is bounded and generous', () {
      // Named rather than inlined so it can be argued with. Reading one indexed
      // row is single-digit milliseconds; this is roughly two hundred times
      // that, and still short enough that nobody stares at an unexplained
      // splash for longer.
      expect(
        startupReadTimeout,
        greaterThan(const Duration(milliseconds: 500)),
      );
      expect(startupReadTimeout, lessThanOrEqualTo(const Duration(seconds: 5)));
    });
  });

  group('startupOverrides', () {
    // The composition root's whole output. Extracted from `main()` precisely so
    // these assertions can exist.

    test('binds the store the composition root was given', () {
      final store = FakeOnboardingStateStore();
      final container = ProviderContainer(
        overrides: startupOverrides(
          store: store,
          completed: false,
          medicineRepository: const UnusedMedicineRepository(),
          clock: FixedClock(),
          doseRepository: const UnusedDoseRepository(),
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(onboardingStateStoreProvider),
        same(store),
        reason:
            'Dropping this override is invisible until a user taps something, '
            'and then it throws in front of them.',
      );
    });

    test('carries the resolved flag through unchanged', () {
      final store = FakeOnboardingStateStore(completed: true);

      final completed = ProviderContainer(
        overrides: startupOverrides(
          store: store,
          completed: true,
          medicineRepository: const UnusedMedicineRepository(),
          clock: FixedClock(),
          doseRepository: const UnusedDoseRepository(),
        ),
      );
      addTearDown(completed.dispose);
      expect(
        completed.read(onboardingCompletedAtStartupProvider),
        isTrue,
        reason:
            'true means the panels have been seen, so the app opens on Home',
      );

      final fresh = ProviderContainer(
        overrides: startupOverrides(
          store: store,
          completed: false,
          medicineRepository: const UnusedMedicineRepository(),
          clock: FixedClock(),
          doseRepository: const UnusedDoseRepository(),
        ),
      );
      addTearDown(fresh.dispose);
      expect(
        fresh.read(onboardingCompletedAtStartupProvider),
        isFalse,
        reason:
            'Inverting this inverts the story: returning users would meet '
            'panel 1 and first-time users would never see the explainer.',
      );
    });

    test('binds all five providers and nothing else', () {
      // A count, and a deliberate pause. It said `hasLength(2)` and "binds
      // both providers" until Story 1.5 added the repository and the clock,
      // then `hasLength(4)` until Story 1.8 added the dose repository -- each
      // bump is the assertion that made the addition a decision rather than a
      // silent widening of the composition root. Bump it when you mean to.
      expect(
        startupOverrides(
          store: FakeOnboardingStateStore(),
          completed: false,
          medicineRepository: const UnusedMedicineRepository(),
          clock: FixedClock(),
          doseRepository: const UnusedDoseRepository(),
        ),
        hasLength(5),
      );
    });
  });

  group('the providers with no safe default', () {
    // Both providers' docs claim they throw "loudly" without an override, and
    // neither claim was checked until 2026-09-08 -- a mutation that gave
    // `clockProvider` a quiet default passed the whole suite. The existing
    // `onboardingStateStoreProvider` group below had this test from the start;
    // the two providers Story 1.5 added did not, which is how a documented
    // guarantee becomes a comment.
    //
    // The stakes differ per provider and the reasons are worth keeping apart:
    // a quiet repository default stores a medicine nowhere and tells the user
    // it saved (PRD §9's worst bug), a quiet clock default has to invent a
    // timezone, which AD-6 makes permanent and Dose resolution reads as truth,
    // and a quiet dose-repository default would have Home read an empty plan
    // forever with nothing on screen saying why.
    for (final ({String name, ProviderBase<Object?> provider}) target
        in <({String name, ProviderBase<Object?> provider})>[
          (
            name: 'medicineRepositoryProvider',
            provider: medicineRepositoryProvider,
          ),
          (name: 'clockProvider', provider: clockProvider),
          (name: 'doseRepositoryProvider', provider: doseRepositoryProvider),
        ]) {
      test('${target.name} throws until the composition root binds it', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container.read(target.provider),
          throwsA(isA<UnimplementedError>()),
          reason:
              '${target.name} returned a value with no override. A plausible '
              'default here is worse than a throw: it fails silently, at the '
              'moment the user is told their medicine was saved.',
        );
      });

      test('${target.name} says where to bind it', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container.read(target.provider),
          throwsA(
            isA<UnimplementedError>().having(
              (UnimplementedError e) => e.message,
              'message',
              allOf(contains('composition root'), contains('main.dart')),
            ),
          ),
        );
      });
    }
  });

  group('onboardingStateStoreProvider', () {
    test('throws until the composition root binds it', () {
      // The provider's own doc claims it "throws, loudly". Without this, a
      // future default that quietly constructed an AppDatabase() would pass
      // every test while opening a second connection to the same file -- the
      // exact AD-3 violation the doc cites as the reason for the throw.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(onboardingStateStoreProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('the throw says where to bind it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(onboardingStateStoreProvider),
        throwsA(
          isA<UnimplementedError>().having(
            (UnimplementedError e) => e.message,
            'message',
            allOf(contains('composition root'), contains('AD-3')),
          ),
        ),
      );
    });
  });

  group('onboardingCompletedAtStartupProvider', () {
    test('defaults to not completed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(onboardingCompletedAtStartupProvider),
        isFalse,
        reason: '"I could not tell" must never resolve to "already seen"',
      );
    });
  });

  group('closeDatabaseOnDetach', () {
    testWidgets('closes the database when the OS detaches the app', (
      tester,
    ) async {
      final interceptor = RecordingInterceptor();
      final database = AppDatabase(
        NativeDatabase.memory().interceptWith(interceptor),
      );
      // Force it open, so there is a connection for the detach to close.
      await database.customSelect('SELECT 1').get();
      expect(interceptor.closes, 0);

      final AppLifecycleListener listener = closeDatabaseOnDetach(database);
      addTearDown(listener.dispose);

      // The real sequence the engine sends on the way down. `hidden` is not
      // optional: AppLifecycleListener asserts the transition, so
      // inactive -> paused directly is rejected as an invalid state change.
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      // The close is issued without being awaited -- `detached` gives no
      // opportunity to await anything -- so let the microtask run.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(
        interceptor.closes,
        1,
        reason:
            'Nothing else releases the SQLite connection: routerProvider '
            'disposes its router, and this is the database equivalent.',
      );
    });

    testWidgets('an earlier lifecycle state does not close it', (tester) async {
      // Backgrounding is not teardown. AD-18's rolling backups are written on
      // background (Story 4.7), and they need the connection to still be open.
      final interceptor = RecordingInterceptor();
      final database = AppDatabase(
        NativeDatabase.memory().interceptWith(interceptor),
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();

      final AppLifecycleListener listener = closeDatabaseOnDetach(database);
      addTearDown(listener.dispose);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(interceptor.closes, 0);
    });

    test('the handler survives being called on a closed database', () async {
      final interceptor = RecordingInterceptor();
      final database = AppDatabase(
        NativeDatabase.memory().interceptWith(interceptor),
      );
      await database.customSelect('SELECT 1').get();

      final VoidCallback handler = databaseDetachHandler(database);
      handler();
      await Future<void>.delayed(Duration.zero);
      expect(interceptor.closes, 1);

      // Called again, which is what a duplicated lifecycle event looks like. It
      // must not throw into the engine's teardown, where nothing is listening
      // and an uncaught error is the last thing the process does.
      expect(handler, returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });
}

/// Redirects `FlutterError.onError` into a list for the duration of the test.
///
/// `FlutterError.reportError` is one of the two channels the startup read uses
/// to surface a failure, and the only one a test can observe -- `developer.log`
/// goes to the VM service. Capturing it is also what stops the reported error
/// from failing the test that deliberately caused it.
List<FlutterErrorDetails> _captureFlutterErrors() {
  final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}
