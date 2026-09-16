// A scriptable `PermissionGateway` for tests that must not touch
// flutter_local_notifications.
//
// Not a mock framework: two settable answers and three call counters cover
// every row of this story's own matrix that reads or requests permission --
// `permission_gateway_test.dart` already proves the real adapter's platform
// branching, so nothing here re-verifies that.

import 'package:med_remind_app/domain/port/permission_gateway.dart';

/// A [PermissionGateway] whose answers are set directly, and whose calls are
/// counted.
final class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway({
    this.notificationsEnabled = true,
    this.exactAlarmsAllowed = true,
  });

  /// What [areNotificationsEnabled] answers, and what
  /// [requestNotificationsPermission] resolves to.
  bool notificationsEnabled;

  /// What the two exact-alarm members answer. Unused by this story (Story
  /// 3.3's own concern), kept so a fake this shape can be reused there
  /// without a second one.
  bool exactAlarmsAllowed;

  /// How many times [areNotificationsEnabled] was read.
  int areNotificationsEnabledCalls = 0;

  /// How many times [requestNotificationsPermission] was called.
  int requestNotificationsPermissionCalls = 0;

  /// How many times [openAppNotificationSettings] was called.
  int openAppNotificationSettingsCalls = 0;

  @override
  Future<bool> areNotificationsEnabled() async {
    areNotificationsEnabledCalls++;
    return notificationsEnabled;
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    requestNotificationsPermissionCalls++;
    return notificationsEnabled;
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowed;

  @override
  Future<bool> requestExactAlarmsPermission() async => exactAlarmsAllowed;

  @override
  Future<bool> openAppNotificationSettings() async {
    openAppNotificationSettingsCalls++;
    return true;
  }
}
