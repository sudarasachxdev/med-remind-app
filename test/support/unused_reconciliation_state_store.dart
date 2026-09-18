// A ReconciliationStateStore that exists to be bound, not called.
//
// Mirrors `unused_dose_repository.dart`/`unused_medicine_repository.dart`/
// `unused_permission_gateway.dart`: the startup tests assert that the
// composition root BINDS a store -- dropping that override is invisible until
// `HomePlanController.build()` reaches `Reconciler.run()`, and then it throws
// in front of the user. They assert nothing about what it answers.
//
// So every method throws, deliberately. A fake that quietly answered "no
// prior zone" would let a test pass while silently exercising a store that
// backs no real settings row.

import 'package:med_remind_app/domain/port/reconciliation_state_store.dart';

/// A [ReconciliationStateStore] whose every method throws [UnsupportedError].
final class UnusedReconciliationStateStore implements ReconciliationStateStore {
  /// Creates the stand-in.
  const UnusedReconciliationStateStore();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedReconciliationStateStore.$method was called. This stand-in exists '
    'to be bound by a startup test, not to answer. Use '
    'DriftReconciliationStateStore over an in-memory database if the test '
    'needs real storage.',
  );

  @override
  Future<String?> lastKnownIanaTimezone() => _unused('lastKnownIanaTimezone');

  @override
  Future<void> saveLastKnownIanaTimezone(String zone) =>
      _unused('saveLastKnownIanaTimezone');
}
