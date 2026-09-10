// The progress card: FR-12's one permitted aggregate metric (UX-DR6) plus the
// next-dose chip repurposing the imported design's streak-badge slot
// (UX-DR7, `EXPERIENCE.md`'s `[RESOLVED 2026-08-30]` entry).
//
// THE RING is a determinate `CircularProgressIndicator`, not a hand-rolled
// conic-gradient painter: the mock's own structure is a 62px ring with a 48px
// solid knockout centred inside it, which is exactly what a progress
// indicator's track/value arcs plus a centred solid circle already draw.
// `MTDimensions.ringProgressKnockout`'s own doc comment already anticipates
// deriving the stroke width from the two diameters rather than declaring a
// third number, which is what [_ringStrokeWidth] does.
//
// NO SECOND METRIC. UX-DR21 forbids a chart, a trend or a badge count
// anywhere on this view -- the next-dose chip carries a time, never a score,
// which is the distinction `EXPERIENCE.md`'s resolution over the streak badge
// turns on.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import 'home_copy.dart';

/// The accent-filled card: the progress ring, its label, and the next-dose
/// chip.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    required this.dosesTaken,
    required this.dosesScheduled,
    required this.nextDoseAt,
    super.key,
  });

  /// How many of today's Doses are Taken. Always `0` until Epic 2.
  final int dosesTaken;

  /// How many Doses are scheduled today.
  final int dosesScheduled;

  /// The next actionable Dose's instant, or `null` for "nothing scheduled".
  final DateTime? nextDoseAt;

  @override
  Widget build(BuildContext context) {
    final String progressLabel = HomeCopy.progressLabel(
      dosesTaken,
      dosesScheduled,
    );

    return Semantics(
      // One sentence for the ring and its label; the chip beneath announces
      // itself separately, since it carries a distinct fact (the next dose),
      // not a restatement of the ring's own metric.
      label: '${HomeCopy.progressTitle}. $progressLabel.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MTColors.accent,
          borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl2)),
          boxShadow: <BoxShadow>[MTElevation.accentStrong],
        ),
        child: Padding(
          padding: const EdgeInsets.all(MTSpacing.s4),
          child: Row(
            children: <Widget>[
              _ProgressRing(taken: dosesTaken, scheduled: dosesScheduled),
              const SizedBox(width: MTSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      HomeCopy.progressTitle,
                      style: MTTypography.title.copyWith(
                        color: MTColors.surfaceRaised,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MTSpacing.s1),
                    Text(
                      progressLabel,
                      style: MTTypography.meta.copyWith(
                        color: MTColors.surfaceRaised,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MTSpacing.s3),
              _NextDoseChip(nextDoseAt: nextDoseAt),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.taken, required this.scheduled});

  final int taken;
  final int scheduled;

  /// Derived from the two ring diameters rather than declared a third time --
  /// see `MTDimensions.ringProgressKnockout`'s own doc comment.
  static double get _strokeWidth =>
      (MTDimensions.ringProgressOuter - MTDimensions.ringProgressKnockout) / 2;

  @override
  Widget build(BuildContext context) {
    final double value = scheduled == 0 ? 0 : taken / scheduled;

    return SizedBox(
      width: MTDimensions.ringProgressOuter,
      height: MTDimensions.ringProgressOuter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: MTDimensions.ringProgressOuter,
            height: MTDimensions.ringProgressOuter,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: _strokeWidth,
              backgroundColor: MTTranslucency.glassQuiet,
              valueColor: const AlwaysStoppedAnimation<Color>(
                MTColors.surfaceRaised,
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: MTColors.accent,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: MTDimensions.ringProgressKnockout,
              height: MTDimensions.ringProgressKnockout,
              child: Center(
                child: Text(
                  HomeCopy.percentLabel(taken, scheduled),
                  style: MTTypography.body.copyWith(
                    color: MTColors.surfaceRaised,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UX-DR7: `rgba(255,255,255,.16)` fill (`chipOnAccent`), `rounded/md`, white
/// ink, the next actionable Dose's time with `next dose` beneath -- or, when
/// none exists anywhere in the visible horizon, the single phrase "nothing
/// scheduled" (this spec's own I/O matrix).
class _NextDoseChip extends StatelessWidget {
  const _NextDoseChip({required this.nextDoseAt});

  final DateTime? nextDoseAt;

  @override
  Widget build(BuildContext context) {
    final DateTime? at = nextDoseAt;
    final String label = at == null
        ? HomeCopy.nothingScheduled
        : HomeCopy.timeLabel(at);

    return Semantics(
      label: at == null
          ? HomeCopy.nothingScheduled
          : '${HomeCopy.timeLabel(at)}, ${HomeCopy.nextDoseLabel}',
      excludeSemantics: true,
      child: ConstrainedBox(
        // A width ceiling, not a fixed width: EXPERIENCE.md's own resolution
        // over this slot says "same position, same dimensions" as the streak
        // badge it replaces -- a short number's badge, not a sentence's. A
        // time (`8:00 AM`) never approaches this; "nothing scheduled" wraps
        // onto two lines inside it instead of forcing the whole progress
        // card's Row wider than the 402px reference frame.
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: MTTranslucency.chipOnAccent,
            borderRadius: BorderRadius.all(Radius.circular(MTRadius.md)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpacing.s3,
              vertical: MTSpacing.s2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  textAlign: TextAlign.center,
                  // A real time is short enough for the mock's own 17px/700
                  // (`title`, weight overridden to match -- the same
                  // substitution `add_medicine_screen.dart`'s header makes).
                  // "nothing scheduled" is a sentence, not a number, and
                  // reads at the smaller `chip` size instead of being forced
                  // to fit the number's slot at the number's size.
                  style: (at == null ? MTTypography.chip : MTTypography.title)
                      .copyWith(
                        color: MTColors.surfaceRaised,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (at != null) ...<Widget>[
                  const SizedBox(height: MTSpacing.s1),
                  Text(
                    HomeCopy.nextDoseLabel,
                    style: MTTypography.chip.copyWith(
                      color: MTColors.surfaceRaised,
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

  /// Single-use: the chip's own width ceiling, per the file comment above.
  static const double _maxWidth = 96;
}
