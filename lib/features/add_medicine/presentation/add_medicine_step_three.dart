// Step 3 -- reminders, the review, and Save.
//
// The reminders toggle with its real timings, the summary tile, the four review
// rows, and the footnote.
//
// THE TIMINGS ARE THE VALUES, NOT A DESCRIPTION OF THEM. The second line of the
// reminders row reads `Follow-up +15, final +30, overdue +60`, composed in
// `add_medicine_copy.dart` from three named constants. The story's acceptance
// criterion is exactly this: "when step 3 renders, then the escalation timings
// appear as the real values +15 / +30 / +60 rather than as a description of
// escalation." Onboarding's panel 2 makes the same promise about the same
// mechanism, and this is the second place the product keeps it.
//
// THE TOGGLE RECORDS INTENT AND NOTHING ELSE. Epic 3 owns notification
// scheduling; nothing in this feature imports a notification package, which is
// the only durable form of that promise and is enforced by
// `test/story_scope_test.dart`.
//
// TOKENS, as measured from the `st3` block of the delivered design:
//   * the reminders card: `surfaceRaised` at `2xl` 20 with a `borderHairline`
//     edge, its two rows separated by a `surfaceInset` hairline;
//   * the toggle: `toggle-track` 51x31 and `toggle-knob` 27 with
//     `elevation/knob`, `accent` when on and `borderStrong` when off, moving in
//     `motion/quick` -- and not moving at all under Reduce Motion;
//   * the summary tile: `control-md` 46 at `md` 14 on `accentWash`;
//   * the review card: `surfaceApp` at `2xl` 20, rows separated by
//     `translucency/hairline-on-ink`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design/design.dart';
import '../application/add_medicine_controller.dart';
import '../domain/add_medicine_draft.dart';
import 'add_medicine_controls.dart';
import 'add_medicine_copy.dart';

/// The third step's body.
class AddMedicineStepThree extends ConsumerWidget {
  const AddMedicineStepThree({required this.draft, super.key});

  /// Everything entered so far.
  final AddMedicineDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddMedicineController controller = ref.read(
      addMedicineControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AddMedicineStepHeading(AddMedicineCopy.stepThreeHeading),
        const SizedBox(height: MTSpacing.s4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: MTColors.surfaceRaised,
            borderRadius: const BorderRadius.all(Radius.circular(MTRadius.xl2)),
            border: Border.all(color: MTColors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _RemindersRow(
                enabled: draft.remindersEnabled,
                onToggled: () =>
                    controller.setReminders(enabled: !draft.remindersEnabled),
              ),
              _SummaryTile(draft: draft),
            ],
          ),
        ),
        const SizedBox(height: MTSpacing.s3),
        _ReviewCard(draft: draft),
        const SizedBox(height: MTSpacing.s3),
        Text(
          AddMedicineCopy.stepThreeFootnote,
          style: MTTypography.body.copyWith(color: MTColors.inkFaint),
        ),
      ],
    );
  }
}

/// The reminders row: a title, the escalation timings, and the toggle.
///
/// The WHOLE ROW is the control. One `Semantics` node carrying both lines and
/// the toggled state, because three nodes -- a title, a sentence of offsets and
/// an unlabelled track -- read as fragments, and because a separate node
/// labelled `Reminder enabled` beside a `Text` reading the same words is two
/// announcements of one control. `EscalationTimeline` merges its rows for the
/// same reason.
class _RemindersRow extends StatelessWidget {
  const _RemindersRow({required this.enabled, required this.onToggled});

  final bool enabled;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      label:
          '${AddMedicineCopy.reminderEnabled}. '
          '${AddMedicineCopy.escalationTimings}',
      onTap: onToggled,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onToggled,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MTColors.surfaceInset)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpacing.s4,
              vertical: MTSpacing.s4,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AddMedicineCopy.reminderEnabled,
                        style: MTTypography.title.copyWith(
                          color: MTColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: MTSpacing.s1),
                      Text(
                        AddMedicineCopy.escalationTimings,
                        style: MTTypography.meta.copyWith(
                          color: MTColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MTSpacing.s3),
                _ReminderToggle(enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The toggle itself. Painted, not interactive: the row above it owns the tap
/// and the semantics, so this cannot become a second control with the same
/// meaning.
class _ReminderToggle extends StatelessWidget {
  const _ReminderToggle({required this.enabled});

  final bool enabled;

  /// The knob's inset from the track, derived rather than declared.
  ///
  /// `toggle-knob` 27 inside `toggle-track` 31 leaves two logical pixels on
  /// each side, which is the inset `MTDimensions.toggleKnob`'s own doc names.
  /// Computed from the two tokens so that a change to either keeps the knob
  /// centred instead of leaving a number here that used to be right.
  static double get _inset =>
      (MTDimensions.toggleTrackHeight - MTDimensions.toggleKnob) / 2;

  /// How far the knob travels: the track's width less the knob and both
  /// insets. 20 logical pixels, which is DESIGN.md's own "22px knob travel"
  /// measured as the knob's left edge moving from 2 to 22.
  static double get _travel =>
      MTDimensions.toggleTrackWidth - MTDimensions.toggleKnob - _inset * 2;

  @override
  Widget build(BuildContext context) {
    // Reduce Motion is a value in the token layer, not a local branch:
    // `MTMotion.reduceMotion` IS the declared policy ("every duration collapses
    // to zero; the final position renders immediately"). The knob still moves
    // to its new position -- it simply does not travel, which is the
    // distinction DESIGN.md draws between reduced motion and no animation.
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? MTMotion.reduceMotion
        : MTMotion.quick;

    return SizedBox(
      width: MTDimensions.toggleTrackWidth,
      height: MTDimensions.toggleTrackHeight,
      child: AnimatedContainer(
        duration: duration,
        curve: MTMotion.easingStandard,
        decoration: BoxDecoration(
          color: enabled ? MTColors.accent : MTColors.borderStrong,
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.pill)),
        ),
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: duration,
              curve: MTMotion.easingStandard,
              top: _inset,
              left: enabled ? _inset + _travel : _inset,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: MTColors.surfaceRaised,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[MTElevation.knob],
                ),
                child: SizedBox(
                  width: MTDimensions.toggleKnob,
                  height: MTDimensions.toggleKnob,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The medicine, as it will be saved: its glyph tile, its name, and its dose.
///
/// The tile is `accentWash` with an `accent` glyph. It is NOT the per-medicine
/// glyph AD-22 assigns: that index is minted inside the repository at the
/// moment of the write, so nothing before Save can know it, and rendering a
/// guess here would be showing the user a silhouette their medicine may not
/// get. One neutral accent tile is the honest placeholder.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.draft});

  final AddMedicineDraft draft;

  /// The tile glyph's size -- a single-use measurement inside one component,
  /// which is where DESIGN.md's `dimensions` note puts an icon inset.
  static const double _glyphSize = 26;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpacing.s4,
        vertical: MTSpacing.s4,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: MTDimensions.controlMd,
            height: MTDimensions.controlMd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MTColors.accentWash,
                borderRadius: BorderRadius.all(Radius.circular(MTRadius.md)),
              ),
              child: Center(
                child: Icon(
                  Icons.medication,
                  size: _glyphSize,
                  color: MTColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: MTSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  draft.trimmedName,
                  style: MTTypography.title.copyWith(
                    color: MTColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: MTSpacing.s1),
                Text(
                  AddMedicineCopy.doseSummary(draft.amount, draft.resolvedUnit),
                  style: MTTypography.meta.copyWith(color: MTColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four review rows: what will be written, in the mock's own order.
///
/// No condition row and no dose row: the mock lists Time, Repeat, Reminders and
/// Starts, and the dose is already on the summary tile above. `Starts` says
/// `Today` rather than a formatted date, because FR-1's start date is read from
/// the clock at the moment of saving and this screen has not read it.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.draft});

  final AddMedicineDraft draft;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      (
        AddMedicineCopy.reviewTimeLabel,
        AddMedicineCopy.timeOfDayLabel(draft.hourOfDay),
      ),
      (
        AddMedicineCopy.reviewRepeatLabel,
        AddMedicineCopy.repeatOptionLabel(
          draft.repeat,
          intervalDays: draft.intervalDays,
        ),
      ),
      (
        AddMedicineCopy.reviewRemindersLabel,
        draft.remindersEnabled
            ? AddMedicineCopy.reminderSummaryOn
            : AddMedicineCopy.reminderSummaryOff,
      ),
      (AddMedicineCopy.reviewStartsLabel, AddMedicineCopy.reviewStartsValue),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MTColors.surfaceApp,
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (int index, (String, String) row) in rows.indexed)
              _ReviewRow(
                label: row.$1,
                value: row.$2,
                // The mock draws a hairline above every row but the first, so
                // the card's own top edge is not doubled.
                separated: index > 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.separated,
  });

  final String label;
  final String value;
  final bool separated;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: separated
              ? const Border(
                  top: BorderSide(color: MTTranslucency.hairlineOnInk),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MTSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Both halves flexible, so at a large text size the row grows
              // taller instead of wider. A fixed label with a `spaceBetween`
              // value overflows the moment either side outgrows its half.
              Expanded(
                child: Text(
                  label,
                  style: MTTypography.body.copyWith(color: MTColors.inkMuted),
                ),
              ),
              const SizedBox(width: MTSpacing.s3),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: MTTypography.body.copyWith(
                    color: MTColors.inkPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
