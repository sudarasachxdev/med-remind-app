// A DoseRepository that exists to be bound, not called.
//
// Mirrors `unused_medicine_repository.dart`: the startup tests assert that the
// composition root BINDS a repository -- dropping that override is invisible
// until Home tries to read it, and then it throws in front of the user. They
// assert nothing about what it stores.
//
// So every method throws, deliberately. A fake that returned empty lists would
// let a test pass while silently exercising a repository that answers for
// nobody. If a future test needs real behaviour it should use
// `DriftDoseRepository` over an in-memory database, as `dose_repository_test.dart`
// already does.

import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';

/// A [DoseRepository] whose every method throws [UnsupportedError].
final class UnusedDoseRepository implements DoseRepository {
  /// Creates the stand-in.
  const UnusedDoseRepository();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedDoseRepository.$method was called. This stand-in exists to be '
    'bound by a startup test, not to answer. Use DriftDoseRepository over an '
    'in-memory database if the test needs real storage.',
  );

  @override
  Future<List<Dose>> dosesForSchedule(String scheduleId) =>
      _unused('dosesForSchedule');

  @override
  Future<void> saveDose(Dose dose) => _unused('saveDose');

  @override
  Future<Dose?> findDose(String id) => _unused('findDose');

  @override
  Future<void> deleteDose(String id) => _unused('deleteDose');

  @override
  Future<List<Dose>> dosesScheduledBetween(DateTime start, DateTime end) =>
      _unused('dosesScheduledBetween');
}
