// The dose card, in the three variants this story is scoped to: plain
// (Scheduled), due, and overdue -- `resolve()` on any Epic-1-generated Dose
// can produce only these plus Missed, which this spec's own Boundaries note
// does not practically occur here (Home shows only today's Doses, and Missed
// is a prior-day state).
//
// STORY 2.2 WIRES BOTH ENTRY POINTS TO `DoseRecorder`, deliberately not the
// same shape: the plain/due trailing control opens `DoseActionSheet`
// (`lib/shared/widgets/`) and acts nowhere else on this card, while the
// overdue row's three pills call `DoseRecorder` directly, with no sheet in
// between -- EXPERIENCE.md's own explicit rule that the overdue variant is
// "the one dose state that never requires a second tap to resolve", not an
// inconsistency this story reconciles. Only the trailing control (plain/due)
// and the three pills (overdue) are tappable; the rest of a card's surface
// still does nothing, exactly as the mock's own `onClick` wiring draws it.
//
// A card's own `Semantics` node stays the ONE thing a screen reader
// announces (`excludeSemantics: true`, unchanged from Epic 1); the plain/due
// variant's node additionally carries `button: true` and the sheet-opening
// `onTap`, since touch exploration would otherwise never reach the small
// GestureDetector nested inside an excluded subtree. The overdue row drops
// its `ExcludeSemantics` wrapper entirely -- its three pills are now real,
// individually-labelled controls, not decoration silently announced as
// nothing.
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dose_recorder_provider.dart';
import '../../../domain/model/domain_failure.dart';
import '../../../domain/model/dose_state.dart';
import '../../../domain/policy/snooze_policy.dart';
import '../../../shared/design/design.dart';
import '../../../shared/widgets/dose_action_sheet.dart';
import '../../../shared/widgets/mt_toast.dart';
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
      // `button: true` and `onTap` here, not only on the trailing
      // `GestureDetector` below: `excludeSemantics` hides that whole subtree
      // from touch exploration, so a screen-reader user's double-tap has to
      // land on THIS node to open the sheet at all -- the mock's own
      // `onClick` binds only the trailing circle for a sighted pointer, but
      // one merged label with one activation point is what UX-DR20's "one
      // screen-reader label per card" means for an interactive card.
      button: true,
      onTap: () => _openSheet(context),
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
                  // The mock's own tap target: `onClick="{{ d.open }}"` binds
                  // only this circle, not the whole row (see the file
                  // comment for the accessibility half of this story).
                  GestureDetector(
                    onTap: () => _openSheet(context),
                    behavior: HitTestBehavior.opaque,
                    child: _TrailingCircle(isDue: isDue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens `DoseActionSheet` over [context] and, once it closes with a
  /// composed toast (a successful action), shows it -- after the pop,
  /// deliberately, since the sheet's own context does not survive it.
  /// Dismissal (scrim tap or back) resolves with `null`: nothing recorded,
  /// no toast, per this spec's own matrix.
  Future<void> _openSheet(BuildContext context) async {
    final String? toastMessage = await DoseActionSheet.show(
      context,
      dose: entry.dose,
      glyphIndex: entry.glyphIndex,
      condition: entry.condition,
    );
    if (toastMessage != null && context.mounted) {
      showMtToast(context, toastMessage);
    }
  }
}

/// The overdue card: amber, no left-border colour reuse from the due card
/// (state-late, never accent), and the three inline actions, each wired
/// directly to `DoseRecorder` -- no sheet, per this story's own Design Notes.
class _OverdueDoseCard extends ConsumerStatefulWidget {
  const _OverdueDoseCard({required this.entry});

  final HomeDoseEntry entry;

  @override
  ConsumerState<_OverdueDoseCard> createState() => _OverdueDoseCardState();
}

class _OverdueDoseCardState extends ConsumerState<_OverdueDoseCard> {
  static const double _accentBarWidth = 4;

  /// Set by a refused action (this spec's "Overdue card, snooze tapped"
  /// row): the same visible-text treatment the sheet gives a refusal, since
  /// this card has no sheet to hold it instead. Cleared at the start of the
  /// next attempt.
  String? _errorMessage;

  /// Guards a rapid double-tap on one of the three pills -- see
  /// `DoseActionSheet`'s own `_busy` for why this is a plain flag rather than
  /// a provider: ephemeral, this card's own lifetime, nothing else reads it.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final HomeDoseEntry entry = widget.entry;

    return DecoratedBox(
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
                // The informational half of the card stays ONE merged
                // announcement, exactly like `_PlainOrDueDoseCard` -- but
                // this `Semantics` wraps only THIS `Row`, not the actions
                // below it, so the exclusion cannot also swallow their own
                // individual button semantics (see the file comment).
                Semantics(
                  label: _cardLabel(entry, 'Overdue'),
                  excludeSemantics: true,
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
                ),
                const SizedBox(height: MTSpacing.s3),
                // No `ExcludeSemantics` here any more (Story 2.2): each pill
                // below carries its own `Semantics(button: true, label: ...)`
                // and is individually reachable and activatable.
                _OverdueActionsRow(
                  onTake: _busy ? null : _take,
                  onSnooze: _busy ? null : _snooze,
                  onSkip: _busy ? null : _skip,
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: MTSpacing.s2),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      style: MTTypography.meta.copyWith(
                        color: MTColors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _take() => _run(
    action: () => ref.read(doseRecorderProvider).take(widget.entry.dose),
    toast: () => composeTakenToast(ref, widget.entry.dose),
  );

  Future<void> _snooze() => _run(
    action: () => ref.read(doseRecorderProvider).snooze(widget.entry.dose),
    toast: () async => HomeCopy.toastSnoozed(defaultSnoozeInterval.inMinutes),
  );

  Future<void> _skip() => _run(
    action: () => ref.read(doseRecorderProvider).skip(widget.entry.dose),
    toast: () async => HomeCopy.toastSkipped,
  );

  /// One action, start to finish -- the overdue row's own version of
  /// `DoseActionSheet`'s `_run`: no sheet to pop, so a success shows the
  /// toast directly (before invalidating the plan, while `context` is
  /// certainly still mounted) and a refusal sets [_errorMessage] instead of
  /// closing anything, because there is nothing here to close.
  Future<void> _run({
    required Future<void> Function() action,
    required Future<String> Function() toast,
  }) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await action();
      final String message = await toast();
      if (!mounted) return;
      showMtToast(context, message);
      ref.invalidate(homePlanControllerProvider);
    } on DomainFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = failure.message;
      });
    }
  }
}

/// The three inline actions the overdue card expands to (UX-DR4, UX-DR13's
/// fixed priority order) -- real controls (Story 2.2), each calling
/// `DoseRecorder` directly with no sheet in between.
class _OverdueActionsRow extends StatelessWidget {
  const _OverdueActionsRow({
    required this.onTake,
    required this.onSnooze,
    required this.onSkip,
  });

  /// `null` while an action from this row is already in flight.
  final VoidCallback? onTake;
  final VoidCallback? onSnooze;
  final VoidCallback? onSkip;

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
            onTap: onTake,
          ),
        ),
        const SizedBox(width: MTSpacing.s2),
        Expanded(
          child: _ActionPill(
            label: 'Snooze',
            background: MTColors.surfaceMuted,
            ink: MTColors.inkSecondary,
            onTap: onSnooze,
          ),
        ),
        const SizedBox(width: MTSpacing.s2),
        Expanded(
          child: _ActionPill(
            label: 'Skip',
            background: MTColors.surfaceApp,
            ink: MTColors.inkFaint,
            onTap: onSkip,
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
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color ink;

  /// `null` while this action is already in flight -- inert, not merely
  /// dimmed, matching `DoseActionSheet`'s own `_SheetAction`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      // One node per pill -- without this the label is announced twice, once
      // here and once by the `Text` below.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
          ),
          child: ConstrainedBox(
            // UX-DR20: "the three-action overdue card is the tightest layout
            // -- it must not compress below" the 44pt/48dp floor.
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
        ),
      ),
    );
  }
}

/// The trailing control on the plain and due cards -- an outline chevron on
/// plain, a filled accent check on due. Purely visual: the tap itself is
/// wired on the `GestureDetector` `_PlainOrDueDoseCard` wraps this in.
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
