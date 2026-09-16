// A PermissionGateway that exists to be bound, not called.
//
// Mirrors `unused_dose_repository.dart`/`unused_medicine_repository.dart`: the
// startup tests assert that the composition root BINDS a gateway -- dropping
// that override is invisible until Home tries to read it, and then it throws
// in front of the user. They assert nothing about what it answers.
//
// So every method throws, deliberately. A fake that quietly answered "granted"
// would let a test pass while silently exercising a gateway that speaks for no
// real OS. If a future test needs real behaviour it should use
// `FakePermissionGateway`, as `home_plan_test.dart` and `home_screen_test.dart`
// already do.

import 'package:med_remind_app/domain/port/permission_gateway.dart';

/// A [PermissionGateway] whose every method throws [UnsupportedError].
final class UnusedPermissionGateway implements PermissionGateway {
  /// Creates the stand-in.
  const UnusedPermissionGateway();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedPermissionGateway.$method was called. This stand-in exists to be '
    'bound by a startup test, not to answer. Use FakePermissionGateway if the '
    'test needs a real answer.',
  );

  @override
  Future<bool> areNotificationsEnabled() => _unused('areNotificationsEnabled');

  @override
  Future<bool> requestNotificationsPermission() =>
      _unused('requestNotificationsPermission');

  @override
  Future<bool> canScheduleExactAlarms() => _unused('canScheduleExactAlarms');

  @override
  Future<bool> requestExactAlarmsPermission() =>
      _unused('requestExactAlarmsPermission');

  @override
  Future<bool> openAppNotificationSettings() =>
      _unused('openAppNotificationSettings');
}
