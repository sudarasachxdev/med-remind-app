// A MedicineRepository that exists to be bound, not called.
//
// The startup tests assert that the composition root BINDS a repository --
// dropping that override is invisible until a user taps Save, and then it
// throws in front of them. They assert nothing about what it stores.
//
// So every method throws, deliberately. A fake that returned empty lists would
// let a test pass while silently exercising a repository that answers for
// nobody, which is the failure mode this project keeps finding: a test that
// asserts on a plausible-looking nothing. If a future test needs real
// behaviour it should use `DriftMedicineRepository` over an in-memory database,
// as `medicine_repository_test.dart` already does.

import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';

/// A [MedicineRepository] whose every method throws [UnsupportedError].
final class UnusedMedicineRepository implements MedicineRepository {
  /// Creates the stand-in.
  const UnusedMedicineRepository();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedMedicineRepository.$method was called. This stand-in exists to be '
    'bound by a startup test, not to answer. Use DriftMedicineRepository over '
    'an in-memory database if the test needs real storage.',
  );

  @override
  Future<List<Medicine>> allMedicines() => _unused('allMedicines');

  @override
  Future<Medicine?> findMedicine(String id) => _unused('findMedicine');

  @override
  Future<Medicine> addMedicine({
    required String name,
    String? condition,
    required String form,
    required double dosageAmount,
    required String dosageUnit,
    String? instructions,
    required DateTime startDate,
    DateTime? endDate,
    bool active = true,
  }) => _unused('addMedicine');

  @override
  Future<void> saveMedicine(Medicine medicine) => _unused('saveMedicine');

  @override
  Future<void> deleteMedicine(String id) => _unused('deleteMedicine');

  @override
  Future<List<Schedule>> schedulesFor(String medicineId) =>
      _unused('schedulesFor');

  @override
  Future<Schedule> addSchedule({
    required String medicineId,
    required String timeOfDay,
    required String ianaTimezone,
    required Frequency frequency,
    Set<int>? daysOfWeek,
    int? intervalDays,
    required double dosageAmount,
    String? reminderOverride,
  }) => _unused('addSchedule');

  @override
  Future<void> saveSchedule(Schedule schedule) => _unused('saveSchedule');

  @override
  Future<void> deleteSchedule(String id) => _unused('deleteSchedule');
}
