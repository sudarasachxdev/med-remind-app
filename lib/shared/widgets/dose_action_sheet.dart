// The modal action sheet UX-DR13 specifies for a plain/due dose card's tap
// (Story 2.2). The overdue card's own three inline actions are a SEPARATE,
// deliberately sheet-free entry point to the same three `DoseRecorder` calls
// (`dose_card.dart`'s `_OverdueActionsRow` -- see that file's comment and
// this spec's Design Notes for why: EXPERIENCE.md states the overdue variant
// as the one dose state that never requires a second tap, which is not this
// sheet with an extra step, it is not this sheet at all).
//
// LIVES IN `lib/shared/widgets/`, per the architecture spine's own source
// tree, and takes a bare `Dose` plus the two Medicine fields it does not
// itself freeze (AD-11) rather than Home's own `HomeDoseEntry` -- so a
// notification tap (Epic 3) can reuse this widget without importing Home's
// application layer to build one. `home_copy.dart`'s sheet/toast strings are
// the one exception this story's own Code Map allows shared/ to reach into
// features/ for, "if the toast/sheet strings are needed by a later screen
// too" -- not yet true, so they stay put until they are.
//
// A `ConsumerStatefulWidget`, not the bare `ConsumerWidget` the Code Map
// names -- matching `AddMedicineScreen`'s shape in the sense that matters
// (no callback-injection layer: every action reads `doseRecorderProvider`
// directly). The refusal row ("sheet stays open; the failure surfaces as
// visible text") needs somewhere to hold that text between the throw and the
// next frame, and ephemeral UI-only state the sheet's own lifetime bounds is
// exactly what `State` is for -- a new provider for a string only this widget
// ever reads would be the wrong tool.
//
// HOW A CLOSE CARRIES ITS TOAST BACK. `showModalBottomSheet<String>`'s own
// return channel: a successful action pops with the composed toast sentence,
// scrim/back dismissal pops with nothing. The toast itself is shown by the
// caller, after the pop, deliberately -- this widget's own `context` is being
// torn down at exactly the moment a toast would need to outlive it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock_provider.dart';
import '../../app/dose_recorder_provider.dart';
import '../../app/dose_repository_provider.dart';
import '../../domain/model/dose.dart';
import '../../domain/model/domain_failure.dart';
import '../../domain/policy/dose_resolver.dart';
import '../../domain/policy/snooze_policy.dart';
import '../../domain/port/dose_repository.dart';
import '../../features/home/application/home_plan_controller.dart';
import '../../features/home/presentation/glyph_tile.dart';
import '../../features/home/presentation/home_copy.dart';
import '../design/design.dart';

/// Re-reads [dose] after a `DoseRecorder.take` call and composes the
/// "Recorded ... as taken[, logged late]" toast -- shared by this sheet's own
/// Take action and the overdue card's direct-tap Take (this spec's own "same
/// toast as the sheet path" row), so the late/on-time check exists in one
/// place rather than twice.
///
/// Re-reads rather than trusting [dose]: `DoseRecorder.take`'s own contract
/// (Story 2.1) is `void`, and `resolve()`'s `loggedLate` flag is the one
/// source of truth for whether a record landed late -- reusing it rather
/// than re-deriving the same `now`-vs-window comparison a second time here.
Future<String> composeTakenToast(WidgetRef ref, Dose dose) async {
  final DoseRepository doses = ref.read(doseRepositoryProvider);
  final Dose? updated = await doses.findDose(dose.id);
  final DateTime now = ref.read(clockProvider).now();
  final bool loggedLate = updated != null && resolve(updated, now).loggedLate;
  return loggedLate
      ? HomeCopy.toastTakenLate(dose.medicineName)
      : HomeCopy.toastTaken(dose.medicineName);
}

/// The bottom sheet UX-DR13 draws for a plain/due dose card's tap: header
/// (glyph, title, meta, condition chip), then three actions in fixed
/// priority -- take, snooze, skip -- never reordered.
class DoseActionSheet extends ConsumerStatefulWidget {
  const DoseActionSheet({
    required this.dose,
    required this.glyphIndex,
    required this.condition,
    super.key,
  });

  /// The Dose this sheet acts on.
  final Dose dose;

  /// The owning Medicine's glyph -- AD-11 does not freeze this onto a Dose,
  /// so it is read once by the caller and passed in, the same way
  /// `dose_card.dart` already does for `HomeDoseEntry.glyphIndex`.
  final int glyphIndex;

  /// The owning Medicine's Condition, or `null` -- display-only, and the
  /// sheet shows no chip at all when it is absent rather than an empty one.
  final String? condition;

  /// Opens the sheet over [context]. Resolves with the toast sentence to
  /// show once a successful action has popped it, or `null` when the sheet
  /// was dismissed (scrim tap or system back) with nothing recorded.
  static Future<String?> show(
    BuildContext context, {
    required Dose dose,
    required int glyphIndex,
    required String? condition,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      // `isScrollControlled`, so the sheet sizes to its own content instead
      // of the default half-screen cap -- UX-DR20's "largest text size" row
      // needs the sheet free to grow past that cap without clipping a line.
      isScrollControlled: true,
      // Transparent: this widget paints its own fill and top-corner radius
      // below, rather than the framework's own Material sheet shape.
      backgroundColor: Colors.transparent,
      barrierColor: MTTranslucency.scrim,
      builder: (context) => DoseActionSheet(
        dose: dose,
        glyphIndex: glyphIndex,
        condition: condition,
      ),
    );
  }

  @override
  ConsumerState<DoseActionSheet> createState() => _DoseActionSheetState();
}

class _DoseActionSheetState extends ConsumerState<DoseActionSheet> {
  /// Set by a refused action (this spec's "Snooze, refused" row): visible
  /// text, the sheet stays open, and nothing is recorded. Cleared at the
  /// start of the next attempt, whichever action that is.
  String? _errorMessage;

  /// Guards against a rapid double-tap re-entering an action already in
  /// flight -- `DoseRecorder`'s own methods are safe to call twice, but there
  /// is no reason to ask them to.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final Dose dose = widget.dose;
    final String? condition = widget.condition;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MTColors.surfaceRaised,
          borderRadius: BorderRadius.only(
            // `rounded/4xl` -- `DESIGN.md`'s Shapes section: "the bottom
            // sheet's top corners alone." Was `xl3` (26) until 2026-09-11:
            // `spacing.dart`'s own doc comment wrongly claimed that step was
            // the sheet's, and the mock's own markup measures 30px, not 26.
            topLeft: Radius.circular(MTRadius.xl4),
            topRight: Radius.circular(MTRadius.xl4),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MTSpacing.s5,
              MTSpacing.s5,
              MTSpacing.s5,
              MTSpacing.s5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    GlyphTile(glyphIndex: widget.glyphIndex),
                    const SizedBox(height: MTSpacing.s4),
                    Text(
                      HomeCopy.sheetTitle(dose.medicineName),
                      textAlign: TextAlign.center,
                      style: MTTypography.headingSm.copyWith(
                        color: MTColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: MTSpacing.s1),
                    Text(
                      HomeCopy.sheetMeta(
                        amount: dose.dosageAmount,
                        unit: dose.dosageUnit,
                        time: dose.scheduledLocal,
                      ),
                      textAlign: TextAlign.center,
                      style: MTTypography.meta.copyWith(
                        color: MTColors.inkMuted,
                      ),
                    ),
                    if (condition != null) ...<Widget>[
                      const SizedBox(height: MTSpacing.s3),
                      _ConditionChip(text: condition),
                    ],
                  ],
                ),
                const SizedBox(height: MTSpacing.s5),
                _SheetAction(
                  label: HomeCopy.sheetTakeAction,
                  onTap: _busy ? null : _take,
                  background: MTColors.accent,
                  ink: MTColors.surfaceRaised,
                  textStyle: MTTypography.title,
                  shadow: const <BoxShadow>[MTElevation.accentStrong],
                ),
                const SizedBox(height: MTSpacing.s3),
                _SheetAction(
                  label: HomeCopy.sheetSnoozeAction(
                    defaultSnoozeInterval.inMinutes,
                  ),
                  onTap: _busy ? null : _snooze,
                  background: MTColors.surfaceMuted,
                  ink: MTColors.inkSecondary,
                  textStyle: MTTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: MTSpacing.s2),
                _SheetAction(
                  label: HomeCopy.sheetSkipAction,
                  onTap: _busy ? null : _skip,
                  background: null,
                  ink: MTColors.inkFaint,
                  textStyle: MTTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: MTSpacing.s3),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: MTTypography.body.copyWith(
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
    action: () => ref.read(doseRecorderProvider).take(widget.dose),
    toast: () => composeTakenToast(ref, widget.dose),
  );

  Future<void> _snooze() => _run(
    action: () => ref.read(doseRecorderProvider).snooze(widget.dose),
    toast: () async => HomeCopy.toastSnoozed(defaultSnoozeInterval.inMinutes),
  );

  Future<void> _skip() => _run(
    action: () => ref.read(doseRecorderProvider).skip(widget.dose),
    toast: () async => HomeCopy.toastSkipped,
  );

  /// One action, start to finish: clear any prior error, run [action],
  /// compose [toast] and pop with it on success -- or, on a typed refusal,
  /// leave the sheet open with [DomainFailure.message] as visible text.
  ///
  /// `on DomainFailure`, not the narrower `DoseRecorderFailure`: the write
  /// this action makes can also refuse at the repository (a stored-row
  /// failure `DoseRecorder` itself does not catch), and PRD §9's rule --
  /// nothing this port did not actually do is ever reported as a success --
  /// applies to both, not only to `DoseRecorder`'s own three refusals.
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
      ref.invalidate(homePlanControllerProvider);
      if (mounted) Navigator.of(context).pop(message);
    } on DomainFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = failure.message;
      });
    }
  }
}

/// The sheet's condition chip -- pill-shaped, the mock's own
/// `background:#F4F3FA` / `color:#5D5D75`, which are `surfaceMuted` and
/// `inkTertiary`.
class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MTColors.surfaceMuted,
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.pill)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpacing.s3,
          vertical: MTSpacing.s2,
        ),
        child: Text(
          text,
          style: MTTypography.chip.copyWith(color: MTColors.inkTertiary),
        ),
      ),
    );
  }
}

/// One of the sheet's three actions -- a single shape parametrised by fill,
/// ink and shadow, since UX-DR13's three actions differ only in emphasis,
/// never in structure.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.onTap,
    required this.background,
    required this.ink,
    required this.textStyle,
    this.shadow,
  });

  final String label;

  /// `null` while an action is already in flight -- inert, not merely
  /// visually dimmed, matching `AddMedicineStepperButton`'s own "a control
  /// that greys out mid-interaction is harder to read than one that does
  /// nothing" reasoning.
  final VoidCallback? onTap;
  final Color? background;
  final Color ink;
  final TextStyle textStyle;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      // One node per action -- without this the label is announced twice,
      // once here and once by the `Text` below (`AddMedicineChip`'s own
      // reasoning).
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(MTRadius.xl)),
            boxShadow: enabled ? shadow : null,
          ),
          child: ConstrainedBox(
            // UX-DR20's floor: every action clears 44pt/48dp, at every text
            // size -- a minimum, so a label that grows under Dynamic Type
            // grows the action instead of truncating inside it.
            constraints: const BoxConstraints(
              minHeight: MTDimensions.touchMinAndroid,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MTSpacing.s4,
                  vertical: MTSpacing.s3,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(color: ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
