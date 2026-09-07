// The port through which the app learns whether onboarding has been seen.
//
// AD-1: pure Dart. This file imports nothing — not Drift, not Flutter — because
// the domain must not know that the flag lives in a SQLite row any more than it
// knows there is a screen. `lib/data/repository/drift_onboarding_state_store.dart`
// is the adapter; `test/architecture_test.dart` fails the build if a `package:`
// import other than `package:meta/` appears anywhere under `lib/domain/`.
//
// Named for the role, not the technology (the spine's naming rule): a *store*
// of onboarding state. `MedicineRepository` is a repository because it owns an
// aggregate (AD-12); a single boolean is not an aggregate, so calling this one
// a repository would claim a shape it does not have.

/// Whether the user has finished the onboarding panels, and the means to record
/// that they have.
///
/// The flag is written when the user **reaches Home** — after the last panel, or
/// after skipping — not once per panel. A launch interrupted on panel 2
/// therefore shows onboarding again, which is the kinder failure: repeating a
/// short explanation costs nothing, while skipping it silently costs the whole
/// point of the screen.
abstract interface class OnboardingStateStore {
  /// Whether onboarding has been completed.
  ///
  /// Implementations return `false` only when the store was read and genuinely
  /// holds no completion. A store that **cannot** be read must throw: "I could
  /// not tell" and "the user has already seen it" are different answers, and
  /// collapsing them into `true` would hide onboarding from a first-time user
  /// on the one launch that matters.
  Future<bool> isOnboardingComplete();

  /// Records that onboarding has been completed.
  ///
  /// Idempotent: calling it when the flag is already set is not an error, so a
  /// second completion (a relaunch that raced the write, a re-entry from a
  /// future Settings surface) needs no guard at the call site.
  Future<void> markOnboardingComplete();
}
