// `notificationId`/`stableHash32` -- pure Dart, no device, no clock (AD-19).
// One test per acceptance criterion this spec names for AD-7's own
// derivation: deterministic, distinguishes tier, distinguishes Dose, and
// stays inside the range a caller can actually hand the OS plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';

void main() {
  test('is deterministic: the same doseId and tier produce the same id, '
      'called twice', () {
    final int first = notificationId('dose-1', NotificationTier.primary);
    final int second = notificationId('dose-1', NotificationTier.primary);

    expect(first, equals(second));
  });

  test('differs across all four tiers, for one Dose', () {
    const String doseId = 'dose-1';
    final Set<int> ids = NotificationTier.values
        .map((NotificationTier tier) => notificationId(doseId, tier))
        .toSet();

    expect(
      ids,
      hasLength(NotificationTier.values.length),
      reason:
          'every tier must recompute to its own id, or cancelPending '
          'would cancel the wrong notification under one of them',
    );
  });

  test('differs across two Doses, for the same tier', () {
    final int first = notificationId('dose-1', NotificationTier.primary);
    final int second = notificationId('dose-2', NotificationTier.primary);

    expect(first, isNot(equals(second)));
  });

  test('stableHash32 stays within a 32-bit unsigned range for every id this '
      'story derives', () {
    for (final String doseId in <String>['dose-1', 'dose-2', '', 'a' * 200]) {
      for (final NotificationTier tier in NotificationTier.values) {
        final int id = notificationId(doseId, tier);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0xFFFFFFFF));
      }
    }
  });

  test('stableHash32 is itself deterministic and non-negative, directly', () {
    expect(stableHash32('same input'), equals(stableHash32('same input')));
    expect(stableHash32('same input'), isNot(equals(stableHash32('other'))));
    expect(stableHash32(''), greaterThanOrEqualTo(0));
  });
}
