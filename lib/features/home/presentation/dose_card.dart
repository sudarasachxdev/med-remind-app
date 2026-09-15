// The dose card, in six of the seven states `resolve()` can produce: plain
// (Scheduled), due, overdue (Story 1.8/2.2), and -- Story 2.3 -- Taken,
// Skipped and Snoozed, the three `DoseRecorder` (Story 2.2) now writes real
// facts for. Missed is the one state never rendered here (this story's own
// Never rule): `EXPERIENCE.md` scopes it to History, and Home shows only
// today's Doses, which a Missed Dose does not practically remain among.
//
// STORY 2.3's THREE NEW VARIANTS (`_TakenDoseCard`, `_SkippedDoseCard`,
// `_SnoozedDoseCard`) share one shell, `_StaticDoseCard`, and are all
// non-interactive: no trailing control, no `GestureDetector`, no sheet.
// There is nothing left to do with an already-acted-on Dose, and this
// story's own Never rule is no new `DoseRecorder` calls and no new refusal
// handling -- Story 2.2 built the write path, this story only renders what
// it produces. Each still carries its own merged `Semantics` label, the same
// "one label per card" shape the interactive variants use, just with nothing
// behind it to activate.
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
// Taken and Skipped are the other two states `EXPERIENCE.md`'s State
// Patterns table assigns a mark to (`✓`, `–`); both marks are folded into the
// chip's own word rather than drawn a second time, and Skipped's chip reuses
// `stateNeutralTile`/`inkMuted` -- never red -- per that table and
// DESIGN.md's own note.
//
// The glyph tile's tint is per-Medicine (AD-22) and is drawn by `GlyphTile`
// alone, on EVERY variant including Taken/Skipped/Snoozed (this story's own
// Boundaries -- generalising the rule Story 1.8 stated only for the Due
// card); only the left border and the chip read from `resolve()` -- the two
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
  const DoseCard({required this.entry, required this.now, super.key});

  /// The Dose, its resolved state, and the two Medicine fields it does not
  /// itself freeze.
  final HomeDoseEntry entry;

  /// The instant `entry.resolution` was resolved against -- `HomePlan.now`,
  /// threaded down rather than re-read from the clock here. The only variant
  /// that needs it is `_SnoozedDoseCard`, whose "reminder in {n} min" is a
  /// fresh `now`-to-`snoozedUntil` computation, not a value `resolve()`
  /// itself carries.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return switch (entry.resolution.state) {
      DoseState.overdue => _OverdueDoseCard(entry: entry),
      DoseState.due => _PlainOrDueDoseCard(entry: entry, isDue: true),
      // Story 2.3: the three states `DoseRecorder` (Story 2.2) can now
      // produce. None is interactive -- this story's own Never rule is no
      // new `DoseRecorder` calls, and there is nothing left to do with an
      // already-acted-on Dose from here.
      DoseState.taken => _TakenDoseCard(entry: entry),
      DoseState.skipped => _SkippedDoseCard(entry: entry),
      DoseState.snoozed => _SnoozedDoseCard(entry: entry, now: now),
      // `scheduled` is the ordinary case; `missed` reaching here (Home shows
      // only today's Doses, and Missed is a prior-day state per this story's
      // own Never rule) renders as the neutral, no-border treatment rather
      // than throwing -- Home degrades to a plain card instead of a crash.
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

/// The shared shell for Story 2.3's three "already resolved" cards -- Taken,
/// Skipped and Snoozed. None is interactive: unlike `_PlainOrDueDoseCard`/
/// `_OverdueDoseCard`, there is no trailing control, no `GestureDetector` and
/// no sheet, because there is nothing left to do with a Dose one of these
/// three actions has already resolved (this story's own Never rule: no new
/// `DoseRecorder` calls, no new refusal handling).
///
/// Same shell as the plain (Scheduled) card otherwise -- `MTRadius.lg`,
/// `MTElevation.raised`, no left border, `GlyphTile(glyphIndex:...)` per
/// AD-22 -- so the only per-variant differences are [nameColor] and [chip].
class _StaticDoseCard extends StatelessWidget {
  const _StaticDoseCard({
    required this.entry,
    required this.stateWord,
    required this.nameColor,
    required this.chip,
  });

  final HomeDoseEntry entry;

  /// The word this card's merged `Semantics` label ends on.
  final String stateWord;

  /// `inkMuted` for Taken (DESIGN.md's "dimmed"), `inkPrimary` for the other
  /// two -- Skipped's own recessive treatment lives entirely on its chip
  /// (`stateNeutralTile`/`inkMuted`, DESIGN.md's own pairing), not on its
  /// name, and Snoozed carries no dimming at all.
  final Color nameColor;

  /// This variant's own `_StatusChip`.
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _cardLabel(entry, stateWord),
      // No `button`/`onTap` here, unlike `_PlainOrDueDoseCard` -- this is a
      // label-only node because there is nothing behind this card to
      // activate, not because the label itself is announced any
      // differently.
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(MTRadius.lg)),
          boxShadow: <BoxShadow>[MTElevation.raised],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.lg)),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: MTColors.surfaceRaised),
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
                          style: MTTypography.title.copyWith(color: nameColor),
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
                        chip,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A recorded-taken Dose (Story 2.3). Dimmed (DESIGN.md's Components note)
/// via [_StaticDoseCard.nameColor], and its chip reads `dose.takenAt`, never
/// `dose.scheduledAt` -- the spec's own AC1: changing `scheduledAt` cannot
/// change what this card shows.
class _TakenDoseCard extends StatelessWidget {
  const _TakenDoseCard({required this.entry});

  /// `entry.resolution.state == DoseState.taken` is this widget's only
  /// caller-enforced precondition (the `DoseCard` switch above), and
  /// `resolve()`'s own Taken branch requires `dose.takenAt != null` to reach
  /// it -- so the `!` below is a contract already proven, not a new
  /// assumption.
  final HomeDoseEntry entry;

  @override
  Widget build(BuildContext context) {
    final String chipText = HomeCopy.stateTaken(entry.dose.takenAt!);
    return _StaticDoseCard(
      entry: entry,
      stateWord: chipText,
      nameColor: MTColors.inkMuted,
      chip: _StatusChip(
        text: chipText,
        background: MTColors.stateTakenTile,
        ink: MTColors.stateTakenMark,
      ),
    );
  }
}

/// A recorded-skipped Dose (Story 2.3) -- recessive, never red: the chip
/// reuses `stateNeutralTile`/`inkMuted`, the same pairing the plain
/// (Scheduled) card's own chip already draws from, per DESIGN.md's own
/// "a skipped dose is neutral" note.
class _SkippedDoseCard extends StatelessWidget {
  const _SkippedDoseCard({required this.entry});

  final HomeDoseEntry entry;

  @override
  Widget build(BuildContext context) {
    return _StaticDoseCard(
      entry: entry,
      stateWord: HomeCopy.stateSkipped,
      // Not dimmed -- only Taken carries DESIGN.md's "dimmed" note. Skipped's
      // own recessiveness lives on its chip alone.
      nameColor: MTColors.inkPrimary,
      chip: const _StatusChip(
        text: HomeCopy.stateSkipped,
        background: MTColors.stateNeutralTile,
        ink: MTColors.inkMuted,
      ),
    );
  }
}

/// A live-snoozed Dose (Story 2.3). The table assigns this state no mark, so
/// its chip stays word-only, in the same accent-wash/accent-ink pairing the
/// due card's own chip already uses (the mock's own `chipBg:VL, chipFg:V` for
/// its snoozed example).
class _SnoozedDoseCard extends StatelessWidget {
  const _SnoozedDoseCard({required this.entry, required this.now});

  final HomeDoseEntry entry;

  /// `HomePlan.now`, threaded down from `DoseCard` -- see that class's own
  /// doc comment for why this is the one variant that needs it.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // `resolve()`'s Snoozed branch requires `snoozedUntil != null` to reach
    // this widget, so the `!` is a proven contract, matching `_TakenDoseCard`.
    final DateTime snoozedUntil = entry.dose.snoozedUntil!;
    // Rounded, not truncated (this spec's own Boundaries: "the rounded
    // minutes from now to snoozedUntil") -- `Duration.inMinutes` truncates
    // towards zero, which would read a dose one minute out as "0 min" rather
    // than "1 min" (this spec's own matrix row).
    final int minutes = (snoozedUntil.difference(now).inSeconds / 60).round();
    final String chipText = HomeCopy.stateSnoozed(minutes);
    return _StaticDoseCard(
      entry: entry,
      stateWord: chipText,
      nameColor: MTColors.inkPrimary,
      chip: _StatusChip(
        text: chipText,
        background: MTColors.accentWash,
        ink: MTColors.accentInk,
      ),
    );
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
