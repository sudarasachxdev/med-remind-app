// Every word the onboarding panels say, in one place.
//
// Gathered here rather than inlined in the widgets for two reasons. The first
// is review: EXPERIENCE.md's Voice and Tone rules -- state the fact, never the
// judgment; no exclamation marks, no encouragement, no clinical phrasing --
// are properties of the *set* of strings, and a rule about a set needs the set
// to exist. `test/onboarding_copy_test.dart` reads [onboardingCopyStrings] and
// checks all of it, which is only possible because it is a list.
//
// The second is provenance. Nothing here is invented, and nothing here is
// composed. Every string is transcribed from the delivered design:
//
//   ~/Downloads/Medication Reminder App Design/MediTracker.dc.html
//
// specifically its `<sc-if value="{{ isOnb }}">` block -- the three `onbA` /
// `onbB` / `onbC` panels -- and the `onbCta` and `onbSkip` expressions in the
// trailing script, which are where the two button labels live.
//
// An earlier pass of this file COMPOSED panel 2's title, panel 3's title and
// panel 2's lead-in, and dropped three of the four timeline notes, because the
// planning repository's `imports/` folder is empty and the file above was
// believed lost. It was one directory away. If a string here ever looks like it
// wants improving, open that file first.
//
// `EXPERIENCE.md` still governs behaviour and voice, and it wins on conflict
// per its own header -- but on wording, where the mock says something, the mock
// is what it says. The only editorial act left in this file is [actionBack],
// which the mock has no control for: `EXPERIENCE.md` requires "Back is always
// available" on the step progress bar, and the story's matrix has two rows
// about it, so the control exists and is named the one word both documents use.

import '../onboarding_panel.dart';

/// The copy of the three onboarding panels.
///
/// Every string below is the delivered design's own wording, transcribed from
/// `~/Downloads/Medication Reminder App Design/MediTracker.dc.html` (the
/// `isOnb` block and the `onbCta`/`onbSkip` expressions in its script). The
/// planning repo's `imports/` folder is empty, which is why an earlier pass of
/// this file composed three of these titles instead — the source was there, one
/// directory away, and had to be pointed at.
abstract final class OnboardingCopy {
  // --- Panel 1: value -------------------------------------------------------

  /// The onboarding lead. The one and only use of `MTTypography.headingXl` in
  /// the product.
  static const String panel1Title = 'Never lose track of a dose';

  /// What the product is for, in the design's own words: the one question it
  /// keeps answered.
  static const String panel1BodyWhatItIs =
      'MediTracker keeps one question answered: what do you need to take '
      'right now?';

  /// Where the data lives.
  ///
  /// The mock sets this and [panel1BodyWhatItIs] as one paragraph. They are two
  /// constants here because they make two claims -- what the app does, and
  /// where the record is kept -- and the second is the one a privacy-conscious
  /// reader is looking for. Rendered as two paragraphs with a spacing step
  /// between them, which is a layout choice, not a rewording: the words and
  /// their order are the mock's.
  static const String panel1BodyPrivacy =
      'Everything stays on this phone. No account, works offline.';

  // --- Panel 2: the escalation explainer ------------------------------------

  /// Panel 2's title.
  static const String panel2Title = 'If you miss a reminder, we catch it';

  /// The lead-in to the timeline.
  static const String panel2Body =
      "A dose you don't answer is never dropped from the record.";

  // --- Panel 3: the permission explainer ------------------------------------

  /// Panel 3's title. Says what notifications are *for* before anything asks
  /// for them, which is the whole reason this panel precedes the OS dialog.
  static const String panel3Title = 'Reminders need notifications';

  /// Why the app wants them.
  static const String panel3BodyWhy =
      'MediTracker uses notifications to tell you when it\'s time to take a '
      'medicine, and to follow up if a dose goes unanswered. That\'s the only '
      'thing they\'re used for.';

  /// That declining is fine.
  ///
  /// This sentence is the reason panel 3 exists, and it is the design's, not a
  /// paraphrase: `EXPERIENCE.md`'s State Patterns row quotes the first half of
  /// it, and the mock adds "and you can turn reminders on later in Settings" --
  /// which matters, because it is the difference between a door left open and a
  /// decision the user believes is final.
  ///
  /// The mock sets it in a tinted card (`#F7F7FB`, radius 16) at 14px. It is
  /// rendered here in the same type and the same ink as the line above it: the
  /// card is a dimension-token decision this story cannot make (see the
  /// deferred list), and of the two available approximations, equal weight is
  /// the safe one. A consequence set smaller and greyer than the pitch is a
  /// consequence being played down.
  static const String panel3BodyDecline =
      'You can decline. The app still works as a manual tracker, and you can '
      'turn reminders on later in Settings.';

  // --- Actions --------------------------------------------------------------

  /// The primary action on panels 1 and 2.
  ///
  /// The mock's `onbCta`: `s.onbStep === 3 ? 'Allow notifications' : 'Continue'`.
  static const String actionContinue = 'Continue';

  /// The secondary action on panels 1 and 2. Leaves for Home immediately.
  ///
  /// The mock's `onbSkip`: `s.onbStep === 3 ? 'Not now' : 'Skip intro'`.
  static const String actionSkipIntro = 'Skip intro';

  /// The primary action on panel 3.
  ///
  /// It does **not** trigger the OS dialog in this story -- there are no
  /// notifications to permit yet. Story 3.1 gives it its real behaviour.
  static const String actionAllowNotifications = 'Allow notifications';

  /// The secondary action on panel 3.
  ///
  /// "Not now", never "Deny" or "No thanks": the first is a door left open and
  /// the other two are a refusal being characterised. It reaches the same Home
  /// as the primary, and the panel has already said the app still works.
  static const String actionNotNow = 'Not now';

  /// Retreats one panel. Present on panels 2 and 3; panel 1 has nothing behind
  /// it, so it shows no Back.
  ///
  /// The one string here the mock does not supply -- it draws no back control
  /// at all. `EXPERIENCE.md`'s Step progress bar row requires one ("Back is
  /// always available") and the story's matrix has two rows about it, so the
  /// spine wins, as its own header says it does.
  static const String actionBack = 'Back';

  /// The step bar's screen-reader label, e.g. `Step 2 of 3`.
  ///
  /// The bar is three flat segments and says nothing out loud on its own, so it
  /// carries this instead of being skipped over.
  static String stepLabel(int step, int total) => 'Step $step of $total';

  /// Every string this feature says, for the Voice and Tone test.
  ///
  /// A getter rather than a constant so [stepLabel] can be rendered at its
  /// three real values: a sentence built at runtime is still a sentence the
  /// user reads, and leaving it out would exempt the only generated string
  /// here from the rules that govern all the others.
  static List<String> get all => <String>[
    panel1Title,
    panel1BodyWhatItIs,
    panel1BodyPrivacy,
    panel2Title,
    panel2Body,
    panel3Title,
    panel3BodyWhy,
    panel3BodyDecline,
    actionContinue,
    actionSkipIntro,
    actionAllowNotifications,
    actionNotNow,
    actionBack,
    for (final OnboardingPanel panel in OnboardingPanel.values)
      stepLabel(panel.step, OnboardingPanel.count),
    for (final EscalationStep step in EscalationStep.values) ...<String>[
      step.head,
      step.note,
    ],
  ];
}

/// The escalation timeline of panel 2, one entry per row.
///
/// The product's argument in one screen: a dose that goes unanswered is
/// followed up, then parked, then still recordable. The last row is the
/// sentence that separates this app from a louder alarm clock, and it stays.
///
/// Transcribed from the mock's four `onbB` rows. Each has a head line at
/// 15px/600 and a second line at 14px in `#8A8AA0`, and all four have both --
/// an earlier pass gave only the last row a second line, which lost "Nudging
/// stops. Resolve it whenever you open the app.", the promise the whole
/// escalation rests on.
enum EscalationStep {
  /// The dose time itself.
  reminder(time: '8:00', label: 'Reminder', note: 'Time for Candesartan'),

  /// The follow-up, softer in wording and still unresolved.
  followUp(
    time: '8:15',
    label: 'Gentle follow-up',
    note: 'Still waiting on this one',
  ),

  /// Follow-ups stop here. The dose stays open; the app stops asking.
  overdue(
    time: '9:00',
    label: 'Marked overdue',
    note: 'Nudging stops. Resolve it whenever you open the app.',
  ),

  /// Hours later, and still recordable.
  taken(
    time: '12:40',
    label: 'Taken',
    note: 'Recorded late, and recorded honestly',
  );

  const EscalationStep({
    required this.time,
    required this.label,
    required this.note,
  });

  /// The wall-clock time of the row.
  final String time;

  /// What happens at that time.
  final String label;

  /// The row's second line. Every row has one; see the enum's doc.
  final String note;

  /// Whether this row is the resolved outcome rather than a pending moment.
  bool get isOutcome => this == taken;

  /// The row's head line, exactly as the mock sets it.
  ///
  /// Three of the four read `{time} · {label}` -- "8:00 · Reminder" -- with
  /// both halves at one weight. The outcome row reads **"Taken at 12:40"**: one
  /// phrase, because that is what the mock draws, and because "12:40 · Taken"
  /// would read as a fifth pending step in the chain rather than as the thing
  /// the chain was for.
  ///
  /// Derived rather than stored per value, so the head and the [time]/[label]
  /// the tests assert on cannot drift apart.
  String get head => isOutcome ? '$label at $time' : '$time · $label';

  /// One label for the whole row, so a screen reader announces it as a sentence
  /// instead of three unrelated fragments.
  ///
  /// Built from the parts rather than from [head], because [head]'s middle dot
  /// is a visual separator: a screen reader either skips it or reads it aloud
  /// as "middle dot", and neither is the sentence.
  String get semanticsLabel {
    final String opening = isOutcome ? '$label at $time' : '$time. $label';
    return '$opening. $note';
  }
}
