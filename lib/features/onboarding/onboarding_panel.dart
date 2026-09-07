// The three onboarding panels, as a closed set.
//
// An enum rather than an `int` index, so that "which panel is showing" cannot
// hold a fourth value, the step bar cannot disagree with the content about how
// many steps there are, and the ordering lives in one place instead of being
// re-derived with `+ 1` at each call site.

/// The onboarding panels, in the order they are shown.
///
/// EXPERIENCE.md's information architecture names the sequence: *value ->
/// escalation explainer -> notification permission*. These are those three.
enum OnboardingPanel {
  /// Panel 1 -- what MediTracker is, and that it stays on the phone.
  value,

  /// Panel 2 -- the escalation chain, drawn as a concrete timeline. The
  /// product's differentiator, and the panel the whole story exists for.
  escalation,

  /// Panel 3 -- why reminders need notifications, and that declining is fine.
  ///
  /// It explains only. Triggering the OS dialog belongs to Story 3.1, where
  /// notifications exist to be permitted.
  permission;

  /// How many panels there are. The step bar's segment count.
  static int get count => values.length;

  /// This panel's 1-based position, for `Step 2 of 3`.
  int get step => index + 1;

  /// Whether this is the first panel. Nothing sits behind it: Back is not
  /// offered, and a system back gesture must retreat to nothing rather than
  /// leave the app.
  bool get isFirst => index == 0;

  /// Whether this is the last panel -- the one whose actions reach Home.
  bool get isLast => index == values.length - 1;

  /// The panel before this one, or `null` on the first.
  OnboardingPanel? get previous => isFirst ? null : values[index - 1];

  /// The panel after this one, or `null` on the last.
  OnboardingPanel? get next => isLast ? null : values[index + 1];
}
