// `FlutterLocalNotificationsDoseNotifier` -- following
// `permission_gateway_test.dart`'s method-channel-stub pattern (AD-19: pure
// unit test, no device, an injected `tz.TZDateTime`-bearing `Dose` standing
// in for a clock).
//
// Unlike `FlutterLocalNotificationsPermissionGateway`, this adapter does no
// platform branching of its own -- `schedule`/`cancelPending` call straight
// through to the base `FlutterLocalNotificationsPlugin`, which does its own
// platform dispatch internally. One registered platform (Android) is enough
// to prove this file's own logic: fire-time computation, id derivation, and
// payload/id wiring -- there is no second branch of this adapter's own code
// a second platform would exercise.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';
import 'package:med_remind_app/platform/notifications/flutter_local_notifications_dose_notifier.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  const DoseNotifier notifier = FlutterLocalNotificationsDoseNotifier();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Dose buildDose({
    required DateTime scheduledLocal,
    String ianaTimezone = 'Asia/Colombo',
    DateTime? snoozedUntil,
  }) => Dose(
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    scheduledLocal: scheduledLocal,
    ianaTimezone: ianaTimezone,
    snoozedUntil: snoozedUntil,
    escalationWindowMinutes: 60,
    medicineName: 'Candesartan',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    form: 'tablet',
  );

  MethodCall zonedScheduleCall() =>
      calls.singleWhere((MethodCall c) => c.method == 'zonedSchedule');

  Map<Object?, Object?> zonedScheduleArgs() =>
      zonedScheduleCall().arguments as Map<Object?, Object?>;

  test('schedule(primary) fires at dose.scheduledAt, unmodified, and calls '
      'zonedSchedule with the derived id and dose.id as the payload', () async {
    final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

    await notifier.schedule(
      dose: dose,
      tier: NotificationTier.primary,
      title: 'Take Candesartan',
      body: '1 tablet',
    );

    final Map<Object?, Object?> args = zonedScheduleArgs();
    expect(args['id'], notificationId(dose.id, NotificationTier.primary));
    expect(args['payload'], dose.id);
    expect(args['title'], 'Take Candesartan');
    expect(args['body'], '1 tablet');
    expect(args['scheduledDateTime'], '2027-01-15T08:00:00');
    expect(args['timeZoneName'], 'Asia/Colombo');
  });

  test('the primary fire time keeps its 08:00 wall clock across a DST '
      'transition (America/New_York, winter vs. summer) -- a raw DateTime is '
      'never passed to the plugin', () async {
    final Dose winter = buildDose(
      scheduledLocal: DateTime(2027, 1, 15, 8),
      ianaTimezone: 'America/New_York',
    );
    final Dose summer = buildDose(
      scheduledLocal: DateTime(2027, 7, 15, 8),
      ianaTimezone: 'America/New_York',
    );

    await notifier.schedule(
      dose: winter,
      tier: NotificationTier.primary,
      title: 'T',
      body: 'B',
    );
    final Map<Object?, Object?> winterArgs = zonedScheduleArgs();
    calls.clear();

    await notifier.schedule(
      dose: summer,
      tier: NotificationTier.primary,
      title: 'T',
      body: 'B',
    );
    final Map<Object?, Object?> summerArgs = zonedScheduleArgs();

    expect(
      winterArgs['scheduledDateTime'],
      '2027-01-15T08:00:00',
      reason: 'EST (winter): still 08:00 local, not shifted',
    );
    expect(
      summerArgs['scheduledDateTime'],
      '2027-07-15T08:00:00',
      reason: 'EDT (summer): still 08:00 local, not shifted',
    );
    expect(
      winterArgs['scheduledDateTimeISO8601'],
      contains('-0500'),
      reason: 'EST is UTC-5',
    );
    expect(
      summerArgs['scheduledDateTimeISO8601'],
      contains('-0400'),
      reason:
          'EDT is UTC-4 -- the underlying instant really did shift by an '
          'hour of UTC offset even though the wall clock this proves stays '
          'put is what a real DST-crossing fire time must do',
    );
  });

  test(
    'schedule(followUp) fires at scheduledAt + followUpOffsetsMinutes[0]',
    () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.followUp,
        title: 'T',
        body: 'B',
      );

      final Map<Object?, Object?> args = zonedScheduleArgs();
      expect(args['id'], notificationId(dose.id, NotificationTier.followUp));
      expect(args['payload'], dose.id);
      expect(args['scheduledDateTime'], '2027-01-15T08:15:00');
    },
  );

  test('schedule(finalFollowUp) fires at scheduledAt + '
      'followUpOffsetsMinutes[1]', () async {
    final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

    await notifier.schedule(
      dose: dose,
      tier: NotificationTier.finalFollowUp,
      title: 'T',
      body: 'B',
    );

    final Map<Object?, Object?> args = zonedScheduleArgs();
    expect(args['id'], notificationId(dose.id, NotificationTier.finalFollowUp));
    expect(args['payload'], dose.id);
    expect(args['scheduledDateTime'], '2027-01-15T08:30:00');
  });

  test('schedule(snooze) fires at dose.snoozedUntil', () async {
    // 09:05 UTC == 14:35 in Asia/Colombo (+05:30, no DST).
    final DateTime snoozedUntil = DateTime.utc(2027, 1, 15, 9, 5);
    final Dose dose = buildDose(
      scheduledLocal: DateTime(2027, 1, 15, 8),
      snoozedUntil: snoozedUntil,
    );

    await notifier.schedule(
      dose: dose,
      tier: NotificationTier.snooze,
      title: 'T',
      body: 'B',
    );

    final Map<Object?, Object?> args = zonedScheduleArgs();
    expect(args['id'], notificationId(dose.id, NotificationTier.snooze));
    expect(args['payload'], dose.id);
    expect(args['scheduledDateTime'], '2027-01-15T14:35:00');
    expect(args['timeZoneName'], 'Asia/Colombo');
  });

  test('cancelPending calls cancel exactly four times, with the four tier ids '
      'and no others', () async {
    const String doseId = 'dose-1';

    await notifier.cancelPending(doseId);

    final List<MethodCall> cancelCalls = calls
        .where((MethodCall c) => c.method == 'cancel')
        .toList();
    expect(cancelCalls, hasLength(NotificationTier.values.length));

    final Set<int> expectedIds = NotificationTier.values
        .map((NotificationTier tier) => notificationId(doseId, tier))
        .toSet();
    final Set<int> actualIds = cancelCalls
        .map(
          (MethodCall c) =>
              (c.arguments as Map<Object?, Object?>)['id']! as int,
        )
        .toSet();
    expect(actualIds, expectedIds);
  });
}
