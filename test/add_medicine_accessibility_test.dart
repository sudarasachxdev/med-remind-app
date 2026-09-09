// The accessibility floor, on the three add-medicine steps.
//
// UX-DR20's hardest case in this story. The flow is dense -- two chip rows, two
// steppers, a seven-toggle day row, a switch -- and every one of those controls
// is drawn from an icon or a single letter in the delivered design. An icon
// announces as nothing and `M T W T F S S` announces two Ts and two Ss with
// nothing to tell them apart, so the labels are as load-bearing here as the
// layout.
//
// The Dynamic Type half is the one that is easy to claim and hard to hold, and
// this story's own spec had to disambiguate it: FR-1's "no step requires
// scrolling" is scoped to the DEFAULT text size. At the largest size the content
// reflows and may scroll -- scrolling is the correct outcome, truncation never
// is. Both halves are asserted below, because the unqualified rule licensed
// exactly the fixed layout that clips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/features/add_medicine/application/add_medicine_controller.dart';
import 'package:med_remind_app/features/add_medicine/domain/add_medicine_draft.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_copy.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_screen.dart';
import 'package:med_remind_app/app/theme.dart';

import 'support/fixed_clock.dart';
import 'support/unused_medicine_repository.dart';

/// The design's reference device frame: 402 x 874 logical pixels (iOS).
const Size _referenceFrame = Size(402, 874);

/// iOS's largest accessibility text size, as a scale factor.
///
/// Bigger than any setting a user can actually choose, which is the point: the
/// layout should have no cliff just past the real maximum either.
const double _largestTextScale = 3;

/// The container the most recent [_pumpStep] built, so a test can drive the
/// controller without reaching through the widget tree for it.
ProviderContainer? _lastContainer;

/// A draft with step 1 and step 2 answered, so step 3 can be reached.
AddMedicineDraft _completed() => const AddMedicineDraft()
    .withName('Atorvastatin')
    .withForm('tablet')
    .withUnit('tablet');

/// Pumps the flow at [step], with [draft] already entered.
Future<void> _pumpStep(
  WidgetTester tester, {
  AddMedicineStep step = AddMedicineStep.what,
  AddMedicineDraft? draft,
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

  // A fresh element tree each time, for the reason the onboarding suite gives:
  // re-pumping over an existing one reuses its ProviderScope container, so a
  // loop over the steps would inherit whichever step the last one left showing.
  await tester.pumpWidget(const SizedBox.shrink());

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      medicineRepositoryProvider.overrideWithValue(
        const UnusedMedicineRepository(),
      ),
      clockProvider.overrideWithValue(FixedClock()),
    ],
  );
  addTearDown(container.dispose);
  _lastContainer = container;
  addTearDown(() => _lastContainer = null);

  final AddMedicineController controller = container.read(
    addMedicineControllerProvider.notifier,
  );
  if (draft != null) {
    controller
      ..setName(draft.name)
      ..chooseForm(draft.form ?? 'tablet')
      ..chooseUnit(draft.unit ?? 'tablet');
  }
  for (int i = 0; i < step.index; i++) {
    controller.advance();
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: MTTheme.light, home: const AddMedicineScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every tappable in the tree, with its rendered size.
Iterable<({Finder finder, Size size})> _tappables(WidgetTester tester) sync* {
  final Finder finder = find.byWidgetPredicate(
    (Widget w) =>
        w is ButtonStyleButton ||
        w is InkWell ||
        w is GestureDetector ||
        w is Switch,
  );
  for (int i = 0; i < finder.evaluate().length; i++) {
    final Finder at = finder.at(i);
    yield (finder: at, size: tester.getSize(at));
  }
}

void main() {
  group('Dynamic Type at the largest accessibility size', () {
    for (final AddMedicineStep step in AddMedicineStep.values) {
      testWidgets('step ${step.step} reflows rather than truncating', (
        tester,
      ) async {
        await _pumpStep(
          tester,
          step: step,
          draft: _completed(),
          textScale: _largestTextScale,
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'An overflow or a clip at this size is a truncation. UX-DR20 '
              'requires the step to reflow vertically instead -- and the '
              'spec scopes FR-1\'s "no scrolling" to the default text size '
              'precisely so this can scroll.',
        );
      });

      testWidgets('step ${step.step} keeps its heading readable', (
        tester,
      ) async {
        await _pumpStep(
          tester,
          step: step,
          draft: _completed(),
          textScale: _largestTextScale,
        );

        final String heading = switch (step) {
          AddMedicineStep.what => AddMedicineCopy.stepOneHeading,
          AddMedicineStep.when => AddMedicineCopy.stepTwoHeading,
          AddMedicineStep.review => AddMedicineCopy.stepThreeHeading,
        };

        expect(find.text(heading), findsOneWidget);
        await tester.ensureVisible(find.text(heading));

        final Text widget = tester.widget<Text>(find.text(heading));
        expect(
          widget.overflow,
          isNot(TextOverflow.ellipsis),
          reason:
              'Ellipsising the question is truncation. The step grows taller '
              'instead.',
        );
        expect(
          widget.maxLines,
          isNull,
          reason: 'A capped heading clips at three times the text size.',
        );
      });
    }

    testWidgets('nothing is capped or ellipsised on any step', (tester) async {
      for (final AddMedicineStep step in AddMedicineStep.values) {
        await _pumpStep(
          tester,
          step: step,
          draft: _completed(),
          textScale: _largestTextScale,
        );

        for (final Element element in find.byType(Text).evaluate()) {
          final Text text = element.widget as Text;
          if (text.data == null) continue;
          expect(
            text.overflow,
            isNot(TextOverflow.ellipsis),
            reason: 'step ${step.step}: "${text.data}" ellipsises',
          );
        }
      }
    });
  });

  group('the touch floor', () {
    for (final AddMedicineStep step in AddMedicineStep.values) {
      testWidgets('step ${step.step} keeps every control above 44pt', (
        tester,
      ) async {
        await _pumpStep(tester, step: step, draft: _completed());

        // The floor applies to the drawn control's TAP TARGET, not to the box
        // the design paints. `control-md` is 46 and `control-sm` is 38 -- the
        // second is below the floor on purpose, which is why MTDimensions names
        // both floors and why this is asserted rather than assumed.
        for (final ({Finder finder, Size size}) tappable in _tappables(
          tester,
        )) {
          expect(
            tappable.size.height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason:
                'step ${step.step}: a control is ${tappable.size.height}pt '
                'high; the floor is 44pt/48dp. MTDimensions.touchMinAndroid '
                'is the binding one on a shared control.',
          );
          expect(
            tappable.size.width,
            greaterThanOrEqualTo(kMinInteractiveDimension),
            reason:
                'step ${step.step}: a control is ${tappable.size.width}pt '
                'wide',
          );
        }
      });
    }

    testWidgets('the day row toggles clear the floor', (tester) async {
      // The tightest case in the flow: seven controls across one row on a
      // 402pt-wide frame leaves 57pt each before any gutter.
      await _pumpStep(tester, step: AddMedicineStep.when, draft: _completed());

      _lastContainer!
          .read(addMedicineControllerProvider.notifier)
          .chooseRepeat(AddMedicineRepeat.specificDays);
      await tester.pumpAndSettle();

      for (int day = DateTime.monday; day <= DateTime.sunday; day++) {
        final Finder toggle = find.bySemanticsLabel(
          RegExp(AddMedicineCopy.dayNames[day]),
        );
        expect(
          toggle,
          findsWidgets,
          reason:
              '${AddMedicineCopy.dayNames[day]} has no semantics label. The '
              'design draws a single letter, and "T" cannot tell Tuesday from '
              'Thursday out loud.',
        );
      }
    });
  });

  group('screen reader', () {
    testWidgets('the step bar says which step this is', (tester) async {
      await _pumpStep(tester, step: AddMedicineStep.when, draft: _completed());

      await _withSemantics(tester, () async {
        expect(
          find.bySemanticsLabel(
            AddMedicineCopy.stepBarLabel(2, AddMedicineStep.count),
          ),
          findsOneWidget,
          reason:
              'Three bars announce as nothing. Sentence case, not the visible '
              'capitals: a reader saying "S T E P" is the failure that '
              'distinction avoids.',
        );
      });
    });

    testWidgets('the icon-only steppers carry words', (tester) async {
      await _pumpStep(tester, draft: _completed());

      await _withSemantics(tester, () async {
        for (final String label in <String>[
          AddMedicineCopy.actionDecreaseDose,
          AddMedicineCopy.actionIncreaseDose,
        ]) {
          expect(
            find.bySemanticsLabel(label),
            findsOneWidget,
            reason:
                'The design draws a `remove`/`add` glyph, which announces as '
                'nothing at all.',
          );
        }
      });
    });

    testWidgets('the two steppers on step 2 do not share a label', (
      tester,
    ) async {
      // Two controls with one label is one control to a reader.
      await _pumpStep(tester, step: AddMedicineStep.when, draft: _completed());

      await _withSemantics(tester, () async {
        expect(
          find.bySemanticsLabel(AddMedicineCopy.actionEarlierTime),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(AddMedicineCopy.actionLaterTime),
          findsOneWidget,
        );
      });

      expect(
        AddMedicineCopy.actionEarlierTime,
        isNot(AddMedicineCopy.actionShorterInterval),
        reason:
            'Both steppers announcing "Decrease" would be two controls with '
            'one name.',
      );
    });

    testWidgets('the back control is named, not just drawn', (tester) async {
      await _pumpStep(tester, draft: _completed());

      await _withSemantics(tester, () async {
        expect(
          find.bySemanticsLabel(AddMedicineCopy.actionBack),
          findsOneWidget,
          reason: 'the design draws an arrow with no word',
        );
      });
    });

    testWidgets('the reminders switch is a switch, with its explanation', (
      tester,
    ) async {
      await _pumpStep(
        tester,
        step: AddMedicineStep.review,
        draft: _completed(),
      );

      // Asserted on the ANNOUNCED STATE, not on `find.byType(Switch)`. The
      // toggle is drawn to the mock's 51x31 track and 27 knob rather than being
      // a Material `Switch`, so a type finder tests which widget was reached
      // for -- a rendering of the thing -- while `SemanticsFlag.hasToggledState`
      // tests what a screen reader is actually told. The first version of this
      // test asserted the type and failed against correct code.
      await _withSemantics(tester, () async {
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(RegExp(AddMedicineCopy.reminderEnabled)),
          ),
          matchesSemantics(
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
          ),
          reason:
              'The row must announce as ONE toggle carrying its state -- not '
              'as a title, a sentence of offsets and an unlabelled box, which '
              'is three nodes for one control. Reminders default to on, as '
              'the mock does.',
        );
      });

      expect(find.text(AddMedicineCopy.reminderEnabled), findsOneWidget);
      expect(
        find.text(AddMedicineCopy.escalationTimings),
        findsOneWidget,
        reason:
            'The story requires the real timings on this row, not a '
            'description of escalation.',
      );
    });
  });

  group('the default text size', () {
    for (final AddMedicineStep step in AddMedicineStep.values) {
      testWidgets('step ${step.step} needs no scrolling on the reference '
          'frame', (tester) async {
        // FR-1, as the spec scopes it: at the DEFAULT size, no step requires
        // scrolling to complete on a standard phone. The reference frame is the
        // design's own 402x874.
        await _pumpStep(tester, step: step, draft: _completed());

        expect(tester.takeException(), isNull);

        final Finder scrollables = find.byType(Scrollable);
        for (int i = 0; i < scrollables.evaluate().length; i++) {
          final ScrollableState state = tester.state<ScrollableState>(
            scrollables.at(i),
          );
          if (!state.position.hasContentDimensions) continue;
          expect(
            state.position.maxScrollExtent,
            0,
            reason:
                'step ${step.step} scrolls at the default text size on the '
                'design\'s own frame. FR-1 says it should not have to.',
          );
        }
      });
    }
  });
}

/// Runs [body] with the semantics tree built.
///
/// The handle is disposed inside the test body, not in a tear-down:
/// `flutter_test` checks for leaked `SemanticsHandle`s *before* tear-downs run,
/// so `addTearDown(handle.dispose)` fails every test that uses it. The
/// onboarding suite found this first and its note is worth repeating here,
/// because the failure names the handle rather than the assertion and reads
/// like six unrelated tests breaking at once.
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
