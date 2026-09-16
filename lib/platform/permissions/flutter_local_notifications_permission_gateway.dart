// The one adapter for `PermissionGateway` (AD-17), and the only file in this
// product permitted to import `flutter_local_notifications` --
// `test/story_scope_test.dart`'s directory-scoped-import guard fails the
// build on a second one, the same shape AD-9's amendment gave
// `flutter_timezone` and `lib/platform/clock/`. `lib/platform/notifications/`
// -- the sibling directory Stories 3.2/3.3 build the scheduling adapter into
// -- stays empty; this story is about permission, not scheduling.
//
// PLATFORM BRANCHING: the plugin's own resolution, not `dart:io`.
// `FlutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<T>()`
// already knows which concrete platform implementation is registered for the
// platform actually running, so every method below branches on whichever of
// `_android`/`_ios` comes back non-null rather than asking `dart:io`'s
// `Platform.isAndroid`/`Platform.isIOS` a second, independently-answered
// question. This is also what makes the branching testable at all: a test
// can register a fake platform implementation and set
// `debugDefaultTargetPlatformOverride` (both of which
// `resolvePlatformSpecificImplementation` actually reads), where
// `dart:io`'s `Platform.isAndroid` reads the real host OS the test runs on
// and cannot be overridden.
//
// THE PLUGIN'S VERIFIED API SURFACE (22.3.0) THIS ADAPTER CALLS:
//   Android (`AndroidFlutterLocalNotificationsPlugin`):
//     requestNotificationsPermission, requestExactAlarmsPermission,
//     areNotificationsEnabled, canScheduleExactNotifications -- all
//     `Future<bool?>`.
//   iOS (`IOSFlutterLocalNotificationsPlugin`):
//     requestPermissions({...}) -- `Future<bool?>`.
//     checkPermissions() -- `Future<NotificationsEnabledOptions?>`, read here
//     for [areNotificationsEnabled]'s iOS path. It is a genuine, side-effect
//     free read (`UNUserNotificationCenter.getNotificationSettings`, verified
//     against the plugin's own native source) -- unlike calling
//     `requestPermissions` with every flag `false`, which the native
//     implementation short-circuits to an unconditional `false` rather than
//     reporting the real state, and would misreport a granted permission as
//     denied.
//   Both platforms, via the base plugin (no branching needed --
//   `FlutterLocalNotificationsPlatform.instance` already dispatches to
//   whichever concrete implementation is registered):
//     openAppNotificationSettings -- `Future<bool?>`.
//   iOS has no exact-alarm methods at all -- there is nothing to call, which
//   is why [canScheduleExactAlarms] and [requestExactAlarmsPermission] are a
//   pure Dart answer on that platform, never a channel call.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/port/permission_gateway.dart';

/// The [PermissionGateway] adapter, backed entirely by
/// `flutter_local_notifications`.
final class FlutterLocalNotificationsPermissionGateway
    implements PermissionGateway {
  /// Creates the adapter over the plugin's already-registered platform
  /// implementation.
  ///
  /// Takes nothing: `FlutterLocalNotificationsPlugin()` is itself a
  /// singleton factory, so there is exactly one meaningful instance to hold
  /// in a running app, and re-resolving it per call keeps this adapter
  /// stateless.
  const FlutterLocalNotificationsPermissionGateway();

  FlutterLocalNotificationsPlugin get _plugin =>
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final IOSFlutterLocalNotificationsPlugin? ios = _ios;
    if (ios != null) {
      final NotificationsEnabledOptions? options = await ios.checkPermissions();
      return options?.isEnabled ?? false;
    }
    // Neither platform implementation is registered -- not a platform this
    // port supports. Reporting "not enabled" rather than throwing matches the
    // rest of this adapter's stance: an unknown answer is surfaced as
    // degraded, never as silently working (AD-14).
    return false;
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final IOSFlutterLocalNotificationsPlugin? ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      // iOS (or any platform other than Android this plugin resolves to):
      // the restriction does not exist, so nothing is denied. No channel
      // call is made -- there is no method on the iOS implementation to call.
      return true;
    }
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      // iOS: a pure Dart no-op, resolving `true` immediately. See
      // `permission_gateway.dart` for why this is correct rather than a
      // stand-in for a missing binding.
      return true;
    }
    return await android.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<bool> openAppNotificationSettings() async =>
      await _plugin.openAppNotificationSettings() ?? false;
}
