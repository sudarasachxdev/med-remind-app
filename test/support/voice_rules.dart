// EXPERIENCE.md's Voice and Tone rules, as lists a test can run.
//
// Shared, because they are the PRODUCT's rules and not one screen's. They lived
// in `onboarding_copy_test.dart` until 2026-09-08, when the add-medicine flow
// needed the same checks -- and a second copy of a forty-phrase rulebook drifts
// silently: the day someone adds "streak" to one list and not the other, half
// the product is guarded and nobody can tell which half.
//
// "State the fact, never the judgment" is not checkable by machine. The rules it
// is spelled out with are: no exclamation marks, no encouragement, no streak
// language, no clinical phrasing, and declining never framed as the lesser
// choice.

/// Words that praise, urge or scold. EXPERIENCE.md's "Don't" column, made
/// concrete: encouragement, streak language, and the imperative nagging that
/// "Don't forget again" is the archetype of.
const List<String> encouragementWords = <String>[
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
const List<String> clinicalWords = <String>[
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
const List<String> judgementalWords = <String>[
  'deny',
  'no thanks',
  'not recommended',
  'reduced',
  'limited experience',
  'won\'t work',
  'will not work',
  'miss out',
];
