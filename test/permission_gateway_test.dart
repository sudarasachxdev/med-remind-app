// `FlutterLocalNotificationsPermissionGateway` -- one test per I/O matrix row
// (LIGHTER, project-context.md). The platform branching is the thing worth
// testing precisely, not exhaustively: every scenario below sets up exactly
// one platform and one channel answer, then checks the one thing that row
// promises.
//
// The plugin's own platform resolution
// (`resolvePlatformSpecificImplementation`) reads `defaultTargetPlatform` and
// `FlutterLocalNotificationsPlatform.instance`, both overridable in a test --
// unlike `dart:io`'s `Platform.isAndroid`, which reads the real host OS the
// test runs on and cannot be faked. Each test therefore registers the
// platform implementation under test, overrides
// `debugDefaultTargetPlatformOverride`, and stubs the plugin's own method
// channel (`dexterous.com/flutter/local_notifications`) -- the same shape
// `clock_test.dart` uses for `flutter_timezone`'s channel.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/port/permission_gateway.dart';
import 'package:med_remind_app/platform/permissions/flutter_local_notifications_permission_gateway.dart';

const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

/// Registers [platform]'s plugin implementation as the one
/// `resolvePlatformSpecificImplementation` will resolve, stubs the plugin's
/// channel with [handler], and tears both back down after the test.
void _givenPlatform(
  TargetPlatform platform,
  Future<Object?> Function(MethodCall call) handler,
) {
  debugDefaultTargetPlatformOverride = platform;
  switch (platform) {
    case TargetPlatform.android:
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    case TargetPlatform.iOS:
      IOSFlutterLocalNotificationsPlugin.registerWith();
    default:
      throw ArgumentError('not used by this test: $platform');
  }
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const PermissionGateway gateway =
      FlutterLocalNotificationsPermissionGateway();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('requests notification permission on Android via '
      'requestNotificationsPermission, and returns the OS answer', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.android, (MethodCall call) async {
      calls.add(call.method);
      return true;
    });

    final bool granted = await gateway.requestNotificationsPermission();

    expect(granted, isTrue);
    expect(calls, <String>['requestNotificationsPermission']);
  });

  test(
    'requests notification permission on iOS via the platform '
    "implementation's own requestPermissions, and returns the OS answer",
    () async {
      final List<String> calls = <String>[];
      _givenPlatform(TargetPlatform.iOS, (MethodCall call) async {
        calls.add(call.method);
        return false;
      });

      final bool granted = await gateway.requestNotificationsPermission();

      expect(granted, isFalse);
      expect(calls, <String>['requestPermissions']);
    },
  );

  test('reads the current notification permission state without re-prompting, '
      'on Android', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.android, (MethodCall call) async {
      calls.add(call.method);
      return false; // already decided: denied
    });

    final bool enabled = await gateway.areNotificationsEnabled();

    expect(enabled, isFalse);
    expect(calls, <String>[
      'areNotificationsEnabled',
    ], reason: 'a read must never invoke a request method');
  });

  test('reads the current notification permission state on iOS via '
      "checkPermissions, not requestPermissions with every flag false -- the "
      'native implementation short-circuits the latter to an unconditional '
      'false rather than reporting the real state (this adapter\'s own file '
      'comment)', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.iOS, (MethodCall call) async {
      calls.add(call.method);
      return <String, Object?>{'isEnabled': true};
    });

    final bool enabled = await gateway.areNotificationsEnabled();

    expect(enabled, isTrue);
    expect(calls, <String>[
      'checkPermissions',
    ], reason: 'a read must never invoke requestPermissions');
  });

  test('a null checkPermissions answer on iOS reads as not enabled, never as '
      'a throw', () async {
    _givenPlatform(TargetPlatform.iOS, (MethodCall call) async => null);

    final bool enabled = await gateway.areNotificationsEnabled();

    expect(enabled, isFalse);
  });

  test('requests exact-alarm permission on Android via '
      'requestExactAlarmsPermission', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.android, (MethodCall call) async {
      calls.add(call.method);
      return true;
    });

    final bool granted = await gateway.requestExactAlarmsPermission();

    expect(granted, isTrue);
    expect(calls, <String>['requestExactAlarmsPermission']);
  });

  test('requesting exact-alarm permission on iOS is a no-op that resolves true '
      'immediately, with no channel call made', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.iOS, (MethodCall call) async {
      calls.add(call.method);
      return null;
    });

    final bool granted = await gateway.requestExactAlarmsPermission();

    expect(granted, isTrue);
    expect(
      calls,
      isEmpty,
      reason: 'no exact-alarm channel method exists on the iOS implementation',
    );
  });

  test('reads exact-alarm permission on Android via canScheduleExactAlarms\'s '
      'real answer', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.android, (MethodCall call) async {
      calls.add(call.method);
      return false; // denied
    });

    final bool canSchedule = await gateway.canScheduleExactAlarms();

    expect(canSchedule, isFalse);
    expect(calls, <String>['canScheduleExactNotifications']);
  });

  test('reading exact-alarm permission on iOS is always true, with no channel '
      'call made -- the restriction does not exist on that platform', () async {
    final List<String> calls = <String>[];
    _givenPlatform(TargetPlatform.iOS, (MethodCall call) async {
      calls.add(call.method);
      return null;
    });

    final bool canSchedule = await gateway.canScheduleExactAlarms();

    expect(canSchedule, isTrue);
    expect(calls, isEmpty);
  });

  test(
    'opens OS notification settings by delegating to the running '
    "platform's own openAppNotificationSettings, on either platform",
    () async {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final List<String> calls = <String>[];
        _givenPlatform(platform, (MethodCall call) async {
          calls.add(call.method);
          return true;
        });

        final bool opened = await gateway.openAppNotificationSettings();

        expect(opened, isTrue, reason: 'on $platform');
        expect(calls, <String>[
          'openAppNotificationSettings',
        ], reason: 'on $platform');
      }
    },
  );
}
