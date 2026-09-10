// The dose card, in the three variants this story is scoped to: plain
// (Scheduled), due, and overdue -- `resolve()` on any Epic-1-generated Dose
// can produce only these plus Missed, which this spec's own Boundaries note
// does not practically occur here (Home shows only today's Doses, and Missed
// is a prior-day state).
//
// NOTHING ON ANY VARIANT IS WIRED TO AN ACTION. `DoseRecorder` and the action
// sheet do not exist before Story 2.1/2.2, so the trailing circle on the plain
// and due cards, and the three-action row the overdue card expands to inline
// (UX-DR4), are rendered exactly as the design draws them and respond to
// nothing -- no `onTap`, no `GestureDetector`, and each is excluded from the
// semantics tree rather than announced as a button that does nothing. A
// control that LOOKS actionable and silently is not would be a worse
// accessibility failure than one that is honestly decorative. Story 2.2 wires
// all of this for real.
//
// COLOUR IS NEVER THE ONLY SIGNAL (UX-DR8, NFR-5): every variant's chip
// carries a word, and the overdue card's left border and chip both read from
// `state-late-*`, never red -- DESIGN.md's own note that the delivered mock
// draws `isOverdue` in defective grey is corrected here, not reproduced.
//
// The glyph tile's tint is per-Medicine (AD-22) and is drawn by `GlyphTile`
// alone; only the left border and the chip read from `resolve()` -- the two
// colour systems never mix on one card.

import 'package:flutter/material.dart';

import '../../../domain/model/dose_state.dart';
import '../../../shared/design/design.dart';
import '../application/home_plan_controller.dart';
import 'glyph_tile.dart';
import 'home_copy.dart';

/// One row of Home's dose list.
class DoseCard extends StatelessWidget {
  const DoseCard({required this.entry, super.key});

  /// The Dose, its resolved state, and the two Medicine fields it does not
  /// itself freeze.
  final HomeDoseEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry.resolution.state) {
      DoseState.overdue => _OverdueDoseCard(entry: entry),
      DoseState.due => _PlainOrDueDoseCard(entry: entry, isDue: true),
      // `scheduled` is the ordinary case; any other state reaching here
      // (Missed, or one of Epic 2's states arriving early through a future
      // regression) renders as the neutral, no-border treatment rather than
      // throwing -- Home degrades to a plain card instead of a crash.
      _ => _PlainOrDueDoseCard(entry: entry, isDue: false),
    };
  }
}

/// The accent-left-bordered "due" card and the border-free "plain"
/// (Scheduled) card -- one widget, because the two differ only in colour and
/// elevation, never in shape.
class _PlainOrDueDoseCard extends StatelessWidget {
  const _PlainOrDueDoseCard({required this.entry, required this.isDue});

  final HomeDoseEntry entry;
  final bool isDue;

  /// The mock's own left-border width on both the due and the overdue card.
  /// Single-use, like `GlyphTile`'s own marks -- see that file's comment.
  static const double _accentBarWidth = 4;

  @override
  Widget build(BuildContext context) {
    final Color? borderColor = isDue ? MTColors.accent : null;
    final List<BoxShadow> shadow = <BoxShadow>[
      isDue ? MTElevation.raisedStrong : MTElevation.raised,
    ];
    final Color chipBg = isDue
        ? MTColors.accentWash
        : MTColors.stateNeutralTile;
    // `accentInk`, not `accent`: DESIGN.md's own 2026-09-06 contrast pass
    // exists precisely because `accent` text on `accentWash` fails AA at chip
    // size (4.15:1) -- `accentInk` is the corrected reading colour for that
    // exact pairing.
    final Color chipInk = isDue ? MTColors.accentInk : MTColors.inkMuted;
    final String chipText = isDue ? HomeCopy.stateDue : HomeCopy.stateScheduled;
    final String stateWord = isDue
        ? HomeCopy.stateDue
        : HomeCopy.stateScheduled;

    return Semantics(
      label: _cardLabel(entry, stateWord),
      // `excludeSemantics`, not `container`: this label must be the ONLY
      // semantics node the card contributes. `container` alone would still
      // let the name/meta/chip `Text` widgets below each add their own node,
      // so a screen reader would hear this sentence and then every fragment
      // of it a second time.
      excludeSemantics: true,
      child: DecoratedBox(
        // The shadow and the radius live here, ALONE: `boxShadow` plus
        // `borderRadius` needs no border on this same decoration, so nothing
        // here fights Flutter's "a borderRadius needs a uniform border" rule.
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
          boxShadow: shadow,
        ),
        child: ClipRRect(
          // Rounds the fill and the one-sided border below into the same
          // silhouette the shadow already casts, without either of them
          // needing to declare a radius of their own.
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MTColors.surfaceRaised,
              // The left accent bar: a `Border` with only one side set, and
              // no `borderRadius` on this decoration at all -- the restriction
              // that forced a three-layer Row+stretch design in an earlier
              // pass only applies when a border and a radius share ONE
              // decoration. Here the `ClipRRect` above already owns the
              // rounding, so this border can be as uneven as it likes.
              border: borderColor == null
                  ? null
                  : Border(
                      left: BorderSide(
                        width: _accentBarWidth,
                        color: borderColor,
                      ),
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(MTSpacing.s3),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: GlyphTile(glyphIndex: entry.glyphIndex),
                  ),
                  const SizedBox(width: MTSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.dose.medicineName,
                          style: MTTypography.title.copyWith(
                            color: MTColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: MTSpacing.s1),
                        Text(
                          HomeCopy.metaLine(
                            condition: entry.condition,
                            amount: entry.dose.dosageAmount,
                            unit: entry.dose.dosageUnit,
                          ),
                          style: MTTypography.meta.copyWith(
                            color: MTColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: MTSpacing.s2),
                        _StatusChip(
                          text: chipText,
                          background: chipBg,
                          ink: chipInk,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MTSpacing.s3),
                  // Decorative only -- see the file comment. Story 2.2 wires
                  // the real tap.
                  ExcludeSemantics(child: _TrailingCircle(isDue: isDue)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The overdue card: amber, no left-border colour reuse from the due card
/// (state-late, never accent), and the three inline actions rendered as
/// decoration only.
class _OverdueDoseCard extends StatelessWidget {
  const _OverdueDoseCard({required this.entry});

  final HomeDoseEntry entry;

  static const double _accentBarWidth = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _cardLabel(entry, 'Overdue'),
      // See `_PlainOrDueDoseCard` for why this is `excludeSemantics`, not
      // `container`.
      excludeSemantics: true,
      child: DecoratedBox(
        // See `_PlainOrDueDoseCard` for why the shadow/radius and the
        // one-sided border live on two different decorations.
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MTRadius.lg)),
          boxShadow: <BoxShadow>[MTElevation.raisedStrong],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MTColors.surfaceRaised,
              border: Border(
                left: BorderSide(
                  width: _accentBarWidth,
                  color: MTColors.stateLateMark,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(MTSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: GlyphTile(glyphIndex: entry.glyphIndex),
                      ),
                      const SizedBox(width: MTSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.dose.medicineName,
                              style: MTTypography.title.copyWith(
                                color: MTColors.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: MTSpacing.s1),
                            Text(
                              HomeCopy.metaLine(
                                condition: entry.condition,
                                amount: entry.dose.dosageAmount,
                                unit: entry.dose.dosageUnit,
                              ),
                              style: MTTypography.meta.copyWith(
                                color: MTColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: MTSpacing.s2),
                            _StatusChip(
                              text: HomeCopy.stateOverdue(
                                entry.dose.scheduledLocal,
                              ),
                              background: MTColors.stateLateTile,
                              ink: MTColors.stateLateMark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MTSpacing.s3),
                  // Visual only: DoseRecorder and the action sheet
                  // (Story 2.2) do not exist yet. No tap handler is wired to
                  // any of the three rows, and the whole group is excluded
                  // from semantics rather than announced as three buttons
                  // that do nothing.
                  ExcludeSemantics(child: _OverdueActionsRow()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three inline actions the overdue card expands to (UX-DR4, UX-DR13's
/// fixed priority order) -- decorative, per the file comment.
class _OverdueActionsRow extends StatelessWidget {
  const _OverdueActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _ActionPill(
            label: '✓ I took it',
            background: MTColors.accent,
            ink: MTColors.surfaceRaised,
          ),
        ),
        const SizedBox(width: MTSpacing.s2),
        Expanded(
          child: _ActionPill(
            label: 'Snooze',
            background: MTColors.surfaceMuted,
            ink: MTColors.inkSecondary,
          ),
        ),
        const SizedBox(width: MTSpacing.s2),
        Expanded(
          child: _ActionPill(
            label: 'Skip',
            background: MTColors.surfaceApp,
            ink: MTColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.background,
    required this.ink,
  });

  final String label;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
      ),
      child: ConstrainedBox(
        // UX-DR20: "the three-action overdue card is the tightest layout --
        // it must not compress below" the 44pt/48dp floor. Nothing here is
        // wired to a tap yet (Story 2.2), but the floor is a layout property,
        // not a behavioural one, and this row must already hold it so wiring
        // the action later is not also a resize.
        constraints: const BoxConstraints(
          minHeight: MTDimensions.touchMinAndroid,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MTSpacing.s2),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: MTTypography.body.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing decorative control on the plain and due cards -- an outline
/// chevron on plain, a filled accent check on due, neither wired to anything.
class _TrailingCircle extends StatelessWidget {
  const _TrailingCircle({required this.isDue});

  final bool isDue;

  /// `touchMinAndroid`, not the mock's own smaller literal: UX-DR20's floor
  /// applies to every dose action, and this circle is the one Story 2.2 wires
  /// to open the action sheet. Sizing it to the floor now means wiring the
  /// tap later is not also a resize.
  static const double _size = MTDimensions.touchMinAndroid;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDue ? MTColors.accent : null,
        shape: BoxShape.circle,
        border: isDue ? null : Border.all(color: MTColors.borderStrong),
      ),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Icon(
          isDue ? Icons.check : Icons.chevron_right,
          size: _iconSize,
          color: isDue ? MTColors.surfaceRaised : MTColors.inkDisabled,
        ),
      ),
    );
  }
}

/// The rounded-`xs` status chip every variant carries -- a word, never colour
/// alone (UX-DR8, NFR-5).
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.background,
    required this.ink,
  });

  final String text;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(MTRadius.xs)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpacing.s2,
          vertical: MTSpacing.s1,
        ),
        child: Text(text, style: MTTypography.chip.copyWith(color: ink)),
      ),
    );
  }
}

/// One announced label per card (UX-DR20): medicine, dose, scheduled time and
/// state, as one sentence.
String _cardLabel(HomeDoseEntry entry, String stateWord) {
  final String meta = HomeCopy.metaLine(
    condition: entry.condition,
    amount: entry.dose.dosageAmount,
    unit: entry.dose.dosageUnit,
  );
  final String time = HomeCopy.timeLabel(entry.dose.scheduledLocal);
  return '${entry.dose.medicineName}. $meta. $time. $stateWord.';
}
