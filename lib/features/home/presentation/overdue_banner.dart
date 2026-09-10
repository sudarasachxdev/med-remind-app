// The overdue banner: present only when at least one of today's Doses has
// resolved to Overdue, absent entirely otherwise -- not empty, not hidden,
// not in the tree at all (this spec's own I/O matrix).
//
// NEUTRAL, AS THE MOCK DRAWS IT. Unlike the per-dose overdue card (see
// `dose_card.dart`), this container *is* correct in the delivered design --
// this spec's own Code Map says so explicitly. `#F4F4F8`/`#E4E3EF` have no
// exact token match (the closest declared pair is `surfaceMuted`/
// `borderStrong`, the second an exact hex match), which is what "equivalent
// tokens" in the Code Map means: read the mock's intent, not its literal hex.

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import 'home_copy.dart';

/// The banner above the dose list when [overdueCount] is greater than zero.
///
/// Callers are expected to omit this widget entirely when [overdueCount] is
/// `0` -- it does not render an empty or invisible state of its own, matching
/// the matrix's "banner absent entirely" row.
class OverdueBanner extends StatelessWidget {
  const OverdueBanner({required this.overdueCount, super.key});

  /// How many of today's Doses are Overdue. Must be greater than zero.
  final int overdueCount;

  /// The mock's own icon-tile size.
  static const double _iconTileSize = 34;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    assert(
      overdueCount > 0,
      'OverdueBanner must not be built for a zero count -- the caller omits '
      'it entirely instead (this spec\'s own "banner absent entirely" row).',
    );

    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MTColors.surfaceMuted,
          border: Border.all(color: MTColors.borderStrong),
          borderRadius: const BorderRadius.all(Radius.circular(MTRadius.xl)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpacing.s4,
            vertical: MTSpacing.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: MTColors.borderStrong,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(MTRadius.sm),
                  ),
                ),
                child: const SizedBox(
                  width: _iconTileSize,
                  height: _iconTileSize,
                  child: Icon(
                    Icons.schedule,
                    size: _iconSize,
                    color: MTColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: MTSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      HomeCopy.overdueBannerTitle(overdueCount),
                      style: MTTypography.body.copyWith(
                        color: MTColors.inkSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MTSpacing.s1),
                    Text(
                      HomeCopy.overdueBannerBody(overdueCount),
                      style: MTTypography.meta.copyWith(
                        color: MTColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
