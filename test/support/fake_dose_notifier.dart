// A scriptable `DoseNotifier` for tests that must not touch
// flutter_local_notifications -- Story 3.2 builds that real adapter, and
// AD-1 keeps every test above it from having to spin up a plugin channel
// just to prove what `DoseRecorder`/a caller of `schedule` did.
//
// Not a mock framework: a call log per method and an optional failure cover
// every row of `dose_recorder_test.dart`'s matrix that mentions notification
// scheduling or cancellation.

import 'dart:async';

import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';

/// A [DoseNotifier] that records every [schedule] and [cancelPending] call,
/// and can be told to fail.
///
/// [notificationTaps] is broadcast, unlike the real adapter's
/// single-subscription stream (see `flutter_local_notifications_dose_notifier
/// .dart`'s own reasoning) -- a test double's job is letting more than one
/// widget pump/listener observe an emitted tap across a test's lifetime,
/// which a single-subscription stream would refuse past the first `.listen`.
final class FakeDoseNotifier implements DoseNotifier {
  FakeDoseNotifier({this.failure});

  /// Thrown by [cancelPending] when set, instead of succeeding.
  final Object? failure;

  /// Every `(doseId, tier, title, body)` [schedule] was called with, in call
  /// order.
  final List<(String, NotificationTier, String, String)> scheduled =
      <(String, NotificationTier, String, String)>[];

  /// Every doseId [cancelPending] was called with, in call order.
  ///
  /// Recorded even when [failure] is set: the call really happened, and a
  /// test proving "the notifier failure still fails the action" needs to see
  /// that cancellation was attempted exactly once, not that it never ran.
  final List<String> cancelled = <String>[];

  @override
  Future<void> schedule({
    required Dose dose,
    required NotificationTier tier,
    required String title,
    required String body,
  }) async {
    scheduled.add((dose.id, tier, title, body));
  }

  @override
  Future<void> cancelPending(String doseId) async {
    cancelled.add(doseId);
    final Object? toThrow = failure;
    if (toThrow != null) throw toThrow;
  }

  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get notificationTaps => _tapController.stream;

  /// Simulates a notification tap arriving for [doseId], live or as a
  /// buffered cold-launch event -- a test's stand-in for a real tap reaching
  /// `notificationTapProvider`.
  void emitTap(String doseId) => _tapController.add(doseId);
}
