// A scriptable `OnboardingStateStore` for tests that must not touch SQLite.
//
// Not a mock framework: three fields and two counters cover every row of the
// story's matrix, including the two failure rows, and a hand-written fake is
// readable in the test that uses it.

import 'package:med_remind_app/domain/port/onboarding_state_store.dart';

/// An in-memory [OnboardingStateStore] that can also be told to fail.
final class FakeOnboardingStateStore implements OnboardingStateStore {
  FakeOnboardingStateStore({
    this.completed = false,
    this.readFailure,
    this.writeFailure,
    this.readDelay,
    this.writeDelay,
  });

  /// Whether the flag is set. Mutable so a test can read it back after a write
  /// without going through [isOnboardingComplete], which would count a read.
  bool completed;

  /// Thrown by [isOnboardingComplete] when set. Models a store that cannot be
  /// opened or read.
  final Object? readFailure;

  /// Thrown by [markOnboardingComplete] when set.
  final Object? writeFailure;

  /// How long [isOnboardingComplete] takes to answer. Models a slow or locked
  /// store; a very long delay models one that never answers at all.
  final Duration? readDelay;

  /// How long [markOnboardingComplete] takes. A delay here holds the trip to
  /// Home open, which is the window a second tap would land in.
  final Duration? writeDelay;

  /// How many times the flag was read.
  int reads = 0;

  /// How many times completion was written.
  int writes = 0;

  @override
  Future<bool> isOnboardingComplete() async {
    reads++;
    final Duration? delay = readDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final Object? failure = readFailure;
    if (failure != null) throw failure;
    return completed;
  }

  @override
  Future<void> markOnboardingComplete() async {
    writes++;
    final Duration? delay = writeDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final Object? failure = writeFailure;
    if (failure != null) throw failure;
    completed = true;
  }
}
