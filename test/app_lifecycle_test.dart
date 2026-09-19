// AD-9, Story 3.5: foreground is one of the three reconciliation triggers.
// `_MediTrackerAppView` (`lib/main.dart`) is a `ConsumerStatefulWidget` mixing
// in `WidgetsBindingObserver` precisely so it can hear
// `AppLifecycleState.resumed` and invalidate `homePlanControllerProvider` --
// this file proves that wiring, driven through the real `MediTrackerApp`
// rather than a bare `WidgetsBindingObserver` in isolation.
//
// The exact `flutter_test` API for dispatching a lifecycle state change,
// confirmed against the installed Flutter SDK (3.44.8) and already used by
// `app_startup_test.dart`'s own `closeDatabaseOnDetach` group:
// `tester.binding.handleAppLifecycleStateChanged(state)`. It notifies every
// `WidgetsBindingObserver` directly, with no transition-validity assertion of
// its own (that check lives in `AppLifecycleListener`, a different mechanism
// this widget does not use), so a single `resumed` call with no preceding
// sequence is a faithful, minimal way to drive it.
//
// The signal counted below is `MedicineRepository.allMedicines()` calls, not
// `Clock.now()`: `home_screen.dart` also reads `clockProvider` directly (for
// its own greeting), so a clock-call count is not a clean proxy for "how many
// times did HomePlanController.build() run". `medicineRepositoryProvider` is
// read only from within `HomePlanController.build()`'s own pipeline (the
// controller's own read, plus `Reconciler.run()`'s `generate()` and
// re-registration steps) -- three calls per build with no Medicines saved --
// so a jump from three to six is unambiguously a second, real `build()`.
//
// Testing depth is LIGHTER (project-context.md): one row proving `resumed`
// invalidates the provider, one proving another lifecycle state does not.
// Whether `Reconciler.run()` itself behaves correctly is
// `reconciler_test.dart`'s own concern -- this file only proves the trigger
// reaches the one provider AD-9 names.

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/startup.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/data/repository/drift_reconciliation_state_store.dart';
import 'package:med_remind_app/data/repository/drift_reminder_settings_store.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/features/home/presentation/home_screen.dart';
import 'package:med_remind_app/main.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_onboarding_state_store.dart';
import 'support/fake_permission_gateway.dart';
import 'support/fixed_clock.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets(
    'AppLifecycleState.resumed invalidates homePlanControllerProvider, '
    'reaching Home through a real rebuild',
    (tester) async {
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final _CountingMedicineRepository medicines = _CountingMedicineRepository(
        DriftMedicineRepository(database),
      );

      await tester.pumpWidget(
        MediTrackerApp(
          overrides: startupOverrides(
            store: FakeOnboardingStateStore(completed: true),
            completed: true,
            medicineRepository: medicines,
            clock: FixedClock(),
            doseRepository: DriftDoseRepository(database),
            permissionGateway: FakePermissionGateway(),
            doseNotifier: const NoOpDoseNotifier(),
            reconciliationStateStore: DriftReconciliationStateStore(database),
            reminderSettingsStore: DriftReminderSettingsStore(database),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        medicines.allMedicinesCalls,
        3,
        reason:
            'the cold-start build\'s own three calls (the controller\'s own '
            'read, plus generate() and re-registration inside '
            'Reconciler.run()), and nothing has invalidated it since',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        medicines.allMedicinesCalls,
        6,
        reason:
            'resuming must invalidate homePlanControllerProvider, causing a '
            'real second build() -- not merely repaint the same one',
      );
    },
  );

  testWidgets('a lifecycle state other than resumed does not invalidate it', (
    tester,
  ) async {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final _CountingMedicineRepository medicines = _CountingMedicineRepository(
      DriftMedicineRepository(database),
    );

    await tester.pumpWidget(
      MediTrackerApp(
        overrides: startupOverrides(
          store: FakeOnboardingStateStore(completed: true),
          completed: true,
          medicineRepository: medicines,
          clock: FixedClock(),
          doseRepository: DriftDoseRepository(database),
          permissionGateway: FakePermissionGateway(),
          doseNotifier: const NoOpDoseNotifier(),
          reconciliationStateStore: DriftReconciliationStateStore(database),
          reminderSettingsStore: DriftReminderSettingsStore(database),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(medicines.allMedicinesCalls, 3);

    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pumpAndSettle();
    }

    expect(
      medicines.allMedicinesCalls,
      3,
      reason:
          'foreground is specifically resumed -- backgrounding must not '
          're-run reconciliation',
    );
  });
}

/// Counts calls to [allMedicines], delegating every member to [_inner].
final class _CountingMedicineRepository implements MedicineRepository {
  _CountingMedicineRepository(this._inner);

  final MedicineRepository _inner;

  /// How many times [allMedicines] has been called.
  int allMedicinesCalls = 0;

  @override
  Future<List<Medicine>> allMedicines() {
    allMedicinesCalls++;
    return _inner.allMedicines();
  }

  @override
  Future<Medicine?> findMedicine(String id) => _inner.findMedicine(id);

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
  }) => _inner.addMedicine(
    name: name,
    condition: condition,
    form: form,
    dosageAmount: dosageAmount,
    dosageUnit: dosageUnit,
    instructions: instructions,
    startDate: startDate,
    endDate: endDate,
    active: active,
  );

  @override
  Future<void> saveMedicine(Medicine medicine) => _inner.saveMedicine(medicine);

  @override
  Future<void> deleteMedicine(String id) => _inner.deleteMedicine(id);

  @override
  Future<List<Schedule>> schedulesFor(String medicineId) =>
      _inner.schedulesFor(medicineId);

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
    required bool remindersEnabled,
  }) => _inner.addSchedule(
    medicineId: medicineId,
    timeOfDay: timeOfDay,
    ianaTimezone: ianaTimezone,
    frequency: frequency,
    daysOfWeek: daysOfWeek,
    intervalDays: intervalDays,
    dosageAmount: dosageAmount,
    reminderOverride: reminderOverride,
    remindersEnabled: remindersEnabled,
  );

  @override
  Future<void> saveSchedule(Schedule schedule) => _inner.saveSchedule(schedule);

  @override
  Future<void> deleteSchedule(String id) => _inner.deleteSchedule(id);
}
