// A scriptable `DoseNotifier` for tests that must not touch
// flutter_local_notifications -- Story 3.2 builds that real adapter, and
// AD-1 keeps every test above it from having to spin up a plugin channel
// just to prove what `DoseRecorder`/a caller of `schedule` did.
//
// Not a mock framework: a call log per method and an optional failure cover
// every row of `dose_recorder_test.dart`'s matrix that mentions notification
// scheduling or cancellation.

import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/port/dose_notifier.dart';

/// A [DoseNotifier] that records every [schedule] and [cancelPending] call,
/// and can be told to fail.
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
}
