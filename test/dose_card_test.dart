// `DoseCard`'s three Story 2.3 variants -- Taken, Skipped, Snoozed -- pumped
// bare, with a hand-built `Dose`/`HomeDoseEntry` rather than a seeded
// database: none of the three touches a provider during `build()` (they are
// plain `StatelessWidget`s, unlike the plain/due/overdue cards this file does
// not re-test), so there is nothing here for `home_screen_test.dart`'s
// heavier, database-backed `pumpHome` to buy.
//
// Testing depth is LIGHTER (project-context.md): one test per matrix row,
// plus this story's own two acceptance criteria (AC1: `takenAt`, never
// `scheduledAt`; AC2: the glyph tile tracks the Medicine, never the state).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/model/dose_state.dart';
import 'package:med_remind_app/domain/policy/dose_resolver.dart';
import 'package:med_remind_app/features/home/application/home_plan_controller.dart';
import 'package:med_remind_app/features/home/presentation/dose_card.dart';
import 'package:med_remind_app/features/home/presentation/glyph_tile.dart';
import 'package:med_remind_app/features/home/presentation/home_copy.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  // `Dose`'s own constructor resolves its zone through `package:timezone`
  // (`dose_recorder_test.dart`'s own house rule).
  setUpAll(tzdata.initializeTimeZones);

  final DateTime defaultNow = DateTime(2026, 9, 9, 10, 30);

  /// A Dose scheduled at [scheduledLocal], with every other field defaulted
  /// to something plausible -- `dose_recorder_test.dart`'s own `buildDose`
  /// shape, since this file needs the same kind of hand-built fixture and no
  /// database to round-trip it through.
  Dose buildDose({
    DateTime? scheduledLocal,
    int escalationWindowMinutes = 60,
    DateTime? takenAt,
    DateTime? skippedAt,
    DateTime? snoozedUntil,
    String medicineName = 'Metformin',
  }) => Dose(
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    scheduledLocal: scheduledLocal ?? DateTime(2026, 9, 9, 8, 0),
    ianaTimezone: 'Asia/Colombo',
    takenAt: takenAt,
    skippedAt: skippedAt,
    snoozedUntil: snoozedUntil,
    escalationWindowMinutes: escalationWindowMinutes,
    medicineName: medicineName,
    dosageAmount: 1,
    dosageUnit: 'tablet',
    form: 'tablet',
  );

  HomeDoseEntry buildEntry(
    Dose dose,
    DateTime now, {
    int glyphIndex = 0,
    String? condition,
  }) => HomeDoseEntry(
    dose: dose,
    resolution: resolve(dose, now),
    glyphIndex: glyphIndex,
    condition: condition,
  );

  /// Pumps a bare `DoseCard` -- a `ProviderScope` ancestor is harmless
  /// insurance (`_OverdueDoseCard`/`_PlainOrDueDoseCard` are `Consumer*`
  /// widgets elsewhere in this switch), but nothing this file actually
  /// renders reads a provider during `build()`.
  Future<void> pumpCard(
    WidgetTester tester,
    HomeDoseEntry entry,
    DateTime now,
  ) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: DoseCard(entry: entry, now: now),
        ),
      ),
    ),
  );

  int glyphIndexOf(WidgetTester tester) =>
      tester.widget<GlyphTile>(find.byType(GlyphTile)).glyphIndex;

  group('Taken (the spec\'s own matrix rows)', () {
    testWidgets(
      'on time -- "✓ Taken at {actual time}", medicine\'s own glyph tint',
      (tester) async {
        final DateTime takenAt = DateTime(2026, 9, 9, 8, 2);
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          takenAt: takenAt,
        );

        await pumpCard(
          tester,
          buildEntry(dose, defaultNow, glyphIndex: 2),
          defaultNow,
        );

        expect(find.text(HomeCopy.stateTaken(takenAt)), findsOneWidget);
        expect(glyphIndexOf(tester), 2);
      },
    );

    testWidgets(
      'after the window -- same treatment; History\'s distinct "Taken late" '
      'label never appears on Home',
      (tester) async {
        final DateTime takenAt = DateTime(2026, 9, 9, 12, 0);
        final Dose dose = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          takenAt: takenAt,
        );
        expect(
          resolve(dose, defaultNow).loggedLate,
          isTrue,
          reason: 'sanity: this fixture really is logged late',
        );

        await pumpCard(tester, buildEntry(dose, defaultNow), defaultNow);

        expect(find.text(HomeCopy.stateTaken(takenAt)), findsOneWidget);
        expect(find.textContaining('late'), findsNothing);
      },
    );

    testWidgets(
      'AC1 -- shows takenAt, never scheduledAt: two Doses with the same '
      'takenAt but different scheduledAt render identically',
      (tester) async {
        final DateTime takenAt = DateTime(2026, 9, 9, 8, 2);
        final Dose morning = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 8, 0),
          takenAt: takenAt,
        );
        final Dose evening = buildDose(
          scheduledLocal: DateTime(2026, 9, 9, 20, 0),
          takenAt: takenAt,
        );

        await pumpCard(tester, buildEntry(morning, defaultNow), defaultNow);
        expect(find.text(HomeCopy.stateTaken(takenAt)), findsOneWidget);

        await pumpCard(tester, buildEntry(evening, defaultNow), defaultNow);
        expect(
          find.text(HomeCopy.stateTaken(takenAt)),
          findsOneWidget,
          reason: 'identical chip text despite a different scheduledAt',
        );
        expect(find.textContaining('8:00 PM'), findsNothing);
      },
    );
  });

  group('Skipped (the spec\'s own row)', () {
    testWidgets(
      'neutral tile, "– Skipped", no red anywhere, medicine\'s own glyph tint',
      (tester) async {
        final Dose dose = buildDose(skippedAt: defaultNow);

        await pumpCard(
          tester,
          buildEntry(dose, defaultNow, glyphIndex: 3),
          defaultNow,
        );

        expect(find.text(HomeCopy.stateSkipped), findsOneWidget);
        expect(glyphIndexOf(tester), 3);
      },
    );
  });

  group('Snoozed (the spec\'s own rows)', () {
    testWidgets('reads "Snoozed · reminder in {n} min"', (tester) async {
      final Dose dose = buildDose(
        snoozedUntil: defaultNow.add(const Duration(minutes: 12)),
      );

      await pumpCard(
        tester,
        buildEntry(dose, defaultNow, glyphIndex: 1),
        defaultNow,
      );

      expect(find.text(HomeCopy.stateSnoozed(12)), findsOneWidget);
      expect(glyphIndexOf(tester), 1);
    });

    testWidgets('about to expire -- reads "1 min", never "0" or negative', (
      tester,
    ) async {
      final Dose dose = buildDose(
        snoozedUntil: defaultNow.add(const Duration(minutes: 1)),
      );

      await pumpCard(tester, buildEntry(dose, defaultNow), defaultNow);

      expect(find.text(HomeCopy.stateSnoozed(1)), findsOneWidget);
    });
  });

  group('AC2 -- the glyph tile tint is per-Medicine on every state', () {
    testWidgets(
      'all seven DoseState values render, and every one reads the same '
      'held-constant glyphIndex, never a state-driven colour',
      (tester) async {
        const int glyphIndex = 2;
        final DateTime today = DateTime(2026, 9, 9, 8, 0);

        final Map<DoseState, Dose> doseByState = <DoseState, Dose>{
          DoseState.scheduled: buildDose(
            scheduledLocal: defaultNow.add(const Duration(hours: 2)),
          ),
          DoseState.due: buildDose(
            scheduledLocal: defaultNow.subtract(const Duration(minutes: 10)),
          ),
          DoseState.overdue: buildDose(
            scheduledLocal: defaultNow.subtract(const Duration(hours: 3)),
            escalationWindowMinutes: 30,
          ),
          DoseState.missed: buildDose(
            scheduledLocal: defaultNow.subtract(const Duration(days: 2)),
            escalationWindowMinutes: 30,
          ),
          DoseState.taken: buildDose(
            scheduledLocal: today,
            takenAt: defaultNow,
          ),
          DoseState.skipped: buildDose(
            scheduledLocal: today,
            skippedAt: defaultNow,
          ),
          DoseState.snoozed: buildDose(
            scheduledLocal: today,
            snoozedUntil: defaultNow.add(const Duration(minutes: 5)),
          ),
        };

        for (final MapEntry<DoseState, Dose> pair in doseByState.entries) {
          expect(
            resolve(pair.value, defaultNow).state,
            pair.key,
            reason: 'sanity: this fixture really resolves to ${pair.key}',
          );

          await pumpCard(
            tester,
            buildEntry(pair.value, defaultNow, glyphIndex: glyphIndex),
            defaultNow,
          );

          expect(
            glyphIndexOf(tester),
            glyphIndex,
            reason:
                '${pair.key}\'s glyph tile must read the Medicine\'s own '
                'glyphIndex, never a colour driven by state',
          );
        }
      },
    );
  });
}
