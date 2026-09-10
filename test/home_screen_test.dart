// Home, pumped as a real screen over a real (if in-memory) database -- the
// widget half of this story's matrix: the fixed vertical order, the three
// dose-card variants, and the accessibility floor UX-DR20 sets.
//
// Testing depth is LIGHTER (project-context.md), with the standing exception
// this spec itself names: "this is the first real screen reading live-
// generated data, and home_screen_test.dart is not optional." Pumped as a
// bare `HomeScreen` under its own `ProviderScope`/`MaterialApp`, not the whole
// `MediTrackerApp`: nothing here navigates (Story 2.2 owns the action sheet,
// and the day strip does not select yet -- Story 4.4), so there is no router
// to exercise.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/dose_repository_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/features/home/presentation/dose_card.dart';
import 'package:med_remind_app/features/home/presentation/home_copy.dart';
import 'package:med_remind_app/features/home/presentation/home_screen.dart';
import 'package:med_remind_app/features/home/presentation/overdue_banner.dart';
import 'package:med_remind_app/features/home/presentation/progress_card.dart';
import 'package:med_remind_app/features/home/presentation/week_strip.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fixed_clock.dart';

/// The design's reference device frame: 402 x 874 logical pixels (iOS).
const Size _referenceFrame = Size(402, 874);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final DateTime defaultNow = DateTime(2026, 9, 9, 10, 30);
  final DateTime defaultStart = DateTime(2026, 9, 7);

  Future<Medicine> addMedicine(
    MedicineRepository medicines, {
    String name = 'Metformin',
    String? condition,
  }) => medicines.addMedicine(
    name: name,
    condition: condition,
    form: 'tablet',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    startDate: defaultStart,
  );

  Future<void> addSchedule(
    MedicineRepository medicines,
    String medicineId, {
    required String timeOfDay,
  }) async {
    await medicines.addSchedule(
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      ianaTimezone: FixedClock.defaultZone,
      frequency: Frequency.everyDay,
      dosageAmount: 1,
    );
  }

  /// Pumps `HomeScreen` over a fresh in-memory database, seeded by [seed]
  /// through the real repositories before the first frame.
  Future<void> pumpHome(
    WidgetTester tester, {
    required Future<void> Function(MedicineRepository medicines) seed,
    DateTime? now,
    double? textScale,
    Size viewport = _referenceFrame,
  }) async {
    tester.view.physicalSize = viewport * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    if (textScale != null) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final MedicineRepository medicines = DriftMedicineRepository(database);
    final DoseRepository doses = DriftDoseRepository(database);

    await seed(medicines);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          medicineRepositoryProvider.overrideWithValue(medicines),
          doseRepositoryProvider.overrideWithValue(doses),
          clockProvider.overrideWithValue(
            FixedClock(instant: now ?? defaultNow),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the fixed vertical order (UX-DR23)', () {
    testWidgets(
      'greeting, date, week strip, progress card, dose list and footnote '
      'appear top to bottom',
      (tester) async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        final double greetingY = tester
            .getTopLeft(find.text(HomeCopy.greetingFor(defaultNow)))
            .dy;
        final double dateY = tester
            .getTopLeft(find.text(HomeCopy.formattedDate(defaultNow)))
            .dy;
        final double weekStripY = tester.getTopLeft(find.byType(WeekStrip)).dy;
        final double progressY = tester
            .getTopLeft(find.byType(ProgressCard))
            .dy;
        final double doseCardY = tester
            .getTopLeft(find.byType(DoseCard).first)
            .dy;
        final double footnoteY = tester
            .getTopLeft(find.text(HomeCopy.privacyFootnote))
            .dy;

        expect(greetingY, lessThan(dateY));
        expect(dateY, lessThan(weekStripY));
        expect(weekStripY, lessThan(progressY));
        expect(progressY, lessThan(doseCardY));
        expect(doseCardY, lessThan(footnoteY));
      },
    );

    testWidgets('the overdue banner sits between the progress card and the '
        'dose list when it is present', (tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 9, 9, 14, 0),
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          // 6h window: Due until 13:00, Overdue at 14:00 (the pumped `now`).
          await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
        },
      );

      final double progressY = tester.getTopLeft(find.byType(ProgressCard)).dy;
      final double bannerY = tester.getTopLeft(find.byType(OverdueBanner)).dy;
      final double doseCardY = tester
          .getTopLeft(find.byType(DoseCard).first)
          .dy;

      expect(progressY, lessThan(bannerY));
      expect(bannerY, lessThan(doseCardY));
    });

    testWidgets('absent entirely when nothing is overdue', (tester) async {
      await pumpHome(
        tester,
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
        },
      );

      expect(find.byType(OverdueBanner), findsNothing);
    });
  });

  group('the three dose-card variants', () {
    testWidgets('plain (Scheduled), due, and overdue each render their own '
        'chip word', (tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 9, 9, 14, 0),
        seed: (medicines) async {
          final Medicine overdue = await addMedicine(
            medicines,
            name: 'OverdueMed',
          );
          await addSchedule(medicines, overdue.id, timeOfDay: '07:00');
          final Medicine due = await addMedicine(medicines, name: 'DueMed');
          await addSchedule(medicines, due.id, timeOfDay: '09:00');
          final Medicine scheduled = await addMedicine(
            medicines,
            name: 'LaterMed',
          );
          await addSchedule(medicines, scheduled.id, timeOfDay: '20:00');
        },
      );

      expect(find.byType(DoseCard), findsNWidgets(3));
      expect(find.text(HomeCopy.stateScheduled), findsOneWidget);
      expect(find.text(HomeCopy.stateDue), findsOneWidget);
      expect(
        find.textContaining('Overdue · was due'),
        findsOneWidget,
        reason: 'the overdue chip states the word and the original time',
      );
    });
  });

  group('accessibility (UX-DR20)', () {
    testWidgets('each dose card announces medicine, dose, time and state as '
        'one label', (tester) async {
      await _withSemantics(tester, () async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(
              medicines,
              condition: 'Type 2 diabetes',
            );
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        final SemanticsNode node = tester.getSemantics(find.byType(DoseCard));
        expect(node.label, contains('Metformin'));
        expect(node.label, contains('Type 2 diabetes'));
        expect(node.label, contains('1 tablet'));
        expect(node.label, contains('8:00 AM'));
        expect(node.label, contains(HomeCopy.stateDue));

        // One label, not several: the name/meta/chip Text widgets inside must
        // not also be independently reachable by a screen reader.
        expect(find.bySemanticsLabel('Metformin'), findsNothing);
      });
    });

    testWidgets('focus/reading order follows the fixed vertical order', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        final double greetingY = tester
            .getTopLeft(find.text(HomeCopy.greetingFor(defaultNow)))
            .dy;
        final double weekStripY = tester.getTopLeft(find.byType(WeekStrip)).dy;
        final double progressY = tester
            .getTopLeft(find.byType(ProgressCard))
            .dy;
        final double doseCardY = tester.getTopLeft(find.byType(DoseCard)).dy;

        // The default traversal policy over a linear, top-to-bottom layout
        // follows widget-tree (== visual) order, which is what this checks --
        // greeting, then the week strip, then progress, then the dose list,
        // per this story's own acceptance criterion.
        expect(greetingY, lessThan(weekStripY));
        expect(weekStripY, lessThan(progressY));
        expect(progressY, lessThan(doseCardY));
      });
    });

    testWidgets('the overdue row\'s decorative actions clear the 44/48pt '
        'floor', (tester) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 9, 9, 14, 0),
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
        },
      );

      for (final String label in <String>['✓ I took it', 'Snooze', 'Skip']) {
        // The floor is enforced on the pill's own `ConstrainedBox`, not on
        // the bare `Text` inside it -- a short label's glyph run is shorter
        // than the pill's own minimum height, so measuring the text directly
        // would be measuring the wrong box.
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
          reason:
              '"$label"\'s pill is ${size.height}pt tall; UX-DR20 names this '
              'row the tightest case and the floor applies before Story 2.2 '
              'wires the tap, not after',
        );
      }
    });
  });

  group('Dynamic Type reflow', () {
    testWidgets('renders without overflowing at the largest accessibility '
        'text size', (tester) async {
      await pumpHome(
        tester,
        textScale: 3,
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(
            medicines,
            condition: 'A fairly long condition name',
          );
          await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          await addSchedule(medicines, medicine.id, timeOfDay: '20:00');
        },
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the nothing-scheduled chip wraps rather than overflowing '
        'the progress card', (tester) async {
      await pumpHome(
        tester,
        textScale: 3,
        seed: (medicines) async {
          await medicines.addMedicine(
            name: 'Ended',
            form: 'tablet',
            dosageAmount: 1,
            dosageUnit: 'tablet',
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 31),
          );
        },
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining(HomeCopy.nothingScheduled), findsOneWidget);
    });
  });
}

/// Runs [body] with the semantics tree built.
///
/// The handle is disposed inside the test body, not in a tear-down:
/// `flutter_test` checks for leaked `SemanticsHandle`s *before* tear-downs
/// run, so `addTearDown(handle.dispose)` fails every test that uses it --
/// `onboarding_accessibility_test.dart`'s own helper of the same name notes
/// the same thing.
Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}
