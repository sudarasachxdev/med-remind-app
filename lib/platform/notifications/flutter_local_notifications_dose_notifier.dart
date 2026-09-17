// The one real `DoseNotifier` adapter (AD-6, AD-7): converts a Dose's stored
// wall-clock time and IANA zone into a `tz.TZDateTime` and calls
// `flutter_local_notifications`'s own `zonedSchedule`, and recomputes all
// four tier ids to cancel with no lookup table (AD-4, AD-7).
//
// This is the second file in this product permitted to import
// `flutter_local_notifications` -- `test/story_scope_test.dart`'s
// `_directoryScopedImports` now names both `lib/platform/permissions`
// (Story 3.1a's `PermissionGateway` adapter) and `lib/platform/notifications`
// (this one) as its two homes.
//
// A RAW `DateTime` IS NEVER PASSED TO THE PLUGIN. Every fire time this file
// computes is converted through `tz.TZDateTime.from(instant, location)`
// before it reaches `zonedSchedule`, even for `primary`, where
// `dose.scheduledAt` already is a `tz.TZDateTime` in the right `Location` --
// the conversion is then a no-op, but it is the same code path every tier
// goes through, so there is exactly one place this story's own acceptance
// criterion ("a raw DateTime is never passed to the plugin") could be
// violated, not four.
//
// AD-14, LANDED HERE (Story 3.3, deferred twice before now). `schedule()`
// asks `PermissionGateway.canScheduleExactAlarms()` fresh on every call --
// never cached -- and falls back to `AndroidScheduleMode.inexactAllowWhileIdle`
// when it answers `false`. Fresh on every call because the user can flip the
// OS setting between one Dose being scheduled and the next; a value cached at
// construction could keep falling back long after the permission was
// granted, or the reverse.
//
// THE NOTIFICATION-TAP ROUTE (Story 3.3) lives in this file too --
// `notificationTaps`, wired through `initialize()`'s
// `onDidReceiveNotificationResponse` and a one-time
// `getNotificationAppLaunchDetails()` check for the cold-launch case. See
// that member's own doc comment for the two paths it covers.
//
// `onDidReceiveBackgroundNotificationResponse` IS NEVER PASSED TO
// `initialize()` -- AD-3's one-process rule, and this story's own acceptance
// criterion ("the app registers no background notification handler").
//
// `payload: dose.id` IS NOT A PARAMETER. `schedule()` already receives
// `dose`; deriving the payload here makes "the payload carries a doseId
// only" (Story 3.3's own acceptance criterion) a structural guarantee of
// this adapter rather than a convention every future caller has to
// remember.

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/model/dose.dart';
import '../../domain/policy/notification_id_policy.dart';
import '../../domain/port/dose_notifier.dart';
import '../../domain/port/permission_gateway.dart';

/// The one Android notification channel every scheduled reminder posts to.
///
/// A single channel: every tier this adapter schedules -- primary,
/// follow-up, final follow-up, snooze -- is the same kind of thing from the
/// user's point of view (a dose reminder), so there is no reason to split
/// them into channels a user would have to manage separately in the OS
/// notification settings.
const String _doseRemindersChannelId = 'dose_reminders';
const String _doseRemindersChannelName = 'Dose reminders';
const String _doseRemindersChannelDescription =
    'Reminders to take a scheduled dose, including follow-up escalations.';

/// The [DoseNotifier] backed by `flutter_local_notifications` (AD-6, AD-7).
final class FlutterLocalNotificationsDoseNotifier implements DoseNotifier {
  /// Creates the adapter over the plugin's already-registered platform
  /// implementation, reading exact-alarm permission from `permissionGateway`
  /// (AD-14) on every [schedule] call.
  FlutterLocalNotificationsDoseNotifier({required this._permissionGateway});

  final PermissionGateway _permissionGateway;

  /// Guards [_ensureInitialized] so `initialize()` is called at most once per
  /// instance, however many times [schedule]/[cancelPending]/
  /// [notificationTaps] run.
  ///
  /// An instance field, not `static`: exactly one instance of this adapter
  /// is ever constructed in a running app (`lib/main.dart`, held by
  /// `dose_notifier_provider.dart` for the process's life), so instance-level
  /// state behaves identically to a process-wide flag there. Unlike before
  /// this story, the constructor is no longer zero-argument, so a `const`
  /// call site can no longer canonicalise every instance into one object the
  /// way `const FlutterLocalNotificationsDoseNotifier()` used to -- a test
  /// that constructs this adapter with a fake `PermissionGateway` gets a
  /// genuinely separate instance, and that instance must run its own real
  /// `initialize()` call (registering its own [_onNotificationResponse]
  /// closure, over its own [_notificationTapController]) rather than finding
  /// a `static` flag already tripped by an earlier test's instance.
  bool _initialized = false;

  /// Buffers a tapped notification's `doseId` until `notificationTapProvider`
  /// -- this stream's one intended listener -- attaches.
  ///
  /// Single-subscription, not broadcast (see [notificationTaps]'s own doc
  /// comment): exactly one listener ever attaches, and a single-subscription
  /// controller buffers events added before that listener does, which is
  /// what makes the cold-launch path below work with no special sequencing
  /// in `main.dart`.
  final StreamController<String> _notificationTapController =
      StreamController<String>();

  /// Guards the one-time [_plugin.getNotificationAppLaunchDetails] check in
  /// [notificationTaps], the same way [_initialized] guards
  /// `_plugin.initialize`.
  bool _launchDetailsChecked = false;

  FlutterLocalNotificationsPlugin get _plugin =>
      FlutterLocalNotificationsPlugin();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested separately, through `PermissionGateway`
          // (AD-17, Story 3.1). This adapter must not re-prompt on its own.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      // No `onDidReceiveBackgroundNotificationResponse` -- see this file's
      // own header comment.
    );
    _initialized = true;
  }

  /// Routes a tap to [_notificationTapController]; drops everything else.
  ///
  /// A dismissal fires this SAME plugin callback, carrying
  /// `NotificationResponseType.notificationDismissed` instead of
  /// `.selectedNotification` -- this filter is the one thing keeping "the
  /// user dismisses the notification... nothing further happens" true. A
  /// `null` payload (should never happen -- [schedule] always sets one) is
  /// dropped rather than added, since the port promises a `doseId`, not a
  /// nullable one.
  void _onNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotification) {
      return;
    }
    final String? payload = response.payload;
    if (payload != null) {
      _notificationTapController.add(payload);
    }
  }

  @override
  Stream<String> get notificationTaps {
    if (!_launchDetailsChecked) {
      _launchDetailsChecked = true;
      // Fire-and-forget: a getter cannot be `async`, and nothing here needs
      // to block the caller -- `notificationTapProvider`'s own `StreamProvider`
      // watches the returned stream regardless of when this resolves.
      unawaited(_checkColdLaunch());
    }
    return _notificationTapController.stream;
  }

  /// The cold-launch case: the app was fully closed and a notification tap
  /// started the process. The live [_onNotificationResponse] callback never
  /// sees this tap -- it is only wired up once `initialize()` has returned,
  /// which is after the process (and the tap that started it) already
  /// happened -- so this reads it back explicitly, once, from
  /// `getNotificationAppLaunchDetails()`.
  Future<void> _checkColdLaunch() async {
    await _ensureInitialized();
    final NotificationAppLaunchDetails? launchDetails = await _plugin
        .getNotificationAppLaunchDetails();
    if (launchDetails == null || !launchDetails.didNotificationLaunchApp) {
      return;
    }
    final String? payload = launchDetails.notificationResponse?.payload;
    if (payload != null) {
      _notificationTapController.add(payload);
    }
  }

  @override
  Future<void> schedule({
    required Dose dose,
    required NotificationTier tier,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    final tz.Location location = tz.getLocation(dose.ianaTimezone);
    final tz.TZDateTime fireTime = tz.TZDateTime.from(
      _instant(dose, tier),
      location,
    );

    // AD-14: read fresh on every call, never cached -- the user can flip the
    // OS setting between one Dose being scheduled and the next.
    final bool exactAlarmsAllowed = await _permissionGateway
        .canScheduleExactAlarms();

    await _plugin.zonedSchedule(
      id: notificationId(dose.id, tier),
      title: title,
      body: body,
      scheduledDate: fireTime,
      payload: dose.id,
      androidScheduleMode: exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _doseRemindersChannelId,
          _doseRemindersChannelName,
          channelDescription: _doseRemindersChannelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> cancelPending(String doseId) async {
    await _ensureInitialized();
    for (final NotificationTier tier in NotificationTier.values) {
      await _plugin.cancel(id: notificationId(doseId, tier));
    }
  }

  /// The absolute instant [tier]'s notification fires at, for [dose] --
  /// before it has been converted to [dose.ianaTimezone]'s `tz.Location`.
  ///
  /// `primary` reads `dose.scheduledAt` directly (already a `tz.TZDateTime`
  /// in the right `Location`, per `Dose`'s own constructor). `followUp` and
  /// `finalFollowUp` add `dose.followUpOffsetsMinutes[0]`/`[1]` -- never the
  /// whole list, and never index `[2]`, which is not a notification offset
  /// (`dose_resolution_policy.dart`'s own doc comment). `snooze` reads
  /// `dose.snoozedUntil`, asserted non-null: a caller only ever schedules
  /// this tier once a snooze exists.
  DateTime _instant(Dose dose, NotificationTier tier) {
    switch (tier) {
      case NotificationTier.primary:
        return dose.scheduledAt;
      case NotificationTier.followUp:
        return dose.scheduledAt.add(
          Duration(minutes: dose.followUpOffsetsMinutes[0]),
        );
      case NotificationTier.finalFollowUp:
        return dose.scheduledAt.add(
          Duration(minutes: dose.followUpOffsetsMinutes[1]),
        );
      case NotificationTier.snooze:
        final DateTime? snoozedUntil = dose.snoozedUntil;
        assert(
          snoozedUntil != null,
          'schedule() with NotificationTier.snooze requires '
          'dose.snoozedUntil to already be set -- a caller only schedules '
          'this tier once a snooze exists.',
        );
        return snoozedUntil!;
    }
  }
}
