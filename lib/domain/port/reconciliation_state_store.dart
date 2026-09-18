// The port through which `Reconciler` learns, and records, the device's
// IANA zone as of its most recent run (AD-9, Story 3.5).
//
// AD-1: pure Dart. This file imports nothing -- not Drift, not Flutter --
// because the domain must not know that this fact lives in a SQLite row any
// more than `OnboardingStateStore` knows there is an onboarding screen.
// `lib/data/repository/drift_reconciliation_state_store.dart` is the adapter;
// `test/architecture_test.dart` fails the build if a `package:` import other
// than `package:meta/` appears anywhere under `lib/domain/`.
//
// Named for the role, not the technology (the spine's naming rule): a *store*
// of one fact, matching `OnboardingStateStore`'s own reasoning -- a single
// zone identifier is not an aggregate, so calling this a repository would
// claim a shape it does not have. A NEW port, not an extension of
// `OnboardingStateStore`: that port's own name and header comment ("a *store*
// of onboarding state... a single boolean is not an aggregate") make it the
// wrong home for an unrelated fact that happens to share a table --
// `app_settings` is a table with two independent settings on it, not one
// settings port with two methods.

/// The device's IANA zone identifier as of `Reconciler`'s most recent run,
/// and the means to record it.
///
/// `null` (see [lastKnownIanaTimezone]) is a genuinely different answer from
/// any real zone: it is what lets `Reconciler` tell "this is the first run
/// ever" apart from "the zone changed FROM something", which must not be
/// treated as a change to react to.
abstract interface class ReconciliationStateStore {
  /// The zone recorded by the most recent [saveLastKnownIanaTimezone], or
  /// `null` when nothing has been recorded yet.
  Future<String?> lastKnownIanaTimezone();

  /// Records [zone] as the device's current IANA zone.
  ///
  /// Idempotent: recording the same zone twice, or recording a zone on every
  /// `Reconciler.run()` regardless of whether it changed, is not an error --
  /// `Reconciler`'s own step 3 does exactly that, unconditionally.
  Future<void> saveLastKnownIanaTimezone(String zone);
}
