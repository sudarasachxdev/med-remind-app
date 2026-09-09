// The add-medicine draft: every question about form state, without a widget.
//
// Nine of the spec's thirteen I/O matrix rows are questions about the draft, not
// about pixels -- "is Continue enabled", "does decrement move", "did the inline
// row collapse". Held in an immutable object they are answerable in a unit test,
// and the enablement rule is decided in one place instead of three screens.
//
// That matters here more than as tidiness. This project's recurring failure is a
// test asserting on a RENDERING of a thing rather than the thing: a passing
// `find.byType`, a `toString()`, a count. `canAdvanceFrom` is the thing.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/policy/medicine_vocabulary.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/features/add_medicine/domain/add_medicine_draft.dart';

/// A draft with step 1 satisfied, so a test about step 2 is not also a test
/// about step 1.
AddMedicineDraft _completeStepOne() => const AddMedicineDraft()
    .withName('Atorvastatin')
    .withForm('tablet')
    .withUnit('tablet');

void main() {
  group('a new draft opens on the design\'s own defaults', () {
    const AddMedicineDraft draft = AddMedicineDraft();

    test('nothing is chosen that the user has not chosen', () {
      expect(draft.name, isEmpty);
      expect(draft.condition, isEmpty);
      expect(
        draft.form,
        isNull,
        reason:
            'A pre-selected form is a decision made for the user that they '
            'then have to notice and undo.',
      );
      expect(draft.unit, isNull);
    });

    test('the values the design does default are the design\'s', () {
      // `amount: 1`, `newTime: '08:00 PM'`, `repeat: 'Every day'`,
      // `reminder: true` in the delivered mock's state object.
      expect(draft.amount, 1);
      expect(draft.hourOfDay, 20);
      expect(draft.timeOfDay, '20:00');
      expect(draft.repeat, AddMedicineRepeat.everyDay);
      expect(draft.remindersEnabled, isTrue);
      expect(draft.intervalDays, Schedule.minimumIntervalDays);
    });

    test('it cannot advance from step 1', () {
      expect(draft.canAdvanceFrom(AddMedicineStep.what), isFalse);
    });
  });

  group('step 1 enablement (FR-1: a name and a dosage amount with unit)', () {
    test('a complete step 1 may advance', () {
      expect(_completeStepOne().canAdvanceFrom(AddMedicineStep.what), isTrue);
    });

    test('an empty name blocks it, and so does a whitespace one', () {
      for (final String name in <String>['', '   ', '\n\t']) {
        expect(
          _completeStepOne()
              .withName(name)
              .canAdvanceFrom(AddMedicineStep.what),
          isFalse,
          reason:
              'A name of ${name.length} whitespace characters is not a name, '
              'and FR-1 requires one.',
        );
      }
    });

    test('no chosen unit blocks it', () {
      final AddMedicineDraft draft = const AddMedicineDraft()
          .withName('Atorvastatin')
          .withForm('tablet');

      expect(draft.canAdvanceFrom(AddMedicineStep.what), isFalse);
    });

    test('no chosen form blocks it', () {
      final AddMedicineDraft draft = const AddMedicineDraft()
          .withName('Atorvastatin')
          .withUnit('tablet');

      expect(draft.canAdvanceFrom(AddMedicineStep.what), isFalse);
    });
  });

  group('the Other unit', () {
    test('choosing Other reveals the free-text entry', () {
      final AddMedicineDraft draft = _completeStepOne().withUnit(
        dosageUnitOther,
      );

      expect(draft.isCustomUnitChosen, isTrue);
    });

    test('Other with nothing typed does not advance', () {
      final AddMedicineDraft draft = _completeStepOne().withUnit(
        dosageUnitOther,
      );

      expect(draft.resolvedUnit, isEmpty);
      expect(draft.canAdvanceFrom(AddMedicineStep.what), isFalse);
    });

    test('Other with only whitespace typed does not advance', () {
      final AddMedicineDraft draft = _completeStepOne()
          .withUnit(dosageUnitOther)
          .withCustomUnit('   ');

      expect(draft.canAdvanceFrom(AddMedicineStep.what), isFalse);
    });

    test('the typed unit is what gets stored, never the sentinel', () {
      final AddMedicineDraft draft = _completeStepOne()
          .withUnit(dosageUnitOther)
          .withCustomUnit('  sachet  ');

      expect(draft.canAdvanceFrom(AddMedicineStep.what), isTrue);
      expect(
        draft.resolvedUnit,
        'sachet',
        reason:
            'Storing the `other` sentinel would render as "1 other" on every '
            'dose card.',
      );
    });
  });

  group('the dose stepper', () {
    test('increments without a ceiling', () {
      AddMedicineDraft draft = const AddMedicineDraft();
      for (int i = 0; i < 5; i++) {
        draft = draft.withMoreAmount();
      }
      expect(draft.amount, 6);
    });

    test('floors at 1, and decrementing there is inert', () {
      const AddMedicineDraft draft = AddMedicineDraft();

      expect(draft.amount, AddMedicineDraft.minimumAmount);
      expect(
        draft.withLessAmount(),
        equals(draft),
        reason:
            'Inert, not an error: there is nothing to explain about a dose '
            'that cannot go below one, so nothing is said.',
      );
      expect(draft.withLessAmount().withLessAmount().amount, 1);
    });

    test('comes back down to the floor and stops', () {
      final AddMedicineDraft raised = const AddMedicineDraft()
          .withMoreAmount()
          .withMoreAmount();

      expect(raised.withLessAmount().withLessAmount().amount, 1);
      expect(
        raised.withLessAmount().withLessAmount().withLessAmount().amount,
        1,
      );
    });
  });

  group('the time stepper', () {
    test('moves an hour at a time, as the design does', () {
      // The mock's `shiftTime` shifts `h24` by +/-1.
      expect(const AddMedicineDraft().withLaterTime().hourOfDay, 21);
      expect(const AddMedicineDraft().withEarlierTime().hourOfDay, 19);
    });

    test('wraps at both ends rather than clamping', () {
      AddMedicineDraft draft = const AddMedicineDraft();
      for (int i = 0; i < 4; i++) {
        draft = draft.withLaterTime();
      }
      expect(draft.hourOfDay, 0, reason: '20 + 4 hours is midnight');
      expect(
        draft.withEarlierTime().hourOfDay,
        23,
        reason:
            "Dart's % on a negative left operand answers a negative, so an "
            'hour before midnight is the case that catches a missing wrap.',
      );
    });

    test('every hour formats as a two-digit HH:mm', () {
      // Schedule.isValidTimeOfDay is strict, and the duplicate rule compares
      // these strings -- `8:00` and `08:00` would be one time that compared
      // unequal.
      AddMedicineDraft draft = const AddMedicineDraft();
      for (int i = 0; i < AddMedicineDraft.hoursInDay; i++) {
        expect(
          Schedule.isValidTimeOfDay(draft.timeOfDay),
          isTrue,
          reason: '${draft.hourOfDay} formatted as ${draft.timeOfDay}',
        );
        draft = draft.withLaterTime();
      }
      expect(draft.hourOfDay, 20, reason: '24 steps returns to the start');
    });
  });

  group('the repeat options and their inline controls', () {
    test('only Specific days expands the day row', () {
      for (final AddMedicineRepeat repeat in AddMedicineRepeat.values) {
        expect(
          const AddMedicineDraft().withRepeat(repeat).isDayRowExpanded,
          repeat == AddMedicineRepeat.specificDays,
          reason: '$repeat',
        );
      }
    });

    test('only Every N days expands the interval stepper', () {
      for (final AddMedicineRepeat repeat in AddMedicineRepeat.values) {
        expect(
          const AddMedicineDraft().withRepeat(repeat).isIntervalStepperExpanded,
          repeat == AddMedicineRepeat.everyNDays,
          reason: '$repeat',
        );
      }
    });

    test('Specific days with no day chosen does not advance', () {
      final AddMedicineDraft draft = _completeStepOne().withRepeat(
        AddMedicineRepeat.specificDays,
      );

      expect(draft.isDayRowExpanded, isTrue);
      expect(draft.canAdvanceFrom(AddMedicineStep.when), isFalse);
    });

    test('one chosen day is enough', () {
      final AddMedicineDraft draft = _completeStepOne()
          .withRepeat(AddMedicineRepeat.specificDays)
          .withDayToggled(DateTime.wednesday);

      expect(draft.canAdvanceFrom(AddMedicineStep.when), isTrue);
      expect(draft.scheduleDaysOfWeek, <int>{DateTime.wednesday});
    });

    test('a day toggles off again, and the empty set only disables', () {
      final AddMedicineDraft draft = _completeStepOne()
          .withRepeat(AddMedicineRepeat.specificDays)
          .withDayToggled(DateTime.monday);

      final AddMedicineDraft off = draft.withDayToggled(DateTime.monday);

      expect(off.daysOfWeek, isEmpty);
      expect(
        off.canAdvanceFrom(AddMedicineStep.when),
        isFalse,
        reason:
            'Removing the last day disables Continue rather than being '
            'prevented, so the user is never trapped holding a day they did '
            'not want.',
      );
    });

    test('changing the option collapses the row AND discards its days', () {
      // The matrix's "Repeat changed away" row. Keeping a hidden day selection
      // would let an invisible value decide enablement the next time Specific
      // days is chosen.
      final AddMedicineDraft chosen = _completeStepOne()
          .withRepeat(AddMedicineRepeat.specificDays)
          .withDayToggled(DateTime.monday)
          .withDayToggled(DateTime.friday);

      final AddMedicineDraft moved = chosen.withRepeat(
        AddMedicineRepeat.everyDay,
      );

      expect(moved.isDayRowExpanded, isFalse);
      expect(moved.daysOfWeek, isEmpty);
      expect(moved.scheduleDaysOfWeek, isNull);
      expect(
        moved.withRepeat(AddMedicineRepeat.specificDays).daysOfWeek,
        isEmpty,
        reason: 'coming back finds it empty, not silently pre-filled',
      );
    });

    test('re-tapping the chosen option keeps the days just picked', () {
      final AddMedicineDraft chosen = _completeStepOne()
          .withRepeat(AddMedicineRepeat.specificDays)
          .withDayToggled(DateTime.monday);

      expect(
        chosen.withRepeat(AddMedicineRepeat.specificDays),
        equals(chosen),
        reason:
            'A second tap on the option already selected must not wipe the '
            'selection it reveals.',
      );
    });

    test('the interval opens at the minimum and floors there', () {
      final AddMedicineDraft draft = _completeStepOne().withRepeat(
        AddMedicineRepeat.everyNDays,
      );

      expect(draft.intervalDays, Schedule.minimumIntervalDays);
      expect(
        draft.withShorterInterval(),
        equals(draft),
        reason:
            'An interval of 1 is `Every day` written the long way, and '
            'Frequency refuses two spellings of one pattern.',
      );
      expect(draft.withLongerInterval().intervalDays, 3);
      expect(
        draft.withLongerInterval().withShorterInterval().intervalDays,
        Schedule.minimumIntervalDays,
      );
    });

    test('Every N days advances immediately, having no empty state', () {
      expect(
        _completeStepOne()
            .withRepeat(AddMedicineRepeat.everyNDays)
            .canAdvanceFrom(AddMedicineStep.when),
        isTrue,
      );
    });

    test('changing the option resets the interval too', () {
      final AddMedicineDraft raised = _completeStepOne()
          .withRepeat(AddMedicineRepeat.everyNDays)
          .withLongerInterval()
          .withLongerInterval();

      expect(raised.intervalDays, 4);
      expect(
        raised.withRepeat(AddMedicineRepeat.everyDay).intervalDays,
        Schedule.minimumIntervalDays,
      );
    });
  });

  group('what the draft hands the repository', () {
    test('each repeat option maps to its Frequency', () {
      expect(
        const AddMedicineDraft()
            .withRepeat(AddMedicineRepeat.everyDay)
            .frequency,
        Frequency.everyDay,
      );
      expect(
        const AddMedicineDraft()
            .withRepeat(AddMedicineRepeat.weekdays)
            .frequency,
        Frequency.weekdays,
      );
      expect(
        const AddMedicineDraft()
            .withRepeat(AddMedicineRepeat.specificDays)
            .frequency,
        Frequency.specificDays,
      );
    });

    test('the companion fields are null unless their option is chosen', () {
      // Schedule.pairingViolation rejects a Frequency whose companion does not
      // match, so sending a stale interval alongside `Every day` would be
      // rejected at save time rather than here.
      final AddMedicineDraft everyDay = _completeStepOne();

      expect(everyDay.scheduleDaysOfWeek, isNull);
      expect(everyDay.scheduleIntervalDays, isNull);

      final AddMedicineDraft interval = everyDay.withRepeat(
        AddMedicineRepeat.everyNDays,
      );
      expect(interval.scheduleDaysOfWeek, isNull);
      expect(interval.scheduleIntervalDays, Schedule.minimumIntervalDays);
    });

    test('an empty condition is null, not an empty string', () {
      // ` · Tablet` is what an empty string renders as on Home and detail.
      expect(const AddMedicineDraft().conditionOrNull, isNull);
      expect(
        const AddMedicineDraft().withCondition('  ').conditionOrNull,
        isNull,
      );
      expect(
        const AddMedicineDraft()
            .withCondition('  Type 2 Diabetes ')
            .conditionOrNull,
        'Type 2 Diabetes',
      );
    });

    test('the name is trimmed and the amount is a double', () {
      final AddMedicineDraft draft = _completeStepOne().withName(
        '  Metformin ',
      );

      expect(draft.trimmedName, 'Metformin');
      expect(draft.dosageAmount, 1.0);
      expect(draft.withMoreAmount().dosageAmount, 2.0);
    });
  });

  group('the steps themselves', () {
    test('there are three, numbered from one', () {
      // The header says "STEP n OF 3" and the bar draws three segments; both
      // read this, so a fourth step cannot appear in one and not the other.
      expect(AddMedicineStep.count, 3);
      expect(AddMedicineStep.values.map((AddMedicineStep s) => s.step), <int>[
        1,
        2,
        3,
      ]);
      expect(AddMedicineStep.values.first.isFirst, isTrue);
      expect(AddMedicineStep.values.last.isLast, isTrue);
    });

    test('the ends have nowhere further to go', () {
      expect(AddMedicineStep.values.first.previous, isNull);
      expect(AddMedicineStep.values.last.next, isNull);
    });

    test('step 3 re-checks both earlier steps, not just its own', () {
      // Save is the one action that cannot be taken back, so it does not trust
      // that the user reached step 3 legitimately.
      final AddMedicineDraft incomplete = _completeStepOne().withRepeat(
        AddMedicineRepeat.specificDays,
      );

      expect(incomplete.canAdvanceFrom(AddMedicineStep.review), isFalse);
      expect(
        incomplete
            .withName('')
            .withDayToggled(DateTime.monday)
            .canAdvanceFrom(AddMedicineStep.review),
        isFalse,
      );
    });
  });
}
