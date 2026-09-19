// `DoseActionSheet` -- one test per matrix row that involves the sheet,
// following `dose_recorder_test.dart`'s shape: a real `DriftDoseRepository`
// over an in-memory database, a `FixedClock`, and the real `DoseRecorder`
// wired through `doseRecorderProvider` rather than a fake -- this is the
// write side of the action loop, and Story 2.2's own project-context
// exception holds it to the full matrix, not the lighter default.
//
// The sheet is opened through `DoseActionSheet.show` over a bare pumped
// `Scaffold`, exactly the way `dose_card.dart`'s own tap handler calls it --
// not through the whole `HomeScreen`, which `home_screen_test.dart` already
// covers for the "tap opens the sheet" and "overdue row acts directly" rows.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/dose_notifier_provider.dart';
import 'package:med_remind_app/app/dose_repository_provider.dart';
import 'package:med_remind_app/app/reminder_settings_store_provider.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/data/repository/drift_reminder_settings_store.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/policy/snooze_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/features/home/presentation/home_copy.dart';
import 'package:med_remind_app/shared/widgets/dose_action_sheet.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fixed_clock.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final DateTime now = FixedClock.defaultInstant;

  late AppDatabase database;
  late DoseRepository doses;
  late MedicineRepository medicines;
  late Schedule schedule;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    doses = DriftDoseRepository(database);
    medicines = DriftMedicineRepository(database);

    final Medicine medicine = await medicines.addMedicine(
      name: 'Candesartan',
      condition: 'High blood pressure',
      form: 'tablet',
      dosageAmount: 1,
      dosageUnit: 'tablet',
      startDate: DateTime(2026, 8, 1),
    );
    schedule = await medicines.addSchedule(
      remindersEnabled: true,
      medicineId: medicine.id,
      timeOfDay: '08:00',
      ianaTimezone: FixedClock.defaultZone,
      frequency: Frequency.everyDay,
      dosageAmount: 1,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Dose buildDose({
    required DateTime scheduledLocal,
    int escalationWindowMinutes = 60,
  }) => Dose(
    scheduleId: schedule.id,
    medicineId: schedule.medicineId,
    scheduledLocal: scheduledLocal,
    ianaTimezone: schedule.ianaTimezone,
    escalationWindowMinutes: escalationWindowMinutes,
    medicineName: 'Candesartan',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    form: 'tablet',
  );

  /// Pumps a bare `Scaffold` with one button that opens `DoseActionSheet` for
  /// [dose] -- the same call `dose_card.dart`'s trailing control makes.
  /// Returns a holder the test reads after the button is tapped: `value` is
  /// the toast `DoseActionSheet.show` resolved with, `set` once the `Future`
  /// completes.
  Future<_ShowResult> pumpSheetOpener(
    WidgetTester tester, {
    required Dose dose,
    String? condition = 'High blood pressure',
  }) async {
    final _ShowResult result = _ShowResult();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          doseRepositoryProvider.overrideWithValue(doses),
          // Story 3.2 flips doseNotifierProvider's default to a throw --
          // this file's matrix is about DoseRecorder's write side and the
          // sheet's own copy, not about scheduling or cancelling a real
          // notification, so the inert no-op is what this test relied on
          // implicitly before that story existed.
          doseNotifierProvider.overrideWithValue(const NoOpDoseNotifier()),
          clockProvider.overrideWithValue(FixedClock(instant: now)),
          reminderSettingsStoreProvider.overrideWithValue(
            DriftReminderSettingsStore(database),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result.value = await DoseActionSheet.show(
                    context,
                    dose: dose,
                    glyphIndex: 1,
                    condition: condition,
                  );
                  result.set = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return result;
  }

  group('the sheet opens with the mock\'s own shape', () {
    testWidgets(
      'glyph, title, meta and condition chip -- present when a condition is',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          escalationWindowMinutes: 120,
        );
        await pumpSheetOpener(tester, dose: dose);

        expect(find.text(HomeCopy.sheetTitle('Candesartan')), findsOneWidget);
        expect(
          find.text(
            HomeCopy.sheetMeta(
              amount: 1,
              unit: 'tablet',
              time: dose.scheduledLocal,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('High blood pressure'), findsOneWidget);
        expect(find.text(HomeCopy.sheetTakeAction), findsOneWidget);
        expect(
          find.text(
            HomeCopy.sheetSnoozeAction(defaultSnoozeInterval.inMinutes),
          ),
          findsOneWidget,
        );
        expect(find.text(HomeCopy.sheetSkipAction), findsOneWidget);
      },
    );

    testWidgets('no chip at all when the Medicine has no condition', (
      tester,
    ) async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 8, 0),
        escalationWindowMinutes: 120,
      );
      await pumpSheetOpener(tester, dose: dose, condition: null);

      expect(find.text('High blood pressure'), findsNothing);
    });
  });

  group('take', () {
    testWidgets(
      'on time: DoseRecorder.take is called, the sheet closes, and the '
      'toast is "Recorded {name} as taken"',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 10, 0),
          escalationWindowMinutes: 60,
        );
        await doses.saveDose(dose);
        final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

        await tester.tap(find.text(HomeCopy.sheetTakeAction));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.sheetTakeAction), findsNothing);
        expect(result.set, isTrue);
        expect(result.value, HomeCopy.toastTaken('Candesartan'));
        final Dose saved = (await doses.findDose(dose.id))!;
        expect(saved.takenAt, isNotNull);
      },
    );

    testWidgets(
      'after the window: the toast additionally states it was recorded '
      'late (UX-DR19)',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          escalationWindowMinutes: 60,
        );
        await doses.saveDose(dose);
        final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

        await tester.tap(find.text(HomeCopy.sheetTakeAction));
        await tester.pumpAndSettle();

        expect(result.value, HomeCopy.toastTakenLate('Candesartan'));
      },
    );
  });

  group('snooze', () {
    testWidgets(
      'the ordinary case: DoseRecorder.snooze is called, the sheet closes, '
      'and the toast is "Snoozed {n} minutes"',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 10, 0),
          escalationWindowMinutes: 120,
        );
        await doses.saveDose(dose);
        final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

        await tester.tap(
          find.text(
            HomeCopy.sheetSnoozeAction(defaultSnoozeInterval.inMinutes),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.sheetSkipAction), findsNothing);
        expect(
          result.value,
          HomeCopy.toastSnoozed(defaultSnoozeInterval.inMinutes),
        );
        final Dose saved = (await doses.findDose(dose.id))!;
        expect(saved.snoozedUntil, isNotNull);
      },
    );

    testWidgets('refused (would cross into Overdue): the sheet stays open, the '
        'failure is visible text, and nothing is recorded or confirmed', (
      tester,
    ) async {
      final Dose dose = buildDose(
        scheduledLocal: DateTime(2026, 9, 9, 8, 0),
        escalationWindowMinutes: 60,
      );
      await doses.saveDose(dose);
      final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

      await tester.tap(
        find.text(HomeCopy.sheetSnoozeAction(defaultSnoozeInterval.inMinutes)),
      );
      await tester.pumpAndSettle();

      // Still open: the title is still on screen and nothing was popped.
      expect(find.text(HomeCopy.sheetTitle('Candesartan')), findsOneWidget);
      expect(result.set, isFalse);
      expect(
        find.text('This dose is too close to its overdue time to snooze.'),
        findsOneWidget,
      );
      final Dose unchanged = (await doses.findDose(dose.id))!;
      expect(unchanged.snoozedUntil, isNull);
    });
  });

  group('skip', () {
    testWidgets(
      'DoseRecorder.skip is called, the sheet closes, and the toast is '
      '"Marked as skipped"',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        );
        await doses.saveDose(dose);
        final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

        await tester.tap(find.text(HomeCopy.sheetSkipAction));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.sheetSkipAction), findsNothing);
        expect(result.value, HomeCopy.toastSkipped);
        final Dose saved = (await doses.findDose(dose.id))!;
        expect(saved.skippedAt, isNotNull);
      },
    );
  });

  group('dismissal', () {
    testWidgets(
      'a scrim tap closes the sheet with nothing recorded and no toast',
      (tester) async {
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 10, 0),
        );
        await doses.saveDose(dose);
        final _ShowResult result = await pumpSheetOpener(tester, dose: dose);

        // The scrim covers the whole barrier; a point well above the sheet's
        // own content is certainly still the barrier, not one of its actions.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.sheetTakeAction), findsNothing);
        expect(result.set, isTrue);
        expect(result.value, isNull);
        final Dose unchanged = (await doses.findDose(dose.id))!;
        expect(unchanged.takenAt, isNull);
        expect(unchanged.skippedAt, isNull);
        expect(unchanged.snoozedUntil, isNull);
      },
    );
  });

  group('accessibility (UX-DR20)', () {
    testWidgets(
      'at the largest accessibility text size, all three actions clear the '
      '44/48pt floor and no label truncates',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          escalationWindowMinutes: 120,
        );
        await pumpSheetOpener(tester, dose: dose);

        expect(tester.takeException(), isNull);
        for (final String label in <String>[
          HomeCopy.sheetTakeAction,
          HomeCopy.sheetSnoozeAction(defaultSnoozeInterval.inMinutes),
          HomeCopy.sheetSkipAction,
        ]) {
          final Size size = tester.getSize(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byWidgetPredicate(
                    (Widget w) =>
                        w is ConstrainedBox && w.constraints.minHeight >= 44,
                  ),
                )
                .first,
          );
          expect(
            size.height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason: '"$label" is ${size.height}pt tall at 3x text scale',
          );
        }
      },
    );
  });
}

/// Holds `DoseActionSheet.show`'s own result, set once its `Future`
/// completes -- `set` distinguishes "resolved with `null`" (dismissal) from
/// "has not resolved yet".
class _ShowResult {
  String? value;
  bool set = false;
}
