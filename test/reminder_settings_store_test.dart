// `DriftReminderSettingsStore` -- the Drift adapter behind `ReminderSettingsStore`,
// against a real SQLite (AD-19: a repository test that stubs the database
// proves the Dart compiles and nothing about the SQL).
//
// Testing depth is LIGHTER (project-context.md): `load()`'s fresh-install
// default, `save()`'s targeted upsert (a round-trip, and a proof it never
// resets a sibling column), and `save()` refusing an invalid value -- the
// rows this spec's own task list names.

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/data/repository/drift_reminder_settings_store.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/reminder_settings.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/domain/port/reminder_settings_store.dart';

import 'support/recording_interceptor.dart';

void main() {
  late AppDatabase database;
  late ReminderSettingsStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftReminderSettingsStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('load', () {
    test('a fresh install with no settings row reads the fresh-install '
        'default', () async {
      expect(await store.load(), ReminderSettings.freshInstallDefault);
    });

    test('a stored value is read back exactly', () async {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: false,
        followUpOffsetsMinutes: <int>[10, 40],
        escalationWindowOverrideMinutes: 90,
        snoozeIntervalMinutes: 20,
      );

      await store.save(settings);

      expect(await store.load(), settings);
    });

    test('a null escalation window override (Automatic) reads back null, '
        'not some placeholder', () async {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[15, 30],
        escalationWindowOverrideMinutes: null,
        snoozeIntervalMinutes: 15,
      );

      await store.save(settings);

      expect((await store.load()).escalationWindowOverrideMinutes, isNull);
    });
  });

  group('save', () {
    test('round-trips through a reopened store', () async {
      const ReminderSettings settings = ReminderSettings(
        remindersEnabledDefault: false,
        followUpOffsetsMinutes: <int>[20, 50],
        escalationWindowOverrideMinutes: 120,
        snoozeIntervalMinutes: 30,
      );

      await store.save(settings);

      final ReminderSettingsStore reopened = DriftReminderSettingsStore(
        database,
      );
      expect(await reopened.load(), settings);
    });

    test('is written to the one settings row, not a new one', () async {
      await store.save(ReminderSettings.freshInstallDefault);
      await store.save(
        ReminderSettings.freshInstallDefault.copyWith(snoozeIntervalMinutes: 5),
      );

      final int rows =
          (await database
                  .customSelect('SELECT COUNT(*) AS n FROM app_settings')
                  .getSingle())
              .read<int>('n');

      expect(rows, 1);
    });

    test('the write touches only its own five columns -- a targeted upsert, '
        'not insertOnConflictUpdate\'s whole-row replace', () async {
      final interceptor = RecordingInterceptor();
      final scoped = AppDatabase(
        NativeDatabase.memory().interceptWith(interceptor),
      );
      addTearDown(scoped.close);
      final ReminderSettingsStore scopedStore = DriftReminderSettingsStore(
        scoped,
      );

      await scopedStore.save(ReminderSettings.freshInstallDefault);

      expect(interceptor.inserts, hasLength(1));
      final String statement = interceptor.inserts.single;
      expect(statement, contains('DO UPDATE SET'));
      final String updateClause = statement.substring(
        statement.indexOf('DO UPDATE SET'),
      );
      for (final String column in <String>[
        '"reminders_enabled_default"',
        '"follow_up_offset_minutes1"',
        '"follow_up_offset_minutes2"',
        '"escalation_window_override_minutes"',
        '"snooze_interval_minutes"',
      ]) {
        expect(updateClause, contains(column));
      }
      expect(
        updateClause,
        isNot(contains('"onboarding_completed"')),
        reason: 'this port owns none of onboardingCompleted',
      );
      expect(
        updateClause,
        isNot(contains('"last_known_iana_timezone"')),
        reason: 'nor lastKnownIanaTimezone -- ReconciliationStateStore\'s own',
      );
      expect(updateClause, isNot(contains('"id"')));
    });

    test('never resets onboardingCompleted or lastKnownIanaTimezone already '
        'stored on the same row', () async {
      await database.customStatement(
        "INSERT INTO app_settings (id, onboarding_completed, "
        "last_known_iana_timezone) VALUES (1, 1, 'Asia/Colombo')",
      );

      await store.save(
        ReminderSettings.freshInstallDefault.copyWith(
          snoozeIntervalMinutes: 25,
        ),
      );

      final row = await database
          .customSelect('SELECT * FROM app_settings')
          .getSingle();
      expect(row.data['onboarding_completed'], 1);
      expect(row.data['last_known_iana_timezone'], 'Asia/Colombo');
      expect(row.data['snooze_interval_minutes'], 25);
    });

    test('never touches Schedules.remindersEnabled on any Schedule', () async {
      final MedicineRepository medicines = DriftMedicineRepository(database);
      final Medicine medicine = await medicines.addMedicine(
        name: 'Metformin',
        form: 'tablet',
        dosageAmount: 1,
        dosageUnit: 'tablet',
        startDate: DateTime(2026, 9, 1),
      );
      final Schedule schedule = await medicines.addSchedule(
        medicineId: medicine.id,
        timeOfDay: '08:00',
        ianaTimezone: 'Asia/Colombo',
        frequency: Frequency.everyDay,
        dosageAmount: 1,
        remindersEnabled: false,
      );

      await store.save(
        ReminderSettings.freshInstallDefault.copyWith(
          remindersEnabledDefault: false,
        ),
      );

      final Schedule reread = (await medicines.schedulesFor(
        medicine.id,
      )).singleWhere((Schedule s) => s.id == schedule.id);
      expect(
        reread.remindersEnabled,
        isFalse,
        reason:
            'a per-Schedule value must survive an app-wide default write -- '
            'they are different columns on different tables entirely',
      );
    });

    test('refuses an invalid combination and writes nothing', () async {
      const ReminderSettings invalid = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[30, 15],
        escalationWindowOverrideMinutes: null,
        snoozeIntervalMinutes: 15,
      );

      await expectLater(
        store.save(invalid),
        throwsA(isA<ReminderSettingsNotValidFailure>()),
      );

      expect(
        await store.load(),
        ReminderSettings.freshInstallDefault,
        reason: 'the refused write must leave the prior value untouched',
      );
    });

    test('an invalid combination against an existing stored value leaves it '
        'exactly as it was', () async {
      const ReminderSettings stored = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[10, 20],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );
      await store.save(stored);

      const ReminderSettings invalid = ReminderSettings(
        remindersEnabledDefault: true,
        followUpOffsetsMinutes: <int>[10, 60],
        escalationWindowOverrideMinutes: 60,
        snoozeIntervalMinutes: 15,
      );

      await expectLater(
        store.save(invalid),
        throwsA(isA<ReminderSettingsNotValidFailure>()),
      );
      expect(await store.load(), stored);
    });
  });
}
