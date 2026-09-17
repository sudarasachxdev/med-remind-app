// Home's third conditional banner (AD-8, Story 3.4), shown whenever
// `HomePlan.budgetExceeded` is true and absent entirely otherwise -- not
// empty, not hidden, not in the tree at all, matching `OverdueBanner`'s and
// `PermissionBanner`'s own "banner absent entirely" contract.
//
// A NEW, SEPARATE WIDGET, not a third `PermissionBannerReason` -- this
// story's own Design Notes cover why in full. In short: `PermissionBanner`'s
// own doc comment states its reason enum matches `HomePlan`'s "own two
// boolean fields" with "no third permission this product reads through
// `PermissionGateway`" -- a budget fact is not a `PermissionGateway` fact.
// `PermissionBanner`'s settings link also renders unconditionally regardless
// of `reason`, which would be a dead, misleading control on a banner about
// dose volume rather than a permission -- there is no OS setting this fact
// routes to.
//
// THE ICON TILE AND TITLE/BODY STACK are `OverdueBanner`'s/`PermissionBanner`'s
// own shape, reused for the same reason those two share it: a capability-level
// degradation reads as a sibling of the other two, not as an unrelated
// component (UX-DR23). The icon itself is deliberately distinct from both
// (`notifications_off`, `schedule_outlined`) -- an hourglass reads as "a
// volume/timing fact," not a permission one.
//
// DISMISS IS SESSION-SCOPED, NEVER PERSISTED -- `permission_banner.dart`'s own
// file comment gives the full reasoning this story reuses verbatim: a
// dismissal written to storage would let a user hide this once and never be
// told again that most of their upcoming doses have no reminder scheduled,
// which is the exact failure AD-14's "degradation is never silent" rule
// exists to prevent. The flag lives in this widget's own `State`, torn down
// and reset the same way `PermissionBanner`'s is on every fresh arrival at
// Home (`home_plan_controller.dart`'s own `autoDispose`).

import 'package:flutter/material.dart';

import '../../../shared/design/design.dart';
import 'home_copy.dart';

/// The banner shown while `HomePlan.budgetExceeded` is true.
///
/// Callers are expected to omit this widget entirely when
/// `HomePlan.budgetExceeded` is false -- it does not render an empty or
/// invisible state of its own (`home_screen.dart`'s own conditional,
/// mirroring `OverdueBanner`'s and `PermissionBanner`'s).
class BudgetBanner extends StatefulWidget {
  const BudgetBanner({super.key});

  @override
  State<BudgetBanner> createState() => _BudgetBannerState();
}

class _BudgetBannerState extends State<BudgetBanner> {
  /// See the file comment: in-memory only, never written to storage.
  bool _dismissed = false;

  /// `OverdueBanner`'s/`PermissionBanner`'s own icon-tile size.
  static const double _iconTileSize = 34;
  static const double _iconSize = 20;
  static const double _dismissIconSize = 18;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return DecoratedBox(
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
                  Icons.hourglass_top,
                  size: _iconSize,
                  color: MTColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: MTSpacing.s3),
            Expanded(
              child: Semantics(
                label:
                    '${HomeCopy.budgetBannerTitle} ${HomeCopy.budgetBannerBody}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      HomeCopy.budgetBannerTitle,
                      style: MTTypography.body.copyWith(
                        color: MTColors.inkSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MTSpacing.s1),
                    Text(
                      HomeCopy.budgetBannerBody,
                      style: MTTypography.meta.copyWith(
                        color: MTColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MTSpacing.s2),
            _DismissButton(
              iconSize: _dismissIconSize,
              onTap: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dismiss control -- icon-only, so [HomeCopy.permissionBannerDismiss] is
/// its accessible name rather than visible text. The same accessible name
/// `PermissionBanner`'s own dismiss uses: both are "Dismiss", and the two
/// controls are never on screen confused with one another since each sits in
/// its own banner.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.iconSize, required this.onTap});

  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: HomeCopy.permissionBannerDismiss,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: MTDimensions.touchMinAndroid,
            minHeight: MTDimensions.touchMinAndroid,
          ),
          child: Center(
            child: Icon(Icons.close, size: iconSize, color: MTColors.inkFaint),
          ),
        ),
      ),
    );
  }
}
