// A scriptable `DoseNotifier` for tests that must not touch
// flutter_local_notifications -- which is not a real adapter yet: Epic 3
// builds it, and AD-4's boundaries keep `lib/platform/notifications/` empty
// until then.
//
// Not a mock framework: a call log and an optional failure cover every row of
// `dose_recorder_test.dart`'s matrix that mentions notification cancellation.

import 'package:med_remind_app/domain/port/dose_notifier.dart';

/// A [DoseNotifier] that records every [cancelPending] call, and can be told
/// to fail.
final class FakeDoseNotifier implements DoseNotifier {
  FakeDoseNotifier({this.failure});

  /// Thrown by [cancelPending] when set, instead of succeeding.
  final Object? failure;

  /// Every doseId [cancelPending] was called with, in call order.
  ///
  /// Recorded even when [failure] is set: the call really happened, and a
  /// test proving "the notifier failure still fails the action" needs to see
  /// that cancellation was attempted exactly once, not that it never ran.
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancelPending(String doseId) async {
    cancelled.add(doseId);
    final Object? toThrow = failure;
    if (toThrow != null) throw toThrow;
  }
}
