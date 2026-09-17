// `ReminderScheduler.schedulePrimary` -- FR-6's content and FR-11's gate.
//
// Testing depth is LIGHTER (project-context.md): the two rows the spec's own
// task list names -- reminders enabled schedules with the right tier/content,
// reminders disabled schedules nothing at all -- not an exhaustive matrix.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/dose.dart';
import 'package:med_remind_app/domain/policy/notification_id_policy.dart';
import 'package:med_remind_app/domain/service/reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'support/fake_dose_notifier.dart';

void main() {
  // `Dose`'s constructor resolves its zone through `package:timezone`, which
  // throws until the database is loaded -- the same house rule every other
  // Dose-constructing test file follows.
  setUpAll(tzdata.initializeTimeZones);

  Dose buildDose({double dosageAmount = 2, String dosageUnit = 'tablet'}) =>
      Dose(
        scheduleId: 'schedule-1',
        medicineId: 'medicine-1',
        scheduledLocal: DateTime(2026, 9, 17, 8, 0),
        ianaTimezone: 'Asia/Colombo',
        escalationWindowMinutes: 60,
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
}
