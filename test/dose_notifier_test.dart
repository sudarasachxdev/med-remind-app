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
//
// A fresh `notifier` is constructed in `setUp` for EVERY test, rather than
// shared as one file-level `const` the way Story 3.2 left it: Story 3.3's
// `notificationTaps` is a single-subscription stream, which can only ever be
// listened to once over its lifetime, and its own cold-launch check
// (`getNotificationAppLaunchDetails`) needs a per-test answer. `_initialized`
// therefore moved from a `static` guard to an instance field (see that
// field's own doc comment in the adapter) -- with a fresh instance per test,
// this is the only shape that keeps every test's `initialize()` call, and
// every test's own tap stream, independent of every other test's.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';
import 'package:med_remind_app/platform/notifications/flutter_local_notifications_dose_notifier.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_permission_gateway.dart';

const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  late List<MethodCall> calls;
  late FakePermissionGateway permissionGateway;
  late DoseNotifier notifier;

  /// What the mocked `getNotificationAppLaunchDetails` channel call answers.
  /// `null` (the default) means "no launch details" -- an ordinary warm
  /// start, not one caused by a notification tap.
  Map<Object?, Object?>? launchDetailsResponse;

  setUp(() {
    calls = <MethodCall>[];
    launchDetailsResponse = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'getNotificationAppLaunchDetails':
              return launchDetailsResponse;
            default:
              return null;
          }
        });
    permissionGateway = FakePermissionGateway();
    notifier = FlutterLocalNotificationsDoseNotifier(
      permissionGateway: permissionGateway,
    );
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

  /// Delivers a platform-to-Dart notification-response call, exactly as
  /// `AndroidFlutterLocalNotificationsPlugin._handleMethod` decodes it
  /// (`didReceiveNotificationResponse`, verified against the installed
  /// 22.3.0 source). This is the one channel direction
  /// `setMockMethodCallHandler` cannot fake -- that only intercepts calls
  /// FROM Dart -- so it goes through
  /// `defaultBinaryMessenger.handlePlatformMessage` instead, the same path
  /// the real native side uses to invoke a registered method channel
  /// handler.
  Future<void> deliverNotificationResponse({
    required String? payload,
    required NotificationResponseType type,
  }) async {
    final ByteData message = const StandardMethodCodec().encodeMethodCall(
      MethodCall('didReceiveNotificationResponse', <String, Object?>{
        'notificationId': 1,
        'actionId': null,
        'input': null,
        'payload': payload,
        'notificationResponseType': type.index,
      }),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_channel.name, message, (ByteData? _) {});
  }

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

  group('AD-14: the exact-alarm fallback', () {
    test('exact alarms allowed: schedules with exactAllowWhileIdle', () async {
      permissionGateway.exactAlarmsAllowed = true;
      final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.primary,
        title: 'T',
        body: 'B',
      );

      final Map<Object?, Object?> platformSpecifics =
          zonedScheduleArgs()['platformSpecifics'] as Map<Object?, Object?>;
      expect(
        platformSpecifics['scheduleMode'],
        AndroidScheduleMode.exactAllowWhileIdle.name,
      );
    });

    test('exact alarms denied: falls back to inexactAllowWhileIdle', () async {
      permissionGateway.exactAlarmsAllowed = false;
      final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.primary,
        title: 'T',
        body: 'B',
      );

      final Map<Object?, Object?> platformSpecifics =
          zonedScheduleArgs()['platformSpecifics'] as Map<Object?, Object?>;
      expect(
        platformSpecifics['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
        reason:
            'AD-14: denied exact-alarm permission degrades to an inexact '
            'fire time rather than failing to schedule at all',
      );
    });

    test('reads the permission fresh on every call, not cached', () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

      permissionGateway.exactAlarmsAllowed = false;
      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.primary,
        title: 'T',
        body: 'B',
      );
      final String firstMode =
          (zonedScheduleArgs()['platformSpecifics']
                  as Map<Object?, Object?>)['scheduleMode']!
              as String;
      calls.clear();

      permissionGateway.exactAlarmsAllowed = true;
      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.primary,
        title: 'T',
        body: 'B',
      );
      final String secondMode =
          (zonedScheduleArgs()['platformSpecifics']
                  as Map<Object?, Object?>)['scheduleMode']!
              as String;

      expect(firstMode, AndroidScheduleMode.inexactAllowWhileIdle.name);
      expect(secondMode, AndroidScheduleMode.exactAllowWhileIdle.name);
    });
  });

  group('AD-3: no action buttons, no background handler', () {
    test('the NotificationDetails passed to zonedSchedule carries no '
        'actions', () async {
      final Dose dose = buildDose(scheduledLocal: DateTime(2027, 1, 15, 8));

      await notifier.schedule(
        dose: dose,
        tier: NotificationTier.primary,
        title: 'T',
        body: 'B',
      );

      final Map<Object?, Object?> platformSpecifics =
          zonedScheduleArgs()['platformSpecifics'] as Map<Object?, Object?>;
      expect(
        platformSpecifics.containsKey('actions'),
        isFalse,
        reason:
            'AD-3: a tap opens the action sheet; the notification itself '
            'offers no in-line buttons',
      );
    });

    test("initialize's call arguments never include a background-response "
        'handler', () async {
      await notifier.cancelPending('dose-1');

      final MethodCall initializeCall = calls.singleWhere(
        (MethodCall c) => c.method == 'initialize',
      );
      final Map<Object?, Object?> args =
          initializeCall.arguments as Map<Object?, Object?>;
      expect(
        args.containsKey('dispatcher_handle'),
        isFalse,
        reason:
            'AD-3: no background isolate handler is ever registered '
            '(both keys are only added when '
            'onDidReceiveBackgroundNotificationResponse is passed)',
      );
      expect(args.containsKey('callback_handle'), isFalse);
    });
  });

  group('notificationTaps: the route into the app', () {
    test(
      'a live tap (selectedNotification) adds to notificationTaps',
      () async {
        final List<String> received = <String>[];
        notifier.notificationTaps.listen(received.add);
        await pumpEventQueue();

        await deliverNotificationResponse(
          payload: 'dose-1',
          type: NotificationResponseType.selectedNotification,
        );
        await pumpEventQueue();

        expect(received, <String>['dose-1']);
      },
    );

    test(
      'a dismissal (notificationDismissed) does not add to notificationTaps',
      () async {
        final List<String> received = <String>[];
        notifier.notificationTaps.listen(received.add);
        await pumpEventQueue();

        await deliverNotificationResponse(
          payload: 'dose-1',
          type: NotificationResponseType.notificationDismissed,
        );
        await pumpEventQueue();

        expect(
          received,
          isEmpty,
          reason:
              'dismissing the notification without opening the app must do '
              'nothing further',
        );
      },
    );

    test('getNotificationAppLaunchDetails reporting didNotificationLaunchApp: '
        'true seeds the stream before any listener attaches, and the buffered '
        'event is still delivered once one does', () async {
      launchDetailsResponse = <Object?, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <Object?, Object?>{
          'notificationId': 1,
          'actionId': null,
          'input': null,
          'payload': 'dose-cold-launch',
          'notificationResponseType':
              NotificationResponseType.selectedNotification.index,
        },
      };

      // Accessing the getter is what triggers the cold-launch check
      // (lazily, per the adapter's own doc comment) -- no listener attaches
      // yet, so the event this seeds must be buffered rather than dropped.
      final Stream<String> taps = notifier.notificationTaps;
      await pumpEventQueue();

      final List<String> received = <String>[];
      taps.listen(received.add);
      await pumpEventQueue();

      expect(received, <String>['dose-cold-launch']);
    });

    test(
      'no cold-launch details: notificationTaps stays empty until a live tap',
      () async {
        final List<String> received = <String>[];
        notifier.notificationTaps.listen(received.add);
        await pumpEventQueue();

        expect(received, isEmpty);
      },
    );
  });
}
