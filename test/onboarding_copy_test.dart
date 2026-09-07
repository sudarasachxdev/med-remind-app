// The onboarding copy, against EXPERIENCE.md's Voice and Tone rules.
//
// "State the fact, never the judgment" is not checkable by machine, but the
// rules it is spelled out with are: sentence case, plain words, complete
// sentences, no exclamation marks, no encouragement, no streak language, no
// clinical phrasing -- and declining never framed as the lesser choice.
//
// The value of this test is not that it catches today's copy (today's copy is
// right). It is that the next person to touch a string has to pass it, and the
// rules are written down here instead of living in a reviewer's memory.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/features/onboarding/presentation/onboarding_copy.dart';

/// Words that praise, urge or scold. EXPERIENCE.md's "Don't" column, made
/// concrete: encouragement, streak language, and the imperative nagging that
/// "Don't forget again" is the archetype of.
const List<String> _encouragement = <String>[
  'amazing',
  'awesome',
  'badge',
  'congrat',
  'don\'t forget',
  'excellent',
  'fantastic',
  'good job',
  'great',
  'keep going',
  'keep it up',
  'nice work',
  'perfect',
  'point',
  'proud',
  'reward',
  'score',
  'streak',
  'success',
  'well done',
  'you can do it',
];

/// Clinical vocabulary. The product records what the user tells it and gives no
/// medical advice, so it must not talk like a chart.
const List<String> _clinical = <String>[
  'adherence',
  'administer',
  'clinical',
  'compliance',
  'contraindicat',
  'diagnos',
  'dosage regimen',
  'patient',
  'prescrib',
  'prescription',
  'regimen',
  'symptom',
  'therapy',
  'treatment plan',
];

/// Words that characterise a refusal. Declining notifications is a legitimate
/// choice and must never be labelled as a failure to do the right thing.
const List<String> _judgesDeclining = <String>[
  'deny',
  'no thanks',
  'not recommended',
  'reduced',
  'limited experience',
  'won\'t work',
  'will not work',
  'miss out',
];

/// The strings that are prose, and therefore must be complete sentences.
/// Button labels, times and row labels are not.
List<String> _paragraphs() => <String>[
  OnboardingCopy.panel1BodyWhatItIs,
  OnboardingCopy.panel1BodyPrivacy,
  OnboardingCopy.panel2Body,
  OnboardingCopy.panel3BodyWhy,
  OnboardingCopy.panel3BodyDecline,
];

// Timeline row notes are deliberately NOT paragraphs. They are captions beside
// a time -- "Time for Candesartan", "Still waiting on this one" -- and the
// delivered design writes them without terminal punctuation. Holding a caption
// to the complete-sentence rule would mean adding full stops the design does
// not have. They are still covered by every other Voice check, which runs over
// OnboardingCopy.all.

void main() {
  group('Voice and Tone', () {
    test('there is copy to check', () {
      // A guard that policed an empty set would pass for the wrong reason.
      expect(OnboardingCopy.all.length, greaterThan(15));
    });

    test('no exclamation mark anywhere', () {
      for (final String copy in OnboardingCopy.all) {
        expect(
          copy,
          isNot(contains('!')),
          reason: 'EXPERIENCE.md bans exclamation marks: "$copy"',
        );
      }
    });

    test('no encouragement and no streak language', () {
      for (final String copy in OnboardingCopy.all) {
        final String lower = copy.toLowerCase();
        for (final String banned in _encouragement) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: '"$banned" is encouragement or gamification: "$copy"',
          );
        }
      }
    });

    test('no clinical phrasing', () {
      for (final String copy in OnboardingCopy.all) {
        final String lower = copy.toLowerCase();
        for (final String banned in _clinical) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: '"$banned" is clinical phrasing: "$copy"',
          );
        }
      }
    });

    test('declining is never framed as the lesser choice', () {
      for (final String copy in OnboardingCopy.all) {
        final String lower = copy.toLowerCase();
        for (final String banned in _judgesDeclining) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: '"$banned" characterises a refusal: "$copy"',
          );
        }
      }

      // The secondary action is a door left open, and the panel says outright
      // that the app still works. Both halves matter: "Not now" alone would
      // leave the consequence unstated.
      expect(OnboardingCopy.actionNotNow, 'Not now');
      expect(
        OnboardingCopy.panel3BodyDecline,
        'You can decline. The app still works as a manual tracker, and you can '
        'turn reminders on later in Settings.',
      );
    });

    test('sentence case, never title case and never all caps', () {
      for (final String copy in OnboardingCopy.all) {
        // A string with no letters -- a clock time -- is neither upper nor
        // lower case, and comparing it with its own uppercase would fail it
        // for having no case at all.
        if (!copy.contains(RegExp('[A-Za-z]'))) continue;
        expect(
          copy,
          isNot(equals(copy.toUpperCase())),
          reason:
              'ALL-CAPS is reserved for the four form labels DOSAGE, '
              'SCHEDULES, REMINDERS and DATA: "$copy"',
        );
        expect(
          _titleCasedWords(copy),
          isEmpty,
          reason:
              'Sentence case: ${_titleCasedWords(copy)} is capitalised '
              'mid-sentence in "$copy"',
        );
      }
    });

    test('prose is complete sentences', () {
      for (final String paragraph in _paragraphs()) {
        expect(
          paragraph,
          anyOf(endsWith('.'), endsWith('?')),
          reason:
              'EXPERIENCE.md asks for complete sentences, which includes a '
              'question -- panel 1 opens by asking the one the product answers: '
              '"$paragraph"',
        );
        expect(paragraph.split(' ').length, greaterThan(3));
      }
    });
  });

  group('the panels say what the design says', () {
    test('panel 1 leads with the value and states where data lives', () {
      expect(OnboardingCopy.panel1Title, 'Never lose track of a dose');
      expect(
        OnboardingCopy.panel1BodyPrivacy,
        'Everything stays on this phone. No account, works offline.',
      );
    });

    test('panel 2 draws the escalation as four concrete moments', () {
      expect(
        EscalationStep.values.map((EscalationStep s) => s.time).toList(),
        equals(<String>['8:00', '8:15', '9:00', '12:40']),
      );
      expect(
        EscalationStep.values.map((EscalationStep s) => s.label).toList(),
        equals(<String>[
          'Reminder',
          'Gentle follow-up',
          'Marked overdue',
          'Taken',
        ]),
      );
      // Every row carries the design's own second line, not just the last.
      // "Nudging stops. Resolve it whenever you open the app." is the promise
      // the whole escalation rests on, and an earlier pass dropped it.
      expect(
        EscalationStep.values.map((EscalationStep s) => s.note).toList(),
        equals(<String>[
          'Time for Candesartan',
          'Still waiting on this one',
          'Nudging stops. Resolve it whenever you open the app.',
          'Recorded late, and recorded honestly',
        ]),
      );
    });

    test('the last line of the timeline is kept', () {
      // The sentence that distinguishes this app from a louder alarm clock. It
      // is called out by name in the story's Design Notes: "Keep that last
      // line."
      expect(
        EscalationStep.values.last.note,
        'Recorded late, and recorded honestly',
      );
    });

    test('every step carries the design\'s own second line', () {
      // An earlier pass gave only the last row a note. The delivered design
      // gives all four one, and the third -- "Nudging stops. Resolve it
      // whenever you open the app." -- is the promise the escalation rests on.
      for (final EscalationStep step in EscalationStep.values) {
        expect(
          step.note,
          isNotEmpty,
          reason: '${step.name} lost its second line',
        );
      }
    });

    test('the head line reads as the mock sets it', () {
      // The three pending moments are `{time} · {label}`; the outcome is one
      // phrase. An earlier version split every row into a 17px time and a 13px
      // muted label, which set the thing the whole chain exists to reach in the
      // smaller and greyer of the two styles.
      expect(
        EscalationStep.values.map((EscalationStep s) => s.head).toList(),
        equals(<String>[
          '8:00 \u00B7 Reminder',
          '8:15 \u00B7 Gentle follow-up',
          '9:00 \u00B7 Marked overdue',
          'Taken at 12:40',
        ]),
      );

      // Only the resolved row is written as a phrase, and it is the last one.
      expect(
        EscalationStep.values.where((EscalationStep s) => s.isOutcome),
        equals(<EscalationStep>[EscalationStep.taken]),
      );
    });

    test('the head line and its parts cannot drift apart', () {
      // `head` is derived rather than stored, so this pins the derivation
      // rather than a second copy of the strings.
      for (final EscalationStep step in EscalationStep.values) {
        expect(step.head, contains(step.time));
        expect(step.head, contains(step.label));
      }
    });

    test('a timeline row reads as one sentence to a screen reader', () {
      // Built from the parts, not from `head`: a screen reader either skips a
      // middle dot or announces it as "middle dot", and neither is a sentence.
      expect(
        EscalationStep.reminder.semanticsLabel,
        '8:00. Reminder. Time for Candesartan',
      );
      expect(
        EscalationStep.taken.semanticsLabel,
        'Taken at 12:40. Recorded late, and recorded honestly',
      );
      for (final EscalationStep step in EscalationStep.values) {
        expect(
          step.semanticsLabel,
          isNot(contains('\u00B7')),
          reason: '${step.name} would have its separator read aloud',
        );
      }
    });

    test('panel 3 names its two actions exactly', () {
      expect(
        OnboardingCopy.actionAllowNotifications,
        'Allow notifications',
        reason: 'the primary action of panel 3, per the story matrix',
      );
      expect(OnboardingCopy.actionNotNow, 'Not now');
    });

    test('the earlier panels offer Continue and Skip intro', () {
      expect(OnboardingCopy.actionContinue, 'Continue');
      expect(OnboardingCopy.actionSkipIntro, 'Skip intro');
    });

    test('the step label counts from one', () {
      expect(OnboardingCopy.stepLabel(1, 3), 'Step 1 of 3');
      expect(OnboardingCopy.stepLabel(3, 3), 'Step 3 of 3');
    });
  });
}

/// Words that are capitalised where sentence case would not capitalise them.
///
/// A word may be capitalised when it opens the string, when it follows a
/// sentence terminator, or when it is the product's own name. Everything else
/// capitalised mid-sentence is title case, which the Voice rules exclude.
/// Words that are legitimately capitalised mid-sentence.
const Set<String> _properNouns = {'MediTracker', 'Settings', 'Candesartan'};

List<String> _titleCasedWords(String copy) {
  final List<String> words = copy.split(RegExp(r'\s+'));
  final List<String> offenders = <String>[];

  for (int i = 1; i < words.length; i++) {
    final String word = words[i];
    if (word.isEmpty) continue;
    final String first = word[0];
    if (first.toLowerCase() == first) continue;
    // Proper nouns are capitalised mid-sentence in correct sentence case.
    // `MediTracker` was already exempt; `Settings` names a screen of this app
    // and `Candesartan` is a medicine name, both from the delivered design's
    // own copy. This is not a relaxation of the rule -- title case means
    // Capitalising Ordinary Words, which is still caught.
    if (_properNouns.any(word.startsWith)) continue;

    final String previous = words[i - 1];
    final bool afterSentenceEnd =
        previous.endsWith('.') ||
        previous.endsWith('?') ||
        previous.endsWith(':');
    if (afterSentenceEnd) continue;
    // The timeline's head line is `8:00 · Reminder`. The middle dot is a
    // separator between two fields, not punctuation inside a sentence, so the
    // field after it starts a new phrase and is capitalised as one.
    if (previous == '\u00B7') continue;

    offenders.add(word);
  }
  return offenders;
}
