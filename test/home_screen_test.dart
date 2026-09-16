// Home, pumped as a real screen over a real (if in-memory) database -- the
// widget half of this story's matrix: the fixed vertical order, the three
// dose-card variants, and the accessibility floor UX-DR20 sets.
//
// Testing depth is LIGHTER (project-context.md), with two standing
// exceptions: "this is the first real screen reading live-generated data,
// and home_screen_test.dart is not optional" (Story 1.8/1.9), and Story
// 2.2's own "standard, not lighter" for the write side this file's own "two
// entry points to DoseRecorder" group covers. Pumped as a bare `HomeScreen`
// under its own `ProviderScope`/`MaterialApp`, not the whole
// `MediTrackerApp`: the action sheet is a plain `Navigator` route
// (`showModalBottomSheet`), not a `go_router` one, and the day strip does
// not select yet (Story 4.4), so there is still no ROUTER to exercise here
// -- EXCEPT the empty state's own "Add medicine" action (Story 1.9), which
// is the one control on this screen that does navigate. Its own group below
// pumps a second, minimal harness -- `pumpHomeWithRouter` -- that carries a
// real `GoRouter` over the same two routes `app/router.dart` registers,
// rather than promoting every test in this file to the full
// `MediTrackerApp`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/dose_repository_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/app/permission_gateway_provider.dart';
import 'package:med_remind_app/app/router.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_dose_repository.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/policy/snooze_policy.dart';
import 'package:med_remind_app/domain/port/dose_repository.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/domain/port/permission_gateway.dart';
import 'package:med_remind_app/features/add_medicine/domain/add_medicine_draft.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_copy.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_screen.dart';
import 'package:med_remind_app/features/home/presentation/dose_card.dart';
import 'package:med_remind_app/features/home/presentation/home_copy.dart';
import 'package:med_remind_app/features/home/presentation/home_empty_state.dart';
import 'package:med_remind_app/features/home/presentation/home_screen.dart';
import 'package:med_remind_app/features/home/presentation/overdue_banner.dart';
import 'package:med_remind_app/features/home/presentation/permission_banner.dart';
import 'package:med_remind_app/features/home/presentation/progress_card.dart';
import 'package:med_remind_app/features/home/presentation/week_strip.dart';
import 'package:med_remind_app/shared/widgets/mt_toast.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_permission_gateway.dart';
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
    PermissionGateway? permissionGateway,
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
          // Granted by default -- Story 3.1b's own group below is the one
          // that overrides this to prove the banner's own matrix rows; every
          // test written before that story keeps asserting a screen with no
          // banner in it.
          permissionGatewayProvider.overrideWithValue(
            permissionGateway ?? FakePermissionGateway(),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps `HomeScreen` behind a real, minimal `GoRouter` carrying the same
  /// two routes `app/router.dart` registers for Home and the add-medicine
  /// flow -- so a tap on the empty state's action exercises the real
  /// `MTRoutes.addMedicine` route rather than a stand-in. Returns the
  /// repositories too, so a test can act on them after the first pump and
  /// then remount `HomeScreen` to prove the screen switches with no manual
  /// refresh.
  Future<
    ({GoRouter router, MedicineRepository medicines, DoseRepository doses})
  >
  pumpHomeWithRouter(
    WidgetTester tester, {
    required Future<void> Function(MedicineRepository medicines) seed,
    DateTime? now,
    Size viewport = _referenceFrame,
    PermissionGateway? permissionGateway,
  }) async {
    tester.view.physicalSize = viewport * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final MedicineRepository medicines = DriftMedicineRepository(database);
    final DoseRepository doses = DriftDoseRepository(database);

    await seed(medicines);

    final GoRouter router = GoRouter(
      initialLocation: MTRoutes.homePath,
      routes: <RouteBase>[
        GoRoute(
          path: MTRoutes.homePath,
          name: MTRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: MTRoutes.addMedicinePath,
          name: MTRoutes.addMedicine,
          builder: (context, state) => const AddMedicineScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          medicineRepositoryProvider.overrideWithValue(medicines),
          doseRepositoryProvider.overrideWithValue(doses),
          clockProvider.overrideWithValue(
            FixedClock(instant: now ?? defaultNow),
          ),
          permissionGatewayProvider.overrideWithValue(
            permissionGateway ?? FakePermissionGateway(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    return (router: router, medicines: medicines, doses: doses);
  }

  group('the empty state (this story\'s own matrix)', () {
    testWidgets(
      'zero Medicines renders the empty-state card; the progress card, dose '
      'list and next-dose chip are absent from the tree entirely',
      (tester) async {
        await pumpHome(tester, seed: (medicines) async {});

        expect(find.byType(EmptyStateCard), findsOneWidget);
        expect(find.text(HomeCopy.emptyStateTitle), findsOneWidget);
        expect(find.text(HomeCopy.emptyStateBody), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, AddMedicineCopy.screenTitle),
          findsOneWidget,
        );
        expect(find.byType(ProgressCard), findsNothing);
        expect(find.byType(DoseCard), findsNothing);
        expect(find.byType(OverdueBanner), findsNothing);
        expect(
          find.byType(WeekStrip),
          findsOneWidget,
          reason:
              'the week strip is unconditional chrome, not part of the '
              'empty/populated branch (the mock\'s own isHome block draws it '
              'before either alternative)',
        );
      },
    );

    testWidgets(
      'a Medicine with no Dose due today renders the populated plan, never '
      'the empty state',
      (tester) async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            // Every 5 days from `defaultStart` (2026-09-07): occurrences fall
            // on the 7th, 12th, 17th... never on `defaultNow`'s the 9th.
            await medicines.addSchedule(
              medicineId: medicine.id,
              timeOfDay: '08:00',
              ianaTimezone: FixedClock.defaultZone,
              frequency: Frequency.everyNDays,
              intervalDays: 5,
              dosageAmount: 1,
            );
          },
        );

        expect(find.byType(EmptyStateCard), findsNothing);
        expect(find.text(HomeCopy.emptyStateTitle), findsNothing);
        expect(find.byType(ProgressCard), findsOneWidget);
        expect(find.text(HomeCopy.progressLabel(0, 0)), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Add medicine" opens the add flow at step 1, via the real '
      'addMedicine route',
      (tester) async {
        await pumpHomeWithRouter(tester, seed: (medicines) async {});

        await tester.tap(
          find.widgetWithText(FilledButton, AddMedicineCopy.screenTitle),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AddMedicineScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(
          find.text(AddMedicineCopy.stepLabel(1, AddMedicineStep.count)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'once a Medicine is saved and Home is returned to, the empty state is '
      'replaced with no manual refresh',
      (tester) async {
        final result = await pumpHomeWithRouter(
          tester,
          seed: (medicines) async {},
        );
        expect(find.byType(EmptyStateCard), findsOneWidget);

        // Leave Home for the add flow first -- a genuine location change, so
        // `homePlanControllerProvider` (`autoDispose`) is actually torn down
        // on the way out rather than merely rebuilt in place; `.go()` to the
        // SAME path a widget is already showing is not the round trip a real
        // "add medicine, then return" does.
        result.router.go(MTRoutes.addMedicinePath);
        await tester.pumpAndSettle();
        expect(find.byType(AddMedicineScreen), findsOneWidget);

        // The real save path a user's "Add medicine" flow takes --
        // `MedicineRepository`, never a Dose constructed by hand -- against
        // the SAME repository instances the pumped screen reads from. This
        // is Story 1.9's own claim: the screen switches, not the data side,
        // which `home_plan_test.dart`'s "First Medicine just saved" group
        // already proves at the controller level.
        final Medicine medicine = await addMedicine(result.medicines);
        await addSchedule(result.medicines, medicine.id, timeOfDay: '08:00');

        // "Return to Home": go_router replaces the location, which is
        // exactly what `add_medicine_screen.dart`'s own `_save` does after a
        // successful save -- no pull-to-refresh, no manual reload button,
        // nothing this test reaches for beyond the navigation itself.
        result.router.go(MTRoutes.homePath);
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(EmptyStateCard), findsNothing);
        expect(find.byType(ProgressCard), findsOneWidget);
        expect(find.byType(DoseCard), findsOneWidget);
      },
    );
  });

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

  group('the notification-permission banner (Story 3.1b, this spec\'s own '
      'matrix)', () {
    testWidgets(
      'permission denied -- the banner shows, above the overdue banner',
      (tester) async {
        await pumpHome(
          tester,
          now: DateTime(2026, 9, 9, 14, 0),
          permissionGateway: FakePermissionGateway(notificationsEnabled: false),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            // 6h window: Due until 13:00, Overdue at 14:00 (the pumped
            // `now`) -- so both conditional banners are on screen together.
            await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
          },
        );

        expect(find.byType(PermissionBanner), findsOneWidget);
        expect(find.text(HomeCopy.permissionBannerTitle), findsOneWidget);

        final double progressY = tester
            .getTopLeft(find.byType(ProgressCard))
            .dy;
        final double permissionY = tester
            .getTopLeft(find.byType(PermissionBanner))
            .dy;
        final double overdueY = tester
            .getTopLeft(find.byType(OverdueBanner))
            .dy;

        expect(
          progressY,
          lessThan(permissionY),
          reason: 'UX-DR23: between the progress card and the overdue banner',
        );
        expect(permissionY, lessThan(overdueY));
      },
    );

    testWidgets('permission granted -- the banner is absent entirely, not '
        'merely hidden', (tester) async {
      await pumpHome(
        tester,
        permissionGateway: FakePermissionGateway(notificationsEnabled: true),
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
        },
      );

      expect(find.byType(PermissionBanner), findsNothing);
    });

    testWidgets(
      'revoked mid-session -- the banner appears on the next Home build, '
      'with no restart',
      (tester) async {
        final gateway = FakePermissionGateway(notificationsEnabled: true);
        final result = await pumpHomeWithRouter(
          tester,
          permissionGateway: gateway,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );
        expect(find.byType(PermissionBanner), findsNothing);

        // "Denied via OS Settings, user returns to app": the same running
        // gateway instance now answers false, and a genuine location change
        // -- away from Home and back -- tears down and rebuilds
        // `homePlanControllerProvider` (`autoDispose`), exactly as this
        // file's own "once a Medicine is saved" test already does for a
        // Medicine write.
        gateway.notificationsEnabled = false;
        result.router.go(MTRoutes.addMedicinePath);
        await tester.pumpAndSettle();
        result.router.go(MTRoutes.homePath);
        await tester.pumpAndSettle();

        expect(find.byType(PermissionBanner), findsOneWidget);
      },
    );

    testWidgets('dismissing hides the banner for this session', (tester) async {
      await pumpHome(
        tester,
        permissionGateway: FakePermissionGateway(notificationsEnabled: false),
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
        },
      );
      expect(find.byType(PermissionBanner), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Not `find.byType(PermissionBanner)`: that widget is the `State`
      // holder for the dismiss flag itself, so it stays mounted (rendering
      // nothing) exactly as `AnimatedSwitcher`'s own outgoing child would --
      // the banner's own visible content is what "hides" means here.
      expect(find.text(HomeCopy.permissionBannerTitle), findsNothing);
      expect(find.byIcon(Icons.notifications_off), findsNothing);
    });

    testWidgets(
      'relaunching after a dismissal shows it again -- the dismissal did '
      'not persist',
      (tester) async {
        await pumpHome(
          tester,
          permissionGateway: FakePermissionGateway(notificationsEnabled: false),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text(HomeCopy.permissionBannerTitle), findsNothing);

        // A relaunch: the whole tree is torn down and a fresh one pumped,
        // exactly as `onboarding_screen_test.dart`'s own "killed on panel 2"
        // test models it -- re-pumping over the same element would reuse the
        // `PermissionBanner`'s own `State` and its dismissal with it.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpHome(
          tester,
          permissionGateway: FakePermissionGateway(notificationsEnabled: false),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        expect(
          find.byType(PermissionBanner),
          findsOneWidget,
          reason:
              'permission is still denied, and dismissal is in-memory '
              'only (this story\'s own Boundaries)',
        );
      },
    );

    testWidgets('tapping the settings route calls '
        'openAppNotificationSettings', (tester) async {
      final gateway = FakePermissionGateway(notificationsEnabled: false);
      await pumpHome(
        tester,
        permissionGateway: gateway,
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
        },
      );

      await tester.tap(find.text(HomeCopy.permissionBannerSettingsAction));
      await tester.pumpAndSettle();

      expect(gateway.openAppNotificationSettingsCalls, 1);
    });

    testWidgets(
      'permission denied -- adding a medicine and recording a dose both '
      'succeed exactly as with permission granted (FR-6, NFR-3)',
      (tester) async {
        final result = await pumpHomeWithRouter(
          tester,
          permissionGateway: FakePermissionGateway(notificationsEnabled: false),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );
        expect(find.byType(PermissionBanner), findsOneWidget);

        // Record the seeded Dose -- the same sheet path every other test in
        // this file uses, proving the denial does not touch it.
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();
        await tester.tap(find.text(HomeCopy.sheetTakeAction));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.progressLabel(1, 1)), findsOneWidget);
        final Dose taken = (await result.doses.dosesScheduledBetween(
          DateTime(2026, 9, 9),
          DateTime(2026, 9, 10),
        )).single;
        expect(taken.takenAt, isNotNull);

        // Add a second Medicine through the real route -- the empty state's
        // own entry point is Story 1.9's, exercised here only to prove it
        // still opens under denial.
        result.router.go(MTRoutes.addMedicinePath);
        await tester.pumpAndSettle();
        expect(find.byType(AddMedicineScreen), findsOneWidget);

        // Flushes the toast's own auto-dismiss `Timer`.
        await tester.pump(mtToastDuration);
      },
    );
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

    testWidgets('Taken, Skipped and Snoozed each render their own chip once '
        'DoseRecorder has written real facts for them (Story 2.3)', (
      tester,
    ) async {
      await pumpHome(
        tester,
        seed: (medicines) async {
          final Medicine taken = await addMedicine(medicines, name: 'TakenMed');
          await addSchedule(medicines, taken.id, timeOfDay: '08:00');
          final Medicine skipped = await addMedicine(
            medicines,
            name: 'SkippedMed',
          );
          await addSchedule(medicines, skipped.id, timeOfDay: '09:00');
          final Medicine snoozed = await addMedicine(
            medicines,
            name: 'SnoozedMed',
          );
          await addSchedule(medicines, snoozed.id, timeOfDay: '10:00');
        },
      );

      Finder cardFor(String medicineName) => find.ancestor(
        of: find.text(medicineName),
        matching: find.byType(DoseCard),
      );

      // Each of the three starts Due (all within the default 6h window of
      // `defaultNow`) -- the sheet is the only entry point this test uses,
      // one medicine at a time, so a still-Due card's own check icon is
      // never ambiguous between them. Each action's own toast is flushed
      // before the next tap -- unlike this group's other, single-action
      // tests, three unflushed toasts here would stack at the bottom of the
      // screen and physically block the next sheet's own bottom-most
      // action from ever receiving a tap.
      await tester.tap(
        find.descendant(
          of: cardFor('TakenMed'),
          matching: find.byIcon(Icons.check),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeCopy.sheetTakeAction));
      await tester.pumpAndSettle();
      await tester.pump(mtToastDuration);

      await tester.tap(
        find.descendant(
          of: cardFor('SkippedMed'),
          matching: find.byIcon(Icons.check),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeCopy.sheetSkipAction));
      await tester.pumpAndSettle();
      await tester.pump(mtToastDuration);

      await tester.tap(
        find.descendant(
          of: cardFor('SnoozedMed'),
          matching: find.byIcon(Icons.check),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(HomeCopy.sheetSnoozeAction(defaultSnoozeInterval.inMinutes)),
      );
      await tester.pumpAndSettle();

      expect(find.text(HomeCopy.stateTaken(defaultNow)), findsOneWidget);
      expect(find.text(HomeCopy.stateSkipped), findsOneWidget);
      expect(
        find.text(HomeCopy.stateSnoozed(defaultSnoozeInterval.inMinutes)),
        findsOneWidget,
      );

      // Flushes the third toast's own auto-dismiss `Timer`.
      await tester.pump(mtToastDuration);
    });
  });

  group('the last dose of the day (UX-DR21\'s negative requirement)', () {
    testWidgets(
      'recording the only Dose of the day shows no celebratory animation, '
      'streak, badge or points -- the absence is what this test asserts',
      (tester) async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();
        await tester.tap(find.text(HomeCopy.sheetTakeAction));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.progressLabel(1, 1)), findsOneWidget);
        expect(
          find.byWidgetPredicate((Widget widget) {
            final String type = widget.runtimeType.toString().toLowerCase();
            return type.contains('confetti') ||
                type.contains('celebrat') ||
                type.contains('streak') ||
                type.contains('badge');
          }),
          findsNothing,
        );
        expect(
          find.textContaining('!'),
          findsNothing,
          reason: 'no exclamation mark anywhere, including on this path',
        );

        // Flushes the toast's own auto-dismiss `Timer`.
        await tester.pump(mtToastDuration);
      },
    );
  });

  group('the two entry points to DoseRecorder (Story 2.2)', () {
    testWidgets(
      'a plain/due card\'s trailing control opens the sheet -- it does not '
      'act directly, and nothing is recorded until an action inside it is '
      'tapped',
      (tester) async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(find.text(HomeCopy.sheetTitle('Metformin')), findsOneWidget);
        expect(find.text(HomeCopy.sheetTakeAction), findsOneWidget);
      },
    );

    testWidgets(
      'a successful action taken from the sheet is also reflected on Home '
      'with no manual refresh',
      (tester) async {
        await pumpHome(
          tester,
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '08:00');
          },
        );
        expect(find.text(HomeCopy.stateDue), findsOneWidget);

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();
        await tester.tap(find.text(HomeCopy.sheetTakeAction));
        await tester.pumpAndSettle();

        expect(
          find.text(HomeCopy.stateDue),
          findsNothing,
          reason:
              'the taken dose no longer resolves Due, with no manual '
              'refresh needed to see it',
        );

        // Flushes the toast's own auto-dismiss `Timer`.
        await tester.pump(mtToastDuration);
      },
    );

    testWidgets(
      'the overdue row\'s "I took it" calls DoseRecorder.take directly -- '
      'no sheet opens, and the toast matches the sheet path\'s own wording',
      (tester) async {
        final result = await pumpHomeWithRouter(
          tester,
          now: DateTime(2026, 9, 9, 14, 0),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
          },
        );

        await tester.tap(find.text('✓ I took it'));
        await tester.pump();

        expect(
          find.text(HomeCopy.sheetTitle('Metformin')),
          findsNothing,
          reason: 'the overdue row never opens the sheet',
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Recorded Metformin as taken'),
          findsOneWidget,
        );

        final Dose taken = (await result.doses.dosesScheduledBetween(
          DateTime(2026, 9, 9),
          DateTime(2026, 9, 10),
        )).single;
        expect(taken.takenAt, isNotNull);

        // Flushes the toast's own auto-dismiss `Timer` (`mtToastDuration`)
        // before the test ends -- `flutter_test` fails a test that leaves a
        // real `Timer` pending, and this one is not otherwise awaited.
        await tester.pump(mtToastDuration);
      },
    );

    testWidgets('the overdue row\'s "Snooze" is refused, with the same visible '
        'failure text the sheet path would show -- nothing recorded', (
      tester,
    ) async {
      await pumpHome(
        tester,
        now: DateTime(2026, 9, 9, 14, 0),
        seed: (medicines) async {
          final Medicine medicine = await addMedicine(medicines);
          await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
        },
      );

      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();

      expect(
        find.text('This dose is too close to its overdue time to snooze.'),
        findsOneWidget,
      );
      expect(find.byType(DoseCard), findsOneWidget);
      expect(
        find.textContaining('Overdue · was due'),
        findsOneWidget,
        reason: 'still Overdue -- the refusal changed nothing',
      );
    });

    testWidgets(
      'a successful action from the overdue row is reflected on Home with '
      'no manual refresh',
      (tester) async {
        await pumpHome(
          tester,
          now: DateTime(2026, 9, 9, 14, 0),
          seed: (medicines) async {
            final Medicine medicine = await addMedicine(medicines);
            await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
          },
        );
        expect(find.text(HomeCopy.progressLabel(0, 1)), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Overdue · was due'),
          findsNothing,
          reason: 'the skipped dose no longer resolves Overdue',
        );
        expect(
          find.byType(OverdueBanner),
          findsNothing,
          reason: 'overdueCount dropped to 0 with no manual refresh',
        );

        // See the "I took it" test above for why this flush is here.
        await tester.pump(mtToastDuration);
      },
    );
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

    testWidgets(
      'the permission banner sits in focus order between the progress card '
      'and the overdue banner, and its two controls are individually '
      'reachable (EXPERIENCE.md\'s amended focus-traversal line)',
      (tester) async {
        await _withSemantics(tester, () async {
          await pumpHome(
            tester,
            now: DateTime(2026, 9, 9, 14, 0),
            permissionGateway: FakePermissionGateway(
              notificationsEnabled: false,
            ),
            seed: (medicines) async {
              final Medicine medicine = await addMedicine(medicines);
              await addSchedule(medicines, medicine.id, timeOfDay: '07:00');
            },
          );

          final double progressY = tester
              .getTopLeft(find.byType(ProgressCard))
              .dy;
          final double permissionY = tester
              .getTopLeft(find.byType(PermissionBanner))
              .dy;
          final double overdueY = tester
              .getTopLeft(find.byType(OverdueBanner))
              .dy;
          expect(progressY, lessThan(permissionY));
          expect(permissionY, lessThan(overdueY));

          expect(
            find.bySemanticsLabel(HomeCopy.permissionBannerSettingsAction),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(HomeCopy.permissionBannerDismiss),
            findsOneWidget,
          );
        });
      },
    );

    testWidgets('the overdue row\'s three real actions clear the 44/48pt '
        'floor and are individually reachable (Story 2.2)', (tester) async {
      await _withSemantics(tester, () async {
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
          // the bare `Text` inside it -- a short label's glyph run is
          // shorter than the pill's own minimum height, so measuring the
          // text directly would be measuring the wrong box.
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
                '"$label"\'s pill is ${size.height}pt tall; UX-DR20 names '
                'this row the tightest case',
          );
          // Story 2.2: each pill is now a real, individually-labelled
          // control -- no longer swallowed by one merged `excludeSemantics`
          // node the way the card's own name/meta/chip still are.
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      });
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
