// `notification_budget_policy.dart` -- pure Dart, no device, no clock port
// (AD-19): every `now` here is an injected `DateTime` literal.
//
// Testing depth is LIGHTER (project-context.md), with one named exception
// this spec's own Design Notes calls out: `tiersForRank`'s boundary ranks
// (9/10, 43/44) get their own explicit tests, since an off-by-one here
// silently reassigns which real Doses get a follow-up chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_budget_policy.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final DateTime now = DateTime.utc(2026, 9, 17, 10, 30);

  Dose doseAt(
    DateTime scheduledLocal, {
    DateTime? takenAt,
    DateTime? skippedAt,
    DateTime? snoozedUntil,
  }) => Dose(
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    scheduledLocal: scheduledLocal,
    ianaTimezone: 'Etc/UTC',
    takenAt: takenAt,
    skippedAt: skippedAt,
    snoozedUntil: snoozedUntil,
    escalationWindowMinutes: 60,
    medicineName: 'Metformin',
    dosageAmount: 1,
    dosageUnit: 'tablet',
    form: 'tablet',
  );

  group('constants (AD-8\'s arithmetic, settled once)', () {
    test('budgetedDoseCount evaluates to 44', () {
      expect(budgetedDoseCount, 44);
    });

    test('the named numbers this arithmetic is built from', () {
      expect(fullChainDoseCount, 10);
      expect(notificationBudget, 64);
      expect(notificationChainLength, 3);
    });
  });

  group('needsChainConsidered', () {
    test('a plain future Scheduled Dose -- the one inclusion', () {
      final Dose dose = doseAt(now.add(const Duration(hours: 1)));

      expect(needsChainConsidered(dose, now), isTrue);
    });

    test('Taken is excluded, even when still in the future', () {
      final Dose dose = doseAt(now.add(const Duration(hours: 1)), takenAt: now);

      expect(needsChainConsidered(dose, now), isFalse);
    });

    test('Skipped is excluded, even when still in the future', () {
      final Dose dose = doseAt(
        now.add(const Duration(hours: 1)),
        skippedAt: now,
      );

      expect(needsChainConsidered(dose, now), isFalse);
    });

    test('a live (not yet expired) Snooze is excluded', () {
      final Dose dose = doseAt(
        now.subtract(const Duration(minutes: 5)),
        snoozedUntil: now.add(const Duration(minutes: 10)),
      );

      expect(needsChainConsidered(dose, now), isFalse);
    });

    test('an EXPIRED snooze is NOT excluded on that basis alone -- matches '
        'dose_resolver.dart\'s own Snoozed-liveness check, unlike '
        'dose_generator.dart\'s _isActedOnOrSnoozed', () {
      // Still in the future, so the scheduledAt clause does not exclude it
      // either -- isolates the snooze-liveness clause specifically.
      final Dose dose = doseAt(
        now.add(const Duration(hours: 1)),
        snoozedUntil: now.subtract(const Duration(minutes: 1)),
      );

      expect(needsChainConsidered(dose, now), isTrue);
    });

    test('already at or past its own scheduledAt is excluded -- Due, '
        'Overdue and Missed are not candidates for a chain still to be '
        'scheduled', () {
      final Dose atNow = doseAt(now);
      final Dose past = doseAt(now.subtract(const Duration(days: 1)));

      expect(needsChainConsidered(atNow, now), isFalse);
      expect(needsChainConsidered(past, now), isFalse);
    });
  });

  group('tiersForRank', () {
    test('rank 0 -- inside the full-chain band', () {
      expect(tiersForRank(0), <NotificationTier>[
        NotificationTier.primary,
        NotificationTier.followUp,
        NotificationTier.finalFollowUp,
      ]);
    });

    test('rank 9 -- the full chain\'s last rank', () {
      expect(tiersForRank(9), <NotificationTier>[
        NotificationTier.primary,
        NotificationTier.followUp,
        NotificationTier.finalFollowUp,
      ]);
    });

    test('rank 10 -- the first primary-only rank', () {
      expect(tiersForRank(10), <NotificationTier>[NotificationTier.primary]);
    });

    test('rank 43 -- the primary-only band\'s last rank', () {
      expect(tiersForRank(43), <NotificationTier>[NotificationTier.primary]);
    });

    test('rank 44 -- the first beyond-budget rank, nothing scheduled', () {
      expect(tiersForRank(44), <NotificationTier>[]);
    });

    test('a negative rank throws ArgumentError', () {
      expect(() => tiersForRank(-1), throwsArgumentError);
    });
  });

  group('planBudget', () {
    test('the first 10 candidates get the full chain, the next 34 get '
        'primary only, and the rest get nothing', () {
      final List<Dose> candidates = <Dose>[
        for (int i = 0; i < 46; i++) doseAt(now.add(Duration(hours: i + 1))),
      ];

      final List<ScheduledTiers> planned = planBudget(candidates);

      expect(planned, hasLength(46));
      for (int i = 0; i < 10; i++) {
        expect(planned[i].tiers, <NotificationTier>[
          NotificationTier.primary,
          NotificationTier.followUp,
          NotificationTier.finalFollowUp,
        ], reason: 'rank $i is inside the full-chain band');
      }
      for (int i = 10; i < 44; i++) {
        expect(planned[i].tiers, <NotificationTier>[
          NotificationTier.primary,
        ], reason: 'rank $i is inside the primary-only band');
      }
      for (int i = 44; i < 46; i++) {
        expect(
          planned[i].tiers,
          isEmpty,
          reason: 'rank $i is beyond the budget -- nothing scheduled',
        );
      }
      expect(
        planned.map((ScheduledTiers s) => s.dose),
        candidates,
        reason: 'planBudget does not reorder its input',
      );
    });

    test('fewer candidates than the full-chain band -- every one gets the '
        'full chain', () {
      final List<Dose> candidates = <Dose>[
        for (int i = 0; i < 3; i++) doseAt(now.add(Duration(hours: i + 1))),
      ];

      final List<ScheduledTiers> planned = planBudget(candidates);

      expect(planned, hasLength(3));
      for (final ScheduledTiers s in planned) {
        expect(s.tiers, <NotificationTier>[
          NotificationTier.primary,
          NotificationTier.followUp,
          NotificationTier.finalFollowUp,
        ]);
      }
    });

    test('no candidates -- an empty plan', () {
      expect(planBudget(<Dose>[]), isEmpty);
    });
  });
}
