// Panel 2's escalation timeline: the product's argument in one screen.
//
// A dose that goes unanswered is followed up, then parked, then still
// recordable -- "recorded late, and recorded honestly." That last row is the
// sentence that distinguishes this app from a louder alarm clock.
//
// COLOURS. Eight of the thirteen colours in the delivered mock's onboarding
// block are not tokens, and the story's Code Map maps the rest onto tokens
// deliberately -- more semantically coherent than the mock, because these dots
// preview states the user will later meet in the app, so they are those states'
// real colours:
//
//   8:00 Reminder          #6C5CE7 -> MTColors.accent
//   8:15 Gentle follow-up  #A99CF0 -> MTColors.accentBorder
//   9:00 Marked overdue    #E3A34C -> MTColors.stateLateGlyph  (the real amber)
//   Taken at 12:40         #16A34A -> MTColors.stateTakenGlyph
//   Connector line         #E6E3F8 -> MTColors.accentWash
//   Row sub-labels         #8A8AA0 -> MTColors.inkMuted
//
// The dots are decoration, not signal: every row states its own time and what
// happened at it, in words, and the screen reader gets the row as one sentence
// with no colour involved. That is why none of the four is a `_contrastPairs`
// row -- `accentBorder` on the page measures 1.60:1 and would fail a 3:1 glyph
// bar it was never carrying. DESIGN.md's contrast note draws exactly this line:
// a lighter tone is allowed where "nothing is being read", and "must never
// carry a word". No word here rests on one.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import 'onboarding_copy.dart';

/// The four-row escalation timeline.
class EscalationTimeline extends StatelessWidget {
  const EscalationTimeline({super.key});

  /// The dot colour previewing each step's real state colour in the app.
  static Color _dotColor(EscalationStep step) => switch (step) {
    EscalationStep.reminder => MTColors.accent,
    EscalationStep.followUp => MTColors.accentBorder,
    EscalationStep.overdue => MTColors.stateLateGlyph,
    EscalationStep.taken => MTColors.stateTakenGlyph,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final EscalationStep step in EscalationStep.values)
          _EscalationRow(
            step: step,
            isLast: step == EscalationStep.values.last,
          ),
      ],
    );
  }
}

class _EscalationRow extends StatelessWidget {
  const _EscalationRow({required this.step, required this.isLast});

  final EscalationStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        // One label for the whole row. Three separate nodes -- a time, a
        // phrase, and an unlabelled dot -- would read as fragments, and
        // EXPERIENCE.md's floor is that each panel's explanation is reachable
        // and readable, not merely present.
        label: step.semanticsLabel,
        excludeSemantics: true,
        // IntrinsicHeight, not a fixed height. The gutter is stretched to the
        // row's height by the text beside it, which is what lets the connector
        // run the full distance to the next dot however tall the text has grown
        // under Dynamic Type -- and `stretch` needs a bounded height to
        // stretch to, which the enclosing scroll view does not provide.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: MTSpacing.s4,
                child: Column(
                  children: <Widget>[
                    // The dot: one spacing step across, drawn as a circle so no
                    // radius is named at all.
                    Container(
                      width: MTSpacing.s4,
                      height: MTSpacing.s4,
                      decoration: BoxDecoration(
                        color: EscalationTimeline._dotColor(step),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      const Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: MTColors.accentWash),
                          child: SizedBox(width: MTSpacing.s1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: MTSpacing.s4),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : MTSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ONE Text, at one weight, carrying the mock's own head
                      // line -- "8:00 · Reminder", and "Taken at 12:40" on the
                      // last row. An earlier pass split it into two Texts at
                      // different weights and inks, which de-emphasised the
                      // outcome: the thing the whole chain exists to reach was
                      // set in the smaller, greyer of the two styles.
                      //
                      // A single Text also wraps by itself, so there is no
                      // Wrap to reflow and nothing that can run out of
                      // horizontal room at the largest accessibility size. No
                      // maxLines and no overflow, so nothing can truncate.
                      Text(
                        step.head,
                        style: MTTypography.title.copyWith(
                          color: MTColors.inkPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: MTSpacing.s1),
                        child: Text(
                          step.note,
                          style: MTTypography.meta.copyWith(
                            color: MTColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
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
