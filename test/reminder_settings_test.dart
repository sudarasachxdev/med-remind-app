// `ReminderSettings` -- `validationError`'s three rows and the fresh-install
// default this spec's own acceptance criteria name.
//
// Testing depth is LIGHTER (project-context.md): the matrix rows this spec
// names, not an exhaustive property sweep.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/reminder_settings.dart';

void main() {
  group('freshInstallDefault', () {
    test('is reminders on, +15/+30, Automatic, 15-minute snooze', () {
      const ReminderSettings settings = ReminderSettings.freshInstallDefault;

      expect(settings.remindersEnabledDefault, isTrue);
      expect(settings.followUpOffsetsMinutes, <int>[15, 30]);
      expect(settings.escalationWindowOverrideMinutes, isNull);
      expect(settings.snoozeIntervalMinutes, 15);
      expect(
        settings.validationError,
        isNull,
        reason: 'the shipped default must itself be a valid combination',
      );
    });
  });

  group('validationError', () {
    test('a valid, strictly-ordered combination reports no error', () {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[10, 20],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 10,
      );

      expect(settings.validationError, isNull);
    });

    test('a valid combination with Automatic (no fixed window) reports no '
        'error, regardless of how large the follow-ups are', () {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[100, 200],
        escalationWindowOverrideMinutes: null,
        snoozeIntervalMinutes: 15,
      );

      expect(settings.validationError, isNull);
    });

    test(
      'follow-ups out of order (first at or after the final) is invalid',
      () {
        const ReminderSettings equal = ReminderSettings(
          remindersEnabledDefault: true,
          followUpOffsetsMinutes: <int>[30, 30],
          escalationWindowOverrideMinutes: null,
          snoozeIntervalMinutes: 15,
        );
        const ReminderSettings reversed = ReminderSettings(
          remindersEnabledDefault: true,
          followUpOffsetsMinutes: <int>[30, 15],
          escalationWindowOverrideMinutes: null,
          snoozeIntervalMinutes: 15,
        );

        expect(equal.validationError, isNotNull);
        expect(reversed.validationError, isNotNull);
      },
    );

    test('the final follow-up at or past a fixed escalation window is '
        'invalid', () {
      const ReminderSettings atBoundary = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 60],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );
      const ReminderSettings pastBoundary = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 90],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );

      expect(atBoundary.validationError, isNotNull);
      expect(pastBoundary.validationError, isNotNull);
    });

    test('the final follow-up strictly before a fixed window is valid', () {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 30],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );

      expect(settings.validationError, isNull);
    });
  });

  group('copyWith', () {
    test('replaces only the given fields', () {
      const ReminderSettings original = ReminderSettings.freshInstallDefault;

      final ReminderSettings updated = original.copyWith(
        snoozeIntervalMinutes: 20,
      );

      expect(updated.snoozeIntervalMinutes, 20);
      expect(updated.remindersEnabledDefault, original.remindersEnabledDefault);
      expect(updated.followUpOffsetsMinutes, original.followUpOffsetsMinutes);
      expect(
        updated.escalationWindowOverrideMinutes,
        original.escalationWindowOverrideMinutes,
      );
    });
  });

  group('equality', () {
    test('two settings with the same fields are equal', () {
      const ReminderSettings a = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 30],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );
      const ReminderSettings b = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 30],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
