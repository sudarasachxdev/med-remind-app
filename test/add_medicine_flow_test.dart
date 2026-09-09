// The add-medicine flow: stepping, saving, and every way a save can fail.
//
// Driven through the controller against a REAL `DriftMedicineRepository` over an
// in-memory database, not a fake. Save is the story's one irreversible action
// and the assertions that matter are about what ends up stored -- one Medicine,
// one Schedule, a `glyphIndex` the port chose, no instructions and no end date.
// A fake repository would let all of that pass by agreeing with itself.
//
// `glyphIndex` is the sharpest case. AD-22 assigns `count mod 4` inside the
// insert's own transaction, and the flow must not compute, pass or second-guess
// it. Only a real repository can show that it did not.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/clock_provider.dart';
import 'package:med_remind_app/app/medicine_repository_provider.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_medicine_repository.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/port/clock.dart';
import 'package:med_remind_app/domain/port/medicine_repository.dart';
import 'package:med_remind_app/features/add_medicine/application/add_medicine_controller.dart';
import 'package:med_remind_app/features/add_medicine/domain/add_medicine_draft.dart';
import 'package:med_remind_app/features/add_medicine/presentation/add_medicine_copy.dart';

import 'support/fixed_clock.dart';

void main() {
  late AppDatabase database;
  late MedicineRepository repository;
  late ProviderContainer container;

  /// Builds a container over [clock], defaulting to the frozen one.
  ProviderContainer build({Clock? clock, MedicineRepository? repository}) {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        medicineRepositoryProvider.overrideWithValue(
          repository ?? DriftMedicineRepository(database),
        ),
        clockProvider.overrideWithValue(clock ?? FixedClock()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  AddMedicineController controller() =>
      container.read(addMedicineControllerProvider.notifier);
  AddMedicineFlow flow() => container.read(addMedicineControllerProvider);

  /// Fills step 1 and step 2 with a valid regimen.
  void fillValid() {
    controller()
      ..setName('Atorvastatin')
      ..chooseForm('tablet')
      ..chooseUnit('tablet');
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftMedicineRepository(database);
    container = build();
  });

  tearDown(() async {
    await database.close();
  });

  group('stepping', () {
    test('opens on step 1 with nothing entered', () {
      expect(flow().step, AddMedicineStep.what);
      expect(flow().draft, const AddMedicineDraft());
      expect(flow().canAdvance, isFalse);
      expect(flow().failureMessage, isNull);
    });

    test('advance is inert while the step is incomplete', () {
      controller().advance();

      expect(
        flow().step,
        AddMedicineStep.what,
        reason:
            'Gated on the draft, not on the button being disabled: a keyboard '
            'Enter and a re-entrant tap both arrive here with no widget in '
            'front of them.',
      );
    });

    test('advances through all three steps once each is complete', () {
      fillValid();
      controller().advance();
      expect(flow().step, AddMedicineStep.when);

      controller().advance();
      expect(flow().step, AddMedicineStep.review);

      controller().advance();
      expect(
        flow().step,
        AddMedicineStep.review,
        reason: 'there is no step 4; the primary action saves instead',
      );
    });

    test('Back preserves every entry', () {
      // The matrix's "Back from step 2 or 3" row. It needs no code -- the draft
      // is one value the steps read -- and that is exactly why it is asserted.
      fillValid();
      controller()
        ..increaseAmount()
        ..setCondition('Cholesterol')
        ..advance()
        ..laterTime()
        ..chooseRepeat(AddMedicineRepeat.weekdays)
        ..advance();

      final AddMedicineDraft atReview = flow().draft;

      expect(controller().retreat(), isTrue);
      expect(flow().step, AddMedicineStep.when);
      expect(controller().retreat(), isTrue);
      expect(flow().step, AddMedicineStep.what);
      expect(flow().draft, equals(atReview));
    });

    test('Back on step 1 reports that there is nowhere to go', () {
      // The controller has no BuildContext; navigation is the caller's.
      expect(
        controller().retreat(),
        isFalse,
        reason: 'the screen leaves for Home on false',
      );
      expect(flow().step, AddMedicineStep.what);
    });

    test('Cancel writes nothing, because the draft was never stored', () async {
      fillValid();
      container.dispose();

      expect(await repository.allMedicines(), isEmpty);
    });

    test('a new flow starts clean, since the provider auto-disposes', () {
      fillValid();
      expect(flow().draft.name, 'Atorvastatin');

      container.dispose();
      container = build();

      expect(
        flow().draft,
        const AddMedicineDraft(),
        reason:
            'The draft lifetime IS the screen lifetime, which is what makes '
            'Cancel discard it without anything having to clear it.',
      );
    });
  });

  group('saving', () {
    test('writes one Medicine and one Schedule', () async {
      fillValid();
      controller()
        ..increaseAmount()
        ..setCondition(' High cholesterol ')
        ..advance()
        ..advance();

      expect(await controller().save(), isTrue);

      final List<Medicine> medicines = await repository.allMedicines();
      expect(medicines, hasLength(1));

      final Medicine saved = medicines.single;
      expect(saved.name, 'Atorvastatin');
      expect(saved.condition, 'High cholesterol', reason: 'trimmed');
      expect(saved.form, 'tablet');
      expect(saved.dosageAmount, 2.0);
      expect(saved.dosageUnit, 'tablet');
      expect(saved.active, isTrue);

      final List<Schedule> schedules = await repository.schedulesFor(saved.id);
      expect(schedules, hasLength(1));
      expect(schedules.single.timeOfDay, '20:00');
      expect(schedules.single.frequency, Frequency.everyDay);
      expect(schedules.single.dosageAmount, 2.0);
    });

    test('the start date is the injected clock, not the wall clock', () async {
      // AD-5. A test that read the real clock would pass every day and fail
      // once, at a midnight boundary, in CI.
      fillValid();
      controller()
        ..advance()
        ..advance();

      expect(await controller().save(), isTrue);

      final Medicine saved = (await repository.allMedicines()).single;
      expect(saved.startDate, DateTime(2026, 9, 9));
    });

    test('the zone stored is the clock\'s, and it is a real one', () async {
      // AD-6: this string is the truth Stories 1.6/1.7 resolve Doses against.
      fillValid();
      controller()
        ..advance()
        ..advance();
      await controller().save();

      final Medicine saved = (await repository.allMedicines()).single;
      final Schedule schedule = (await repository.schedulesFor(
        saved.id,
      )).single;

      expect(schedule.ianaTimezone, 'Asia/Colombo');
      expect(
        schedule.ianaTimezone,
        isNot('Etc/UTC'),
        reason:
            'A placeholder zone is wrong rather than unknown, and would be '
            'read back as true. See AD-9\'s amendment.',
      );
    });

    test('never writes instructions or an end date', () async {
      // FR-1/FR-2 set both later, from Medicine detail. This flow never asks,
      // so it must not write a value for either.
      fillValid();
      controller()
        ..advance()
        ..advance();
      await controller().save();

      final Medicine saved = (await repository.allMedicines()).single;
      expect(saved.instructions, isNull);
      expect(saved.endDate, isNull);
    });

    test('the glyph comes from the port, in AD-22\'s sequence', () async {
      // Not computed, not passed, not second-guessed. Five medicines through
      // the real flow must read 0,1,2,3,0.
      final List<int> glyphs = <int>[];
      for (int i = 0; i < 5; i++) {
        container.dispose();
        container = build();
        controller()
          ..setName('Medicine $i')
          ..chooseForm('tablet')
          ..chooseUnit('tablet')
          ..advance()
          // A different hour each time, or the second save would be a duplicate
          // schedule on a different medicine -- which it would not be, but
          // keeping them distinct keeps this test about glyphs.
          ..laterTime()
          ..advance();
        expect(await controller().save(), isTrue);
        glyphs.add((await repository.allMedicines()).last.glyphIndex);
      }

      expect(glyphs, <int>[0, 1, 2, 3, 0]);
    });

    test('a specific-days regimen stores its days and no interval', () async {
      fillValid();
      controller()
        ..advance()
        ..chooseRepeat(AddMedicineRepeat.specificDays)
        ..toggleDay(DateTime.monday)
        ..toggleDay(DateTime.thursday)
        ..advance();

      expect(await controller().save(), isTrue);

      final Medicine saved = (await repository.allMedicines()).single;
      final Schedule schedule = (await repository.schedulesFor(
        saved.id,
      )).single;

      expect(schedule.frequency, Frequency.specificDays);
      expect(schedule.daysOfWeek, <int>{DateTime.monday, DateTime.thursday});
      expect(schedule.intervalDays, isNull);
    });

    test('an every-N-days regimen stores its interval and no days', () async {
      fillValid();
      controller()
        ..advance()
        ..chooseRepeat(AddMedicineRepeat.everyNDays)
        ..increaseInterval()
        ..advance();

      expect(await controller().save(), isTrue);

      final Medicine saved = (await repository.allMedicines()).single;
      final Schedule schedule = (await repository.schedulesFor(
        saved.id,
      )).single;

      expect(schedule.intervalDays, 3);
      expect(schedule.daysOfWeek, anyOf(isNull, isEmpty));
    });

    test(
      'a free-text unit is stored as typed, never as the sentinel',
      () async {
        controller()
          ..setName('Ventolin')
          ..chooseForm('liquid')
          ..chooseUnit('other')
          ..setCustomUnit('puff')
          ..advance()
          ..advance();

        expect(await controller().save(), isTrue);

        expect((await repository.allMedicines()).single.dosageUnit, 'puff');
      },
    );

    test('save is refused on an incomplete draft', () async {
      controller().setName('Atorvastatin');

      expect(await controller().save(), isFalse);
      expect(await repository.allMedicines(), isEmpty);
    });
  });

  group('when a save fails', () {
    test('a rejected schedule is explained and leaves no orphan', () async {
      // The matrix's duplicate-schedule row, provoked through a repository that
      // rejects the Schedule write.
      //
      // It has to be provoked, because `DuplicateScheduleFailure` is
      // UNREACHABLE through this flow: the port scopes the rule to "the
      // Medicine already has a Schedule at the same time", and every save here
      // creates a NEW Medicine, which by definition has none. It becomes
      // reachable when Medicine detail adds a second Schedule to an existing
      // Medicine, in a later story. An earlier version of this test asserted a
      // control case -- a different medicine at the same time, which succeeds --
      // and so proved nothing at all.
      //
      // What IS this story's behaviour, and what this asserts: when the port
      // says no, the message reaches the user and the Medicine written moments
      // earlier is rolled back. FR-1 says the flow must never leave an
      // unscheduled Medicine, and the port has no cross-aggregate transaction
      // to enforce it.
      container.dispose();
      container = build(repository: _RejectingSchedules(repository));
      controller()
        ..setName('Atorvastatin')
        ..chooseForm('tablet')
        ..chooseUnit('tablet')
        ..advance()
        ..advance();

      expect(await controller().save(), isFalse);
      expect(
        flow().failureMessage,
        _RejectingSchedules.failure.message,
        reason: 'the port\'s own sentence, not one composed here',
      );
      expect(
        flow().step,
        AddMedicineStep.review,
        reason: 'the user stays on step 3 with their entries intact',
      );
      expect(
        await repository.allMedicines(),
        isEmpty,
        reason:
            'The Medicine was written before the Schedule was rejected. '
            'Without the rollback it survives as an orphan with no reminders, '
            'which FR-1 forbids.',
      );
      expect(flow().draft.name, 'Atorvastatin');
      expect(flow().saving, isFalse);
    });

    test('a rollback that itself fails does not hide the original', () async {
      // The worst case: the Schedule is rejected AND the compensating delete
      // throws. The user must still be told why their medicine was not saved,
      // rather than meeting a second, unrelated error -- or none.
      container.dispose();
      container = build(
        repository: _RejectingSchedules(repository, failRollback: true),
      );
      controller()
        ..setName('Atorvastatin')
        ..chooseForm('tablet')
        ..chooseUnit('tablet')
        ..advance()
        ..advance();

      expect(await controller().save(), isFalse);
      expect(flow().failureMessage, _RejectingSchedules.failure.message);
    });

    test('an unreadable device zone is explained and writes nothing', () async {
      // AD-9's amendment made this reachable: `UnresolvedZoneClock` throws
      // rather than answering, so the one operation that would persist a wrong
      // zone fails instead.
      container.dispose();
      container = build(clock: const _ZonelessClock());
      controller()
        ..setName('Atorvastatin')
        ..chooseForm('tablet')
        ..chooseUnit('tablet')
        ..advance()
        ..advance();

      expect(await controller().save(), isFalse);
      expect(
        flow().failureMessage,
        AddMedicineCopy.timezoneUnavailable,
        reason: 'the user is told, in the product\'s voice',
      );
      expect(
        await repository.allMedicines(),
        isEmpty,
        reason:
            'The message says "Nothing has been saved", and that has to be '
            'true -- the zone is read BEFORE the medicine is written.',
      );
      expect(flow().saving, isFalse, reason: 'the button is usable again');
    });

    test('editing anything clears a stale failure message', () async {
      container.dispose();
      container = build(clock: const _ZonelessClock());
      controller()
        ..setName('Atorvastatin')
        ..chooseForm('tablet')
        ..chooseUnit('tablet')
        ..advance()
        ..advance();
      await controller().save();
      expect(flow().failureMessage, isNotNull);

      controller().setReminders(enabled: false);

      expect(
        flow().failureMessage,
        isNull,
        reason:
            'A message about a save that is now out of date would have the '
            'user re-reading an explanation of a state they have left.',
      );
    });

    test('a second tap while saving is refused', () async {
      fillValid();
      controller()
        ..advance()
        ..advance();

      final Future<bool> first = controller().save();
      final bool second = await controller().save();

      expect(
        second,
        isFalse,
        reason:
            'Two taps inside one frame both run the handler, because the '
            'widget has not rebuilt in between.',
      );
      expect(await first, isTrue);
      expect(await repository.allMedicines(), hasLength(1));
    });
  });
}

/// A repository that writes Medicines but always rejects Schedules.
///
/// Delegates everything else to the real one, so the Medicine really is written
/// and the rollback really has something to undo. A wholly fake repository would
/// let "nothing was left behind" pass by never having written anything.
final class _RejectingSchedules implements MedicineRepository {
  _RejectingSchedules(this._inner, {this.failRollback = false});

  /// The failure every `addSchedule` throws.
  static const DuplicateScheduleFailure failure = DuplicateScheduleFailure(
    existingScheduleId: 'schedule-1',
    timeOfDay: '20:00',
    overlappingDays: <int>{DateTime.monday},
  );

  final MedicineRepository _inner;

  /// Whether the compensating delete throws too.
  final bool failRollback;

  @override
  Future<Schedule> addSchedule({
    required String medicineId,
    required String timeOfDay,
    required String ianaTimezone,
    required Frequency frequency,
    Set<int>? daysOfWeek,
    int? intervalDays,
    required double dosageAmount,
    String? reminderOverride,
  }) => Future<Schedule>.error(failure, StackTrace.current);

  @override
  Future<void> deleteMedicine(String id) {
    if (failRollback) {
      return Future<void>.error(StateError('rollback failed'));
    }
    return _inner.deleteMedicine(id);
  }

  @override
  Future<Medicine> addMedicine({
    required String name,
    String? condition,
    required String form,
    required double dosageAmount,
    required String dosageUnit,
    String? instructions,
    required DateTime startDate,
    DateTime? endDate,
    bool active = true,
  }) => _inner.addMedicine(
    name: name,
    condition: condition,
    form: form,
    dosageAmount: dosageAmount,
    dosageUnit: dosageUnit,
    instructions: instructions,
    startDate: startDate,
    endDate: endDate,
    active: active,
  );

  @override
  Future<List<Medicine>> allMedicines() => _inner.allMedicines();

  @override
  Future<Medicine?> findMedicine(String id) => _inner.findMedicine(id);

  @override
  Future<void> saveMedicine(Medicine medicine) => _inner.saveMedicine(medicine);

  @override
  Future<List<Schedule>> schedulesFor(String medicineId) =>
      _inner.schedulesFor(medicineId);

  @override
  Future<void> saveSchedule(Schedule schedule) => _inner.saveSchedule(schedule);

  @override
  Future<void> deleteSchedule(String id) => _inner.deleteSchedule(id);
}

/// A clock that knows the time but throws on the zone.
///
/// The shape `UnresolvedZoneClock` has, declared here so this test does not
/// depend on the platform adapter to describe a controller behaviour.
final class _ZonelessClock implements Clock {
  const _ZonelessClock();

  @override
  DateTime now() => DateTime(2026, 9, 9, 10, 30);

  @override
  String get ianaTimezone =>
      throw StateError('the device has not named its zone');
}
