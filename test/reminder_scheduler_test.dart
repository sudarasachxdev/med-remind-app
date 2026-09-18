// `ReminderScheduler.schedulePrimary`/`scheduleFollowUp`/
// `scheduleFinalFollowUp` -- FR-6/FR-11's content and gate, plus FR-11/AD-19's
// follow-up chain: the right tier/content when enabled and within the
// Escalation Window, no-op when disabled, no-op at or past the window, and
// the frozen-cadence guarantee (a Dose's own offset governs, never the
// current default constant).
//
// Testing depth is LIGHTER (project-context.md): the rows the spec's own
// task list names, not an exhaustive matrix. AD-19 names its own exception
// directly -- the frozen-cadence test and the escalation-window boundary test
// are both required, not optional depth.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/dose_resolution_policy.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/service/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_dose_notifier.dart';
import 'support/voice_rules.dart';

void main() {
  // `Dose`'s constructor resolves its zone through `package:timezone`, which
  // throws until the database is loaded -- the same house rule every other
  // Dose-constructing test file follows.
  setUpAll(tzdata.initializeTimeZones);

  Dose buildDose({
    double dosageAmount = 2,
    String dosageUnit = 'tablet',
    DateTime? scheduledLocal,
    int escalationWindowMinutes = 60,
    List<int>? followUpOffsetsMinutes,
  }) => Dose(
    scheduleId: 'schedule-1',
    medicineId: 'medicine-1',
    scheduledLocal: scheduledLocal ?? DateTime(2026, 9, 17, 8, 0),
    ianaTimezone: 'Asia/Colombo',
    escalationWindowMinutes: escalationWindowMinutes,
    followUpOffsetsMinutes:
        followUpOffsetsMinutes ?? defaultFollowUpOffsetsMinutes,
    medicineName: 'Metformin',
    dosageAmount: dosageAmount,
    dosageUnit: dosageUnit,
    form: 'tablet',
  );

  test('reminders enabled: schedules the primary tier with the Medicine name '
      'and dosage amount (FR-6)', () async {
    final FakeDoseNotifier notifier = FakeDoseNotifier();
    final ReminderScheduler scheduler = ReminderScheduler(notifier);
    final Dose dose = buildDose();

    await scheduler.schedulePrimary(dose, remindersEnabled: true);

    expect(notifier.scheduled, hasLength(1));
    final (String doseId, NotificationTier tier, String title, String body) =
        notifier.scheduled.single;
    expect(doseId, dose.id);
    expect(tier, NotificationTier.primary);
    expect(title, 'Metformin');
    expect(body, contains('2'));
    expect(body, contains('tablet'));
  });

  test('reminders disabled: schedules nothing at all (FR-11), and the Dose is '
      'left to resolve exactly as it otherwise would', () async {
    final FakeDoseNotifier notifier = FakeDoseNotifier();
    final ReminderScheduler scheduler = ReminderScheduler(notifier);

    await scheduler.schedulePrimary(buildDose(), remindersEnabled: false);

    expect(notifier.scheduled, isEmpty);
  });

  test('a whole-number amount is shown without a trailing .0', () async {
    final FakeDoseNotifier notifier = FakeDoseNotifier();
    final ReminderScheduler scheduler = ReminderScheduler(notifier);

    await scheduler.schedulePrimary(
      buildDose(dosageAmount: 1, dosageUnit: 'capsule'),
      remindersEnabled: true,
    );

    final (_, _, _, String body) = notifier.scheduled.single;
    expect(body, '1 capsule');
  });

  group('scheduleFollowUp', () {
    test('reminders enabled, within window: schedules the followUp tier with '
        "EXPERIENCE.md's own UJ-3 wording (FR-11)", () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);
      final Dose dose = buildDose();

      await scheduler.scheduleFollowUp(dose, remindersEnabled: true);

      expect(notifier.scheduled, hasLength(1));
      final (String doseId, NotificationTier tier, String title, String body) =
          notifier.scheduled.single;
      expect(doseId, dose.id);
      expect(tier, NotificationTier.followUp);
      expect(title, 'Metformin');
      expect(body, 'Your 08:00 AM dose is still waiting.');
    });

    test('reminders disabled: schedules nothing at all (FR-11)', () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);

      await scheduler.scheduleFollowUp(buildDose(), remindersEnabled: false);

      expect(notifier.scheduled, isEmpty);
    });

    test("at or past the Dose's own Escalation Window: schedules nothing, even "
        'though nothing reachable through today\'s UI can trip this -- a '
        'structural guarantee for FR-11\'s "Follow-Up Reminders stop when the '
        'Escalation Window closes", not merely an accident of today\'s '
        '60-minute floor', () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);
      // followUpOffsetsMinutes[0] (15, the default) sits at the window's
      // own boundary: `>=` must exclude it, not merely values past it.
      final Dose dose = buildDose(escalationWindowMinutes: 15);

      await scheduler.scheduleFollowUp(dose, remindersEnabled: true);

      expect(notifier.scheduled, isEmpty);
    });

    test("a Dose whose followUpOffsetsMinutes differs from the current default "
        "constant still schedules at ITS OWN frozen offset (AD-19), proving "
        "the frozen-cadence guarantee directly: a window narrow enough that "
        "the CURRENT default offset (15) would fail the guard does not fail "
        "it for this Dose's own, different, frozen offset", () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);
      expect(
        defaultFollowUpOffsetsMinutes[0],
        greaterThanOrEqualTo(10),
        reason:
            'this test only proves anything if the current default '
            'offset would fail a 10-minute window',
      );
      final Dose dose = buildDose(
        escalationWindowMinutes: 10,
        followUpOffsetsMinutes: const <int>[5, 8, 60],
      );

      await scheduler.scheduleFollowUp(dose, remindersEnabled: true);

      expect(
        notifier.scheduled,
        hasLength(1),
        reason:
            "the Dose's own frozen offset (5) governs, not the current "
            'default constant (15) -- settings changing after generation '
            'must never re-read a different offset for an existing Dose',
      );
    });

    test("the body passes EXPERIENCE.md's Voice and Tone rules", () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);

      await scheduler.scheduleFollowUp(buildDose(), remindersEnabled: true);

      final (_, _, _, String body) = notifier.scheduled.single;
      expect(body, isNot(contains('!')));
      for (final String banned in <String>[
        ...encouragementWords,
        ...clinicalWords,
        ...judgementalWords,
      ]) {
        expect(body.toLowerCase(), isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('scheduleFinalFollowUp', () {
    test('reminders enabled, within window: schedules the finalFollowUp tier, '
        'one notch more specific than the follow-up but never naming a fixed '
        'number of minutes (AD-16)', () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);
      final Dose dose = buildDose();

      await scheduler.scheduleFinalFollowUp(dose, remindersEnabled: true);

      expect(notifier.scheduled, hasLength(1));
      final (String doseId, NotificationTier tier, String title, String body) =
          notifier.scheduled.single;
      expect(doseId, dose.id);
      expect(tier, NotificationTier.finalFollowUp);
      expect(title, 'Metformin');
      expect(
        body,
        'Your 08:00 AM dose is still unresolved. Reminders will stop soon.',
      );
    });

    test('reminders disabled: schedules nothing at all (FR-11)', () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);

      await scheduler.scheduleFinalFollowUp(
        buildDose(),
        remindersEnabled: false,
      );

      expect(notifier.scheduled, isEmpty);
    });

    test("at or past the Dose's own Escalation Window: schedules nothing "
        '(same structural guarantee as scheduleFollowUp, guarding index [1] '
        'instead of [0])', () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);
      // followUpOffsetsMinutes[1] (30, the default) sits at the window's
      // own boundary.
      final Dose dose = buildDose(escalationWindowMinutes: 30);

      await scheduler.scheduleFinalFollowUp(dose, remindersEnabled: true);

      expect(notifier.scheduled, isEmpty);
    });

    test(
      "a Dose whose followUpOffsetsMinutes differs from the current default "
      'constant still schedules at ITS OWN frozen offset (AD-19): a window '
      "narrow enough that the CURRENT default offset (30) would fail the "
      "guard does not fail it for this Dose's own, different, frozen offset",
      () async {
        final FakeDoseNotifier notifier = FakeDoseNotifier();
        final ReminderScheduler scheduler = ReminderScheduler(notifier);
        expect(
          defaultFollowUpOffsetsMinutes[1],
          greaterThanOrEqualTo(10),
          reason:
              'this test only proves anything if the current default '
              'offset would fail a 10-minute window',
        );
        final Dose dose = buildDose(
          escalationWindowMinutes: 10,
          followUpOffsetsMinutes: const <int>[5, 8, 60],
        );

        await scheduler.scheduleFinalFollowUp(dose, remindersEnabled: true);

        expect(
          notifier.scheduled,
          hasLength(1),
          reason:
              "the Dose's own frozen offset (8) governs, not the current "
              'default constant (30)',
        );
      },
    );

    test("the body passes EXPERIENCE.md's Voice and Tone rules", () async {
      final FakeDoseNotifier notifier = FakeDoseNotifier();
      final ReminderScheduler scheduler = ReminderScheduler(notifier);

      await scheduler.scheduleFinalFollowUp(
        buildDose(),
        remindersEnabled: true,
      );

      final (_, _, _, String body) = notifier.scheduled.single;
      expect(body, isNot(contains('!')));
      for (final String banned in <String>[
        ...encouragementWords,
        ...clinicalWords,
        ...judgementalWords,
      ]) {
        expect(body.toLowerCase(), isNot(contains(banned)), reason: banned);
      }
    });
  });
}
