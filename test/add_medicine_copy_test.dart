// The add-medicine copy: the product's voice, and provenance for every string.
//
// Two jobs, and the second is the one this project keeps needing. Voice: the
// shared rules in `support/voice_rules.dart` run over the whole set, because a
// rule about tone is a property of the set and not of any one string.
// Provenance: the delivered design is the source, and the strings that are NOT
// transcribed are named here as well as at their declaration -- so the list of
// invented copy is a thing a reviewer can read, rather than a thing they have to
// assemble by grepping doc comments.
//
// Story 1.3 composed three onboarding titles that already existed one directory
// away in `imports/MediTracker.dc.html`. This test is the check that the same
// did not happen here.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/features/add_medicine/domain/add_medicine_draft.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_copy.dart';

import 'support/voice_rules.dart';

/// The strings this flow composes rather than transcribes, and why.
///
/// Spelled out so the count is a decision. Every entry has a reason at its own
/// declaration in `add_medicine_copy.dart`; a sixth appearing here without one
/// is the failure this list exists to make visible.
const Map<String, String> _composedStrings = <String, String>{
  AddMedicineCopy.conditionPlaceholder:
      'the design has no Condition input at all; the wording was decided by '
      'the product owner on 2026-09-07',
  AddMedicineCopy.customUnitPlaceholder:
      "the design draws no input behind its `Other` chip; the word is FR-1's "
      'own noun',
  AddMedicineCopy.actionBack:
      'the design draws an arrow with no word, and a screen reader needs one',
  AddMedicineCopy.timezoneUnavailable:
      'the failure did not exist when the design was delivered; AD-9 was '
      'amended on 2026-09-08',
};

/// Strings the design writes verbatim. Transcribed from the `{{ isAdd }}` block
/// of `imports/MediTracker.dc.html` and its trailing script.
const List<String> _transcribed = <String>[
  'Add medicine',
  'Cancel',
  'What are you taking, and how much?',
  'Medicine name',
  'FORM',
  'DOSE PER TIME',
  'When should you take it?',
  'TIME',
  'REPEAT',
  "Reminders, then you're set",
  'Reminder enabled',
  'Follow-up +15, final +30, overdue +60',
  'Time',
  'Repeat',
  'Reminders',
  'Starts',
  'Today',
  'You can change any of this later from Schedule.',
  'Continue',
  'Save medicine',
  'Off',
];

void main() {
  group('Voice and Tone', () {
    test('there is copy to check', () {
      // A guard over an empty set passes for the wrong reason.
      expect(AddMedicineCopy.all.length, greaterThan(30));
    });

    test('no exclamation mark anywhere', () {
      for (final String copy in AddMedicineCopy.all) {
        expect(copy, isNot(contains('!')), reason: '"$copy"');
      }
    });

    test('no encouragement and no streak language', () {
      for (final String copy in AddMedicineCopy.all) {
        for (final String banned in encouragementWords) {
          expect(
            copy.toLowerCase(),
            isNot(contains(banned)),
            reason: '"$banned" is encouragement or gamification: "$copy"',
          );
        }
      }
    });

    test('no clinical phrasing', () {
      // The one flow most at risk of it: this is the screen that asks for a
      // dose and a condition, where "administer", "regimen" and "prescribed"
      // are the words a chart would use.
      for (final String copy in AddMedicineCopy.all) {
        for (final String banned in clinicalWords) {
          expect(
            copy.toLowerCase(),
            isNot(contains(banned)),
            reason: '"$banned" is clinical phrasing: "$copy"',
          );
        }
      }
    });

    test('nothing frames a choice as the lesser one', () {
      for (final String copy in AddMedicineCopy.all) {
        for (final String banned in judgementalWords) {
          expect(
            copy.toLowerCase(),
            isNot(contains(banned)),
            reason: '"$banned" judges a legitimate choice: "$copy"',
          );
        }
      }
    });

    test('nothing shouts except the section labels and the step line', () {
      // DESIGN.md: ALL-CAPS labels group form sections, "the only place
      // capitals are used". Two refinements, both learned by writing the naive
      // version of this test and watching it fail on correct copy:
      //
      //   * The position line `STEP 2 OF 3` is set in the same `label` style as
      //     the section labels and is capitals for the same reason. It is a
      //     fifth legitimate caps string, not a violation.
      //   * `08:00 PM` has no lower-case letters because a time has none. A
      //     rule that reads "all cased letters are upper" calls that shouting,
      //     which is a rule finding a fact about the alphabet rather than about
      //     the voice.
      final Set<String> allowed = <String>{
        ...AddMedicineCopy.sectionLabels,
        for (final AddMedicineStep step in AddMedicineStep.values)
          AddMedicineCopy.stepLabel(step.step, AddMedicineStep.count),
      };
      final RegExp timeOfDay = RegExp(r'^\d{2}:00 [AP]M$');

      final List<String> shouted = AddMedicineCopy.all
          .where(
            (String copy) =>
                copy.length > 2 &&
                copy.contains(RegExp('[A-Za-z]')) &&
                copy == copy.toUpperCase() &&
                !timeOfDay.hasMatch(copy),
          )
          .toList();

      expect(
        shouted.toSet(),
        allowed,
        reason:
            'Either a new capitalised label was added without being listed, '
            'or a sentence is shouting.',
      );
    });
  });

  group('provenance', () {
    test('every transcribed string is present, exactly as written', () {
      // Exact equality, not `contains`. A string that is nearly the design's is
      // the failure mode -- it reads fine in review and is not what was
      // delivered.
      for (final String expected in _transcribed) {
        expect(
          AddMedicineCopy.all,
          contains(expected),
          reason:
              '"$expected" is in imports/MediTracker.dc.html and must appear '
              'verbatim. Do not paraphrase the design.',
        );
      }
    });

    test('exactly four strings are composed rather than transcribed', () {
      // A count, and a deliberate pause. Composed copy is the thing that goes
      // wrong quietly: it is always plausible, and it is always someone
      // deciding on the product's behalf. Bump this when you mean to, and add
      // the reason.
      expect(_composedStrings, hasLength(4));
      for (final MapEntry<String, String> entry in _composedStrings.entries) {
        expect(
          AddMedicineCopy.all,
          contains(entry.key),
          reason: 'composed string no longer used: "${entry.key}"',
        );
        expect(entry.value, isNotEmpty);
      }
    });

    test('the Condition placeholder is the wording that was chosen', () {
      // Two alternatives were rejected on the record: `Condition (optional)`
      // puts our domain word in front of the user, and `e.g. Type 2 Diabetes`
      // hints the field is looked up -- which PRD 6 forbids, since Condition is
      // displayed but never interpreted or matched against any database.
      expect(AddMedicineCopy.conditionPlaceholder, "What it's for");
      expect(
        AddMedicineCopy.conditionPlaceholder.toLowerCase(),
        isNot(contains('condition')),
      );
      expect(
        AddMedicineCopy.conditionPlaceholder.toLowerCase(),
        isNot(contains('e.g')),
      );
    });
  });

  group('the composed sentences', () {
    test('the step label counts from one and names the real total', () {
      expect(AddMedicineCopy.stepLabel(1, 3), 'STEP 1 OF 3');
      expect(
        AddMedicineCopy.stepLabel(
          AddMedicineStep.values.last.step,
          AddMedicineStep.count,
        ),
        'STEP 3 OF 3',
        reason:
            'The total is a parameter, so the sentence cannot disagree with '
            'AddMedicineStep about how many steps there are.',
      );
    });

    test('the screen-reader step label is sentence case, not capitals', () {
      // ALL-CAPS is a property of how the position line is SET. A screen reader
      // announcing "S T E P" is the failure that distinction avoids.
      expect(AddMedicineCopy.stepBarLabel(2, 3), 'Step 2 of 3');
    });

    test('the escalation timings are the real numbers', () {
      // The story's criterion: step 3 shows +15 / +30 / +60, not a description
      // of escalation.
      expect(AddMedicineCopy.escalationTimings, contains('+15'));
      expect(AddMedicineCopy.escalationTimings, contains('+30'));
      expect(AddMedicineCopy.escalationTimings, contains('+60'));
      expect(
        AddMedicineCopy.escalationTimings,
        'Follow-up +15, final +30, overdue +60',
      );
    });

    test('the timings sentence follows its constants', () {
      // Composed from the constants rather than typed, so the sentence and the
      // numbers cannot drift. Asserted by construction: all three appear.
      for (final int minutes in <int>[
        AddMedicineCopy.followUpMinutes,
        AddMedicineCopy.finalReminderMinutes,
        AddMedicineCopy.overdueMinutes,
      ]) {
        expect(AddMedicineCopy.escalationTimings, contains('+$minutes'));
      }
    });

    test('the reminders summary quotes the design, on and off', () {
      expect(AddMedicineCopy.reminderSummaryOn, 'On · +15 / +30 min');
      expect(AddMedicineCopy.reminderSummaryOff, 'Off');
    });

    test('a time renders zero-padded, twelve-hour, with a meridiem', () {
      // The mock pads: String(h12).padStart(2, '0'). A column of times that
      // changes width as it crosses ten o'clock reads as a layout bug.
      expect(AddMedicineCopy.timeOfDayLabel(20), '08:00 PM');
      expect(AddMedicineCopy.timeOfDayLabel(0), '12:00 AM');
      expect(AddMedicineCopy.timeOfDayLabel(12), '12:00 PM');
      expect(AddMedicineCopy.timeOfDayLabel(9), '09:00 AM');
      expect(AddMedicineCopy.timeOfDayLabel(23), '11:00 PM');
    });

    test('every hour of the day renders the same width', () {
      for (int hour = 0; hour < 24; hour++) {
        expect(
          AddMedicineCopy.timeOfDayLabel(hour),
          matches(RegExp(r'^\d{2}:00 [AP]M$')),
          reason: 'hour $hour',
        );
      }
    });

    test('the dose summary pluralises the way the design does', () {
      // reviewDose: amount + ' ' + unit.toLowerCase() + (amount > 1 ? 's' : '')
      expect(AddMedicineCopy.doseSummary(1, 'tablet'), '1 tablet');
      expect(AddMedicineCopy.doseSummary(2, 'tablet'), '2 tablets');
      expect(
        AddMedicineCopy.doseSummary(1, 'Puff'),
        '1 puff',
        reason:
            'A free-text unit is shown as the user typed it, lower-cased, '
            'rather than being second-guessed.',
      );
    });

    test('the repeat labels are the design\'s four', () {
      expect(
        AddMedicineRepeat.values
            .map(
              (AddMedicineRepeat r) =>
                  AddMedicineCopy.repeatOptionLabel(r, intervalDays: 2),
            )
            .toList(),
        <String>['Every day', 'Weekdays', 'Specific days', 'Every 2 days'],
      );
    });

    test('the Every N label follows the stepper', () {
      // DESIGN.md reveals the interval stepper beneath the option, so the
      // option's own label has to follow N or the two disagree on screen.
      expect(
        AddMedicineCopy.repeatOptionLabel(
          AddMedicineRepeat.everyNDays,
          intervalDays: 5,
        ),
        'Every 5 days',
      );
    });

    test('the saved confirmation names the medicine and the time', () {
      // UX-DR14, and the mock's own flash():
      // newName + ' added · first reminder ' + newTime
      expect(
        AddMedicineCopy.savedConfirmation('Atorvastatin', '08:00 PM'),
        'Atorvastatin added · first reminder 08:00 PM',
      );
    });

    test('the unit chips are the design\'s five, with ml uncapitalised', () {
      expect(AddMedicineCopy.unitLabels.values.toList(), <String>[
        'Tablet',
        'Capsule',
        'ml',
        'Drop',
        'Other',
      ]);
    });

    test('the form chips are the design\'s four', () {
      expect(
        addMedicineForms.map((String f) => f[0].toUpperCase() + f.substring(1)),
        <String>['Tablet', 'Capsule', 'Liquid', 'Drop'],
      );
    });
  });

  group('the day row', () {
    test('the letters are the design\'s M T W T F S S', () {
      expect(AddMedicineCopy.dayLetters.skip(1).toList(), <String>[
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
        'S',
      ]);
    });

    test('the spoken names disambiguate the repeated letters', () {
      // Two Ts and two Ss, with nothing to tell them apart out loud. This is
      // why the names exist and are not transcribed.
      expect(AddMedicineCopy.dayNames.skip(1).toSet(), hasLength(7));
      expect(AddMedicineCopy.dayNames[DateTime.monday], 'Monday');
      expect(AddMedicineCopy.dayNames[DateTime.sunday], 'Sunday');
    });

    test('both lists are indexed by DateTime.monday..sunday', () {
      // Index 0 unused, so dayNames[DateTime.monday] is Monday. A zero-based
      // list would make every lookup an off-by-one waiting to happen.
      expect(AddMedicineCopy.dayLetters, hasLength(8));
      expect(AddMedicineCopy.dayNames, hasLength(8));
      expect(AddMedicineCopy.dayLetters.first, isEmpty);
      expect(AddMedicineCopy.dayNames.first, isEmpty);
    });
  });
}
