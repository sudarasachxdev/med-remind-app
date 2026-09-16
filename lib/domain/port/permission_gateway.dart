// The single authority for notification and exact-alarm permission state
// (AD-17). Story 3.1a builds this port and its one adapter with no caller --
// exactly the position `DoseRepository` was in from Story 1.7a until Story
// 1.8 wired its first one. Story 3.1b is this port's first caller.
//
// AD-1: pure Dart. This file imports nothing at all -- a port that reads and
// requests permission needs no model and no package to say so, exactly like
// `clock.dart` and `dose_notifier.dart`.
//
// WHY EXACT-ALARM PERMISSION IS SHAPED THE WAY IT IS.
// Exact-alarm scheduling is an Android-only restriction, introduced so an app
// cannot wake the device on a precise schedule without the user's say-so.
// iOS has never had, and does not have, anything resembling it: a local
// notification scheduled for a precise time on iOS always fires at that
// time, so there is no permission to hold and nothing to deny. This port's
// two exact-alarm members therefore always answer as if the permission were
// granted on iOS -- not because the adapter assumes the best case, but
// because "the restriction does not exist here" and "the restriction is
// granted" are the same caller-visible fact, and reporting anything else
// would either invent a channel call the platform has no handler for (a
// throw) or manufacture a restriction that was never real (a false
// degradation) -- precisely the failure AD-14 exists to prevent, from the
// other direction.
//
// WHY ONE PORT, NOT TWO. AD-17 names a single authority for both notification
// and exact-alarm permission. Splitting this into `NotificationPermission`
// and `ExactAlarmPermission` ports would let a future caller read one without
// the other consistently, which is the exact divergence AD-17 exists to
// prevent -- the same reasoning `DoseNotifier` gives for staying one port
// covering every tier of a Dose's notifications rather than one per tier.

/// Reads and requests the OS's notification and exact-alarm permission
/// state, and opens the platform's own notification settings screen
/// (AD-17).
///
/// The one and only authority for any of this in the whole app:
/// `permission_handler` is permanently forbidden (AD-17), and no feature may
/// call `flutter_local_notifications`'s own permission APIs directly --
/// `test/story_scope_test.dart` fails the build on either.
abstract interface class PermissionGateway {
  /// Whether the OS currently allows this app to show notifications.
  ///
  /// Never prompts -- this is a read of the OS's already-decided answer, not
  /// a request. Safe to call before the user has ever been asked: it simply
  /// reports whatever the OS holds for an undecided state, without showing a
  /// dialog.
  Future<bool> areNotificationsEnabled();

  /// Asks the OS to grant notification permission, and returns its answer.
  ///
  /// Shows the OS's own permission dialog the first time this is called.
  /// Calling it again after the user has already decided does not re-prompt
  /// on either platform -- it silently returns the existing decision, which
  /// is exactly the trap AD-17 exists to keep a second call site from hitting
  /// by surprise.
  Future<bool> requestNotificationsPermission();

  /// Whether exact-alarm scheduling is currently permitted.
  ///
  /// **Android-only restriction.** Reflects the OS's real, current answer.
  /// **Always `true` on iOS** -- there is no such restriction to hold or
  /// deny on that platform, so this never throws and never probes a
  /// nonexistent channel there.
  Future<bool> canScheduleExactAlarms();

  /// Asks the OS to grant exact-alarm scheduling, and returns its answer.
  ///
  /// **Android-only restriction.** Android has no in-app dialog for this
  /// permission (unlike notification permission); granting it routes through
  /// the OS's own settings screen.
  /// **A pure Dart no-op on iOS**, resolving `true` immediately -- no channel
  /// call is made, because there is nothing on that platform to ask for.
  Future<bool> requestExactAlarmsPermission();

  /// Opens this platform's own notification settings screen for the app.
  ///
  /// The route a permission-denied banner offers once denial has already
  /// happened (Story 3.1b) -- this story ships the capability with no caller.
  Future<bool> openAppNotificationSettings();
}
