// Home's other conditional banner (Story 3.1b), shown whenever
// `HomePlan.notificationsDenied` is true and absent entirely otherwise -- not
// empty, not hidden, not in the tree at all, matching `OverdueBanner`'s own
// "banner absent entirely" contract.
//
// [PermissionBannerReason] (Story 3.3, AD-14): a second, milder degradation --
// notifications are allowed but Android's exact-alarm permission is not --
// reuses this same widget shape rather than a second banner component. The
// two reasons are mutually exclusive at the call site (`home_screen.dart`'s
// own conditional): full denial is strictly worse and takes priority, so the
// two are never shown at once, and this widget itself does not need to know
// that -- it always renders exactly one banner for whichever reason it was
// given.
//
// THE ICON TILE AND TITLE/BODY STACK are `OverdueBanner`'s own shape, reused
// for the reason that banner's own file comment gives for the mock's: a
// capability-level degradation and an item-level one read as siblings, not as
// two unrelated components (UX-DR23, amended 2026-09-16, places this banner
// directly above that one for exactly that reason). What this banner adds
// beyond that shape -- a dismiss control and a tap-through to OS settings --
// is new, so it is not copied verbatim (this spec's own Code Map).
//
// DISMISS IS SESSION-SCOPED, NEVER PERSISTED (this story's own Boundaries): a
// dismissal written to storage would let a user hide this once and then never
// be told again that months of reminders have silently not fired, which is
// the exact failure this story exists to prevent. The flag therefore lives in
// this widget's own `State`, not a provider or a store. `HomeScreen` reaches
// this widget through `homePlanControllerProvider`
// (`AutoDisposeAsyncNotifierProvider`), which is torn down on every fresh
// arrival at Home (no tab bar yet -- `home_plan_controller.dart`'s own file
// comment), so a relaunch, or any other remount, tears this widget down with
// it and starts undismissed again with no code written for that case
// specifically.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/permission_gateway_provider.dart';
import '../../../domain/port/permission_gateway.dart';
import '../../../shared/design/design.dart';
import 'home_copy.dart';

/// Which degradation [PermissionBanner] is reporting.
///
/// Exactly two, matching `HomePlan`'s own two boolean fields
/// (`notificationsDenied`, `exactAlarmsDenied`) -- there is no third
/// permission this product reads through `PermissionGateway` that would need
/// a banner of its own.
enum PermissionBannerReason {
  /// Full denial (Story 3.1b): no primary reminder fires at all.
  /// [HomeCopy.permissionBannerTitle]/[HomeCopy.permissionBannerBody],
  /// unchanged since that story.
  notificationsDenied,

  /// Exact-alarm denial (AD-14, Story 3.3): reminders still fire, but the OS
  /// may batch one into its next Doze/idle wake window, arriving somewhat
  /// later than scheduled. [HomeCopy.exactAlarmBannerTitle]/
  /// [HomeCopy.exactAlarmBannerBody] -- deliberately milder, never claiming
  /// "will not fire" (see this file's own header comment).
  exactAlarmsDenied,
}

/// The permission banner. Callers are expected to omit this widget entirely
/// when neither `HomePlan.notificationsDenied` nor
/// `HomePlan.exactAlarmsDenied` applies -- it does not render an empty or
/// invisible state of its own (`home_screen.dart`'s own conditional,
/// mirroring `OverdueBanner`'s).
class PermissionBanner extends ConsumerStatefulWidget {
  const PermissionBanner({super.key, required this.reason});

  /// Which degradation this instance reports. See [PermissionBannerReason].
  final PermissionBannerReason reason;

  @override
  ConsumerState<PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends ConsumerState<PermissionBanner> {
  /// See the file comment: in-memory only, never written to storage.
  bool _dismissed = false;

  /// The mock's own icon-tile size, matching `OverdueBanner`'s.
  static const double _iconTileSize = 34;
  static const double _iconSize = 20;
  static const double _dismissIconSize = 18;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final bool exactAlarmsDenied =
        widget.reason == PermissionBannerReason.exactAlarmsDenied;
    final IconData icon = exactAlarmsDenied
        ? Icons.schedule_outlined
        : Icons.notifications_off;
    final String title = exactAlarmsDenied
        ? HomeCopy.exactAlarmBannerTitle
        : HomeCopy.permissionBannerTitle;
    final String body = exactAlarmsDenied
        ? HomeCopy.exactAlarmBannerBody
        : HomeCopy.permissionBannerBody;

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
              child: SizedBox(
                width: _iconTileSize,
                height: _iconTileSize,
                child: Icon(icon, size: _iconSize, color: MTColors.inkMuted),
              ),
            ),
            const SizedBox(width: MTSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // One node for the title and body: neither is interactive,
                  // and a screen reader announcing them separately from the
                  // settings link and dismiss control below would split one
                  // fact across three stops instead of one.
                  Semantics(
                    label: '$title $body',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: MTTypography.body.copyWith(
                            color: MTColors.inkSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: MTSpacing.s1),
                        Text(
                          body,
                          style: MTTypography.meta.copyWith(
                            color: MTColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MTSpacing.s2),
                  _SettingsLink(onTap: _openSettings),
                ],
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

  /// The matrix's "Tap the settings route" row.
  Future<void> _openSettings() async {
    final PermissionGateway gateway = ref.read(permissionGatewayProvider);
    await gateway.openAppNotificationSettings();
  }
}

/// The tap-through to OS settings -- accent ink, the same treatment
/// onboarding's own secondary action gives a real control that must not read
/// as decorative (`onboarding_screen_test.dart`'s "accent ink, not a second
/// fill").
class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: HomeCopy.permissionBannerSettingsAction,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MTDimensions.touchMinAndroid,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              HomeCopy.permissionBannerSettingsAction,
              style: MTTypography.meta.copyWith(
                color: MTColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dismiss control -- icon-only, so [HomeCopy.permissionBannerDismiss] is
/// its accessible name rather than visible text. `MTDimensions.controlSm` is
/// declared for exactly this role ("a compact square control: a stepper
/// arrow, a close button"), padded out to [MTDimensions.touchMinAndroid] so
/// the drawn size and the tappable floor (UX-DR20) are not the same box.
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
