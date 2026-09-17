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
// UNCONDITIONAL `exactAllowWhileIdle`. Story 3.1b deferred the
// `canScheduleExactAlarms()` check and its `inexactAllowWhileIdle` fallback
// to Story 3.3, the first story with a real `zonedSchedule` call site for it
// to modify (AD-14, epics.md note dated 2026-09-16). Building that branch
// here would mean Story 3.3 edits a branch this story wrote rather than
// adding one, and would need `PermissionGateway` wired into a port AD-1
// keeps import-light. Do not add it here.
//
// NO `onDidReceiveNotificationResponse` CALLBACK YET. Story 3.3 adds it to
// this same `initialize()` call, for the tap-to-open-action-sheet route. An
// empty placeholder here would be dead code with nothing to call it.
//
// `payload: dose.id` IS NOT A PARAMETER. `schedule()` already receives
// `dose`; deriving the payload here makes "the payload carries a doseId
// only" (Story 3.3's own acceptance criterion) a structural guarantee of
// this adapter rather than a convention every future caller has to
// remember.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/model/dose.dart';
import '../../domain/policy/notification_id_policy.dart';
import '../../domain/port/dose_notifier.dart';

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
  /// implementation.
  ///
  /// Takes nothing, matching `FlutterLocalNotificationsPermissionGateway`:
  /// `FlutterLocalNotificationsPlugin()` is itself a singleton factory, so
  /// there is exactly one meaningful instance to hold in a running app.
  const FlutterLocalNotificationsDoseNotifier();

  /// Guards [_ensureInitialized] so `initialize()` is called at most once per
  /// process, however many times [schedule]/[cancelPending] run.
  ///
  /// `static`, not an instance field: this adapter is constructed `const`,
  /// so every instance shares the same underlying plugin registration
  /// anyway, and a `static` flag is what keeps a second `const
  /// FlutterLocalNotificationsDoseNotifier()` (a fresh instance, same
  /// identity under `const`) from re-initializing.
  static bool _initialized = false;

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
    );
    _initialized = true;
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

    await _plugin.zonedSchedule(
      id: notificationId(dose.id, tier),
      title: title,
      body: body,
      scheduledDate: fireTime,
      payload: dose.id,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
