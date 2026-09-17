// A DoseNotifier that exists to be bound, not called.
//
// Mirrors `unused_permission_gateway.dart`: the startup tests assert that the
// composition root BINDS a notifier -- dropping that override is invisible
// until a Dose is recorded, and then it throws in front of the user. They
// assert nothing about what it does.
//
// So every method throws, deliberately. A fake that quietly succeeded would
// let a test pass while silently exercising a notifier that schedules and
// cancels nothing real. If a future test needs real behaviour it should use
// `FakeDoseNotifier`, as `dose_recorder_test.dart` already does.

import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';

/// A [DoseNotifier] whose every method throws [UnsupportedError].
final class UnusedDoseNotifier implements DoseNotifier {
  /// Creates the stand-in.
  const UnusedDoseNotifier();

  Never _unused(String method) => throw UnsupportedError(
    'UnusedDoseNotifier.$method was called. This stand-in exists to be '
    'bound by a startup test, not to answer. Use FakeDoseNotifier if the '
    'test needs real behaviour.',
  );

  @override
  Future<void> schedule({
    required Dose dose,
    required NotificationTier tier,
    required String title,
    required String body,
  }) => _unused('schedule');

  @override
  Future<void> cancelPending(String doseId) => _unused('cancelPending');

  @override
  Stream<String> get notificationTaps => _unused('notificationTaps');
}
