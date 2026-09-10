// UX-DR16's shared empty-state card: a 76px accent-wash glyph tile, a title,
// a body, and an optional action -- the one shape Home, Schedule and History
// all reuse for "nothing here yet", each with its own icon and words.
//
// GENERIC ON PURPOSE. Home is the first caller (Story 1.9); Schedule's and
// History's own empty states are not built here and are not imported here --
// this widget knows nothing about doses, medicines or routes, only the four
// things UX-DR16 actually varies: a glyph, a title, a body, and an optional
// single action. The story that gives this widget its second caller is the
// story that should reshape it, with that caller in hand -- the same
// discipline `add_medicine_controls.dart`'s file comment holds its own atoms
// to.
//
// THE ACTION IS OPTIONAL, per UX-DR16's own wording ("title, body, optional
// action") and per the delivered mock: Home's `isEmpty` block carries a
// button, but Schedule's own empty-state block (the same mock, its
// `isSchedule` section) does not -- its own "+ Add medicine" control sits
// outside the card entirely. `actionLabel`/`onAction` are therefore
// both-or-neither, not required.
//
// TOKENS, as measured from the mock's `isEmpty` block: `surface-raised` ·
// `rounded/2xl` (20) · `elevation/raised` for the card; a 76px tile ·
// `accent-wash` · `rounded/3xl` (26 -- the tile's own radius, not the card's)
// for the glyph. The action, when given, is `accent` · `rounded/md` (14) ·
// `elevation/accent` -- deliberately NOT the app theme's pill shape, the same
// override `AddMedicinePrimaryAction` already makes for its own measured
// radius.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';

/// The shared empty-state card (UX-DR16).
///
/// [icon] and the words are supplied by the caller; this widget carries no
/// copy and no navigation of its own, so a second screen can reuse it without
/// pulling in anything Home-specific.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction are both given or both omitted -- the '
         'action is optional (UX-DR16), not half-wired.',
       );

  /// The glyph drawn on the accent-wash tile. Decorative: the card's meaning
  /// is carried by [title] and [body], so this is excluded from semantics.
  final IconData icon;

  /// The card's heading.
  final String title;

  /// The explanatory line beneath [title].
  final String body;

  /// The single action's label, or `null` for no action (UX-DR16's "optional
  /// action").
  final String? actionLabel;

  /// The single action, or `null` for no action.
  final VoidCallback? onAction;

  /// The action's leading glyph. Every empty state this product draws is
  /// "add something", so this defaults to a plus rather than asking every
  /// caller to repeat it -- a future caller with a genuinely different action
  /// can still override it.
  final IconData actionIcon;

  /// The glyph's own drawn size inside the tile -- the mock's own
  /// measurement, single-use like `OverdueBanner`'s `_iconSize`.
  static const double _iconSize = 38;

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    final VoidCallback? action = onAction;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MTColors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl2)),
        boxShadow: <BoxShadow>[MTElevation.raised],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpacing.s6,
          vertical: MTSpacing.s7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: MTColors.accentWash,
                  borderRadius: BorderRadius.all(Radius.circular(MTRadius.xl3)),
                ),
                child: SizedBox(
                  width: MTDimensions.tileXl,
                  height: MTDimensions.tileXl,
                  child: Icon(icon, size: _iconSize, color: MTColors.accent),
                ),
              ),
            ),
            const SizedBox(height: MTSpacing.s4),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: MTTypography.title.copyWith(
                  color: MTColors.inkPrimary,
                  // "Heading weight": every heading in the design is 700,
                  // `title` alone is 600 -- see `progress_card.dart`'s
                  // identical override of the same style for the same
                  // reason.
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: MTSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: MTTypography.body.copyWith(color: MTColors.inkMuted),
            ),
            if (label != null && action != null) ...<Widget>[
              const SizedBox(height: MTSpacing.s5),
              DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(MTRadius.md)),
                  boxShadow: <BoxShadow>[MTElevation.accent],
                ),
                child: FilledButton.icon(
                  onPressed: action,
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(MTRadius.md),
                      ),
                    ),
                  ),
                  icon: Icon(actionIcon),
                  label: Text(label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
