// Home's copy, against EXPERIENCE.md's Voice and Tone rules.
//
// The same two jobs `add_medicine_copy_test.dart` and `onboarding_copy_test.dart`
// already do for their own screens: run the shared rules over the whole set
// (`support/voice_rules.dart`, extracted in Story 1.5 so a phrase banned on one
// screen cannot quietly go unchecked on another), and pin the handful of
// strings this screen composes rather than transcribes, so the reason survives
// alongside the string.
//
// UX-DR19 binds Home exactly as it binds onboarding and the add flow. Nothing
// checked that here until this file existed.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/features/home/presentation/home_copy.dart';

import 'support/voice_rules.dart';

void main() {
  group('Voice and Tone', () {
    test('there is copy to check', () {
      expect(HomeCopy.all.length, greaterThan(8));
    });

    test('no exclamation mark anywhere', () {
      for (final String copy in HomeCopy.all) {
        expect(copy, isNot(contains('!')), reason: '"$copy"');
      }
    });

    test('no encouragement and no streak language', () {
      for (final String copy in HomeCopy.all) {
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
      for (final String copy in HomeCopy.all) {
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
      for (final String copy in HomeCopy.all) {
        for (final String banned in judgementalWords) {
          expect(
            copy.toLowerCase(),
            isNot(contains(banned)),
            reason: '"$banned" judges a legitimate choice: "$copy"',
          );
        }
      }
    });

    test('the overdue banner states the fact, not a time of day it does not '
        'know', () {
      // The one place this file diverges from the mock's own words: "waiting
      // from this morning" asserts a time of day an overdue dose need not
      // have. Pinned here so a future edit cannot quietly reintroduce it.
      expect(HomeCopy.overdueBannerTitle(1), isNot(contains('morning')));
      expect(HomeCopy.overdueBannerTitle(1), contains('earlier today'));
    });
  });

  group('the greeting', () {
    test('is time-of-day only -- no name, no emoji (resolved 2026-09-10)', () {
      for (final String greeting in <String>[
        HomeCopy.greetingFor(DateTime(2026, 1, 1, 6)),
        HomeCopy.greetingFor(DateTime(2026, 1, 1, 13)),
        HomeCopy.greetingFor(DateTime(2026, 1, 1, 19)),
      ]) {
        expect(
          greeting,
          isNot(contains(RegExp(r'[^\x00-\x7F]'))),
          reason: 'no emoji: "$greeting"',
        );
      }
    });

    test('covers morning, afternoon and evening distinctly', () {
      expect(HomeCopy.greetingFor(DateTime(2026, 1, 1, 6)), 'Good morning');
      expect(HomeCopy.greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(HomeCopy.greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
    });
  });

  group('pluralisation', () {
    test('the overdue banner counts correctly', () {
      expect(
        HomeCopy.overdueBannerTitle(1),
        '1 dose is waiting from earlier today',
      );
      expect(
        HomeCopy.overdueBannerTitle(2),
        '2 doses are waiting from earlier today',
      );
      expect(HomeCopy.overdueBannerBody(1), contains('it.'));
      expect(HomeCopy.overdueBannerBody(2), contains('them.'));
    });

    test('the progress and meta lines pluralise the dose amount', () {
      expect(HomeCopy.doseSummary(1, 'tablet'), '1 tablet');
      expect(HomeCopy.doseSummary(2, 'tablet'), '2 tablets');
      expect(HomeCopy.progressLabel(1, 3), '1 of 3 doses taken');
    });
  });
}
