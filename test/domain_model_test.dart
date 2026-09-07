// The pure-Dart domain models: AD-6's wall-clock Schedule, the
// duplicate-schedule predicate, the frequency/companion pairing, and
// Medicine's calendar dates.
//
// No database and no Flutter binding. Everything here is a rule, and every
// rule the repository enforces is decided by one of these methods -- so a
// change to the predicate fails here first, with a message about the rule
// rather than about a SQL statement.

import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/domain/model/frequency.dart';
import 'package:med_remind_app/domain/model/medicine.dart';
import 'package:med_remind_app/domain/model/schedule.dart';
import 'package:med_remind_app/domain/policy/glyph_policy.dart';
import 'package:med_remind_app/domain/policy/medicine_vocabulary.dart';

void main() {
  group('Frequency', () {
    test('is FR-4\'s four patterns and no fifth', () {
      expect(
        Frequency.values.map((Frequency f) => f.name).toList(),
        equals(<String>['everyDay', 'weekdays', 'specificDays', 'everyNDays']),
        reason:
            'The names are persisted as text, so the list is a storage '
            'contract as well as a vocabulary one. Reordering is safe; '
            'renaming is a migration.',
      );
    });
  });

  group('Schedule stores a wall clock (AD-6)', () {
    test('keeps the time exactly as given', () {
      final Schedule schedule = _schedule(timeOfDay: '08:00');

      expect(schedule.timeOfDay, '08:00');
      expect(schedule.ianaTimezone, 'Asia/Colombo');
    });

    test('holds no member of any date-time type', () {
      // AD-6 as a claim about the type's SURFACE, checked structurally.
      //
      // This was previously a substring assertion over `toString()`, which is
      // hand-written: adding `DateTime get scheduledUtc => ...` to Schedule
      // left the whole suite green, because a new member cannot change a
      // string four fields write by hand. The real check reads the source and
      // is in `test/story_scope_test.dart` ("Schedule's surface holds no
      // instant"), where the analyzer is already a dependency.
      //
      // What stays here is the behavioural half: the two fields that carry the
      // time say what was stored, and nothing derived appears beside them.
      final Schedule schedule = _schedule();

      expect(schedule.timeOfDay, '08:00');
      expect(schedule.ianaTimezone, 'Asia/Colombo');
      expect(
        schedule.toString(),
        allOf(
          contains('08:00'),
          contains('Asia/Colombo'),
          isNot(contains('UTC')),
        ),
      );
    });

    test('rejects a zone that is not an IANA identifier', () {
      // AD-6 makes the zone half the stored truth, and an unresolvable one is
      // a reminder that cannot be scheduled at all -- discovered in Epic 3,
      // far from the write that caused it.
      for (final String bad in <String>[
        '',
        'Colombo', // a bare city
        '+05:30', // a fixed offset
        'IST', // an abbreviation, ambiguous between three zones
        'asia/', // no location
        '/Colombo', // no area
        'Asia//Colombo',
        'Asia Colombo',
        'Asia/Colombo/Extra/Deep',
      ]) {
        expect(
          () => _schedule(ianaTimezone: bad),
          throwsArgumentError,
          reason: '"$bad" cannot resolve to a zone anywhere',
        );
      }
    });

    test('accepts the zone shapes the IANA database actually uses', () {
      for (final String good in <String>[
        'Asia/Colombo',
        'Europe/London',
        'America/Argentina/Buenos_Aires',
        'America/Port-au-Prince',
        'Etc/GMT+5',
      ]) {
        expect(_schedule(ianaTimezone: good).ianaTimezone, good);
      }
    });

    test('rejects a time that is not HH:mm', () {
      for (final String bad in <String>[
        '8:00',
        '08:0',
        '0800',
        '24:00',
        '08:60',
        '08:00:00',
        'ab:cd',
        '',
      ]) {
        expect(
          () => _schedule(timeOfDay: bad),
          throwsArgumentError,
          reason:
              '"$bad" would be stored as written and never parse back into a '
              'reminder time',
        );
      }
    });

    test('accepts both ends of the day', () {
      expect(_schedule(timeOfDay: '00:00').timeOfDay, '00:00');
      expect(_schedule(timeOfDay: '23:59').timeOfDay, '23:59');
    });

    test('rejects a day of the week outside 1..7', () {
      for (final int bad in <int>[0, 8, -1]) {
        expect(
          () => _schedule(
            frequency: Frequency.specificDays,
            daysOfWeek: <int>{bad},
          ),
          throwsArgumentError,
        );
      }
    });

    test('the stored day set cannot be mutated afterwards', () {
      final Set<int> mine = <int>{DateTime.monday};
      final Schedule schedule = _schedule(
        frequency: Frequency.specificDays,
        daysOfWeek: mine,
      );

      // Adding to the caller's set must not reach into the Schedule, and the
      // Schedule's own set must refuse the write.
      mine.add(DateTime.friday);
      expect(schedule.daysOfWeek, equals(<int>{DateTime.monday}));
      expect(
        () => schedule.daysOfWeek!.add(DateTime.friday),
        throwsUnsupportedError,
      );
    });
  });

  group('occupiedDaysOfWeek', () {
    test('every day is all seven', () {
      expect(
        _schedule().occupiedDaysOfWeek,
        equals(<int>{1, 2, 3, 4, 5, 6, 7}),
      );
    });

    test('weekdays is Monday to Friday, and never moves with the locale', () {
      expect(
        _schedule(frequency: Frequency.weekdays).occupiedDaysOfWeek,
        equals(<int>{1, 2, 3, 4, 5}),
      );
    });

    test('specific days is exactly what was chosen', () {
      expect(
        _schedule(
          frequency: Frequency.specificDays,
          daysOfWeek: <int>{DateTime.tuesday, DateTime.saturday},
        ).occupiedDaysOfWeek,
        equals(<int>{DateTime.tuesday, DateTime.saturday}),
      );
    });

    test('every N days claims all seven, deliberately', () {
      // An interval schedule is anchored to a date, not to a weekday, so it
      // has no day-of-week set. Claiming all seven makes the clash test err
      // towards rejecting; the alternative errs towards two reminders for the
      // same medicine at the same minute.
      expect(
        _schedule(
          frequency: Frequency.everyNDays,
          intervalDays: 3,
        ).occupiedDaysOfWeek,
        equals(<int>{1, 2, 3, 4, 5, 6, 7}),
      );
    });
  });

  group('clashesWith — the duplicate-schedule predicate', () {
    test('same medicine, same time, overlapping days is a clash', () {
      final Schedule existing = _schedule(id: 'a', timeOfDay: '08:00');
      final Schedule candidate = _schedule(id: 'b', timeOfDay: '08:00');

      expect(candidate.clashesWith(existing), isTrue);
    });

    test('same time on disjoint day sets is NOT a clash', () {
      // The PRD's own example of a legitimate pair. Dropping the day-overlap
      // condition would reject it.
      final Schedule monday = _schedule(
        id: 'a',
        timeOfDay: '08:00',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.monday},
      );
      final Schedule tuesday = _schedule(
        id: 'b',
        timeOfDay: '08:00',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.tuesday},
      );

      expect(tuesday.clashesWith(monday), isFalse);
      expect(monday.clashesWith(tuesday), isFalse);
    });

    test('a different time on the same days is NOT a clash', () {
      // The ordinary case: morning and night.
      final Schedule morning = _schedule(id: 'a', timeOfDay: '08:00');
      final Schedule night = _schedule(id: 'b', timeOfDay: '20:00');

      expect(night.clashesWith(morning), isFalse);
    });

    test('a different medicine at the same time is NOT a clash', () {
      // Two medicines taken together is the normal shape of a regimen.
      final Schedule mine = _schedule(id: 'a', medicineId: 'm1');
      final Schedule theirs = _schedule(id: 'b', medicineId: 'm2');

      expect(theirs.clashesWith(mine), isFalse);
    });

    test('a Schedule never clashes with itself', () {
      // So that editing one and saving it unchanged succeeds.
      final Schedule schedule = _schedule(id: 'a');

      expect(schedule.clashesWith(schedule), isFalse);
    });

    test('partial day overlap is enough', () {
      final Schedule weekdays = _schedule(
        id: 'a',
        frequency: Frequency.weekdays,
      );
      final Schedule fridayAndSunday = _schedule(
        id: 'b',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.friday, DateTime.sunday},
      );

      expect(fridayAndSunday.clashesWith(weekdays), isTrue);
    });

    test(
      'the same wall clock in a different zone IS a clash, deliberately',
      () {
        // Not an oversight in the predicate: `clashesWith` does not compare
        // zones, and the doc on it says why. The zone is the device's at the
        // moment of writing rather than something the user picks per Schedule,
        // so two zones on one Medicine means the user travelled between adding
        // them -- and what they see in the list is two doses at "8:00".
        // Comparing zones would make the duplicate rule evadable by a flight,
        // which is the one route to "two reminders at the same minute" a user
        // cannot see coming.
        final Schedule colombo = _schedule(
          id: 'a',
          ianaTimezone: 'Asia/Colombo',
        );
        final Schedule london = _schedule(
          id: 'b',
          ianaTimezone: 'Europe/London',
        );

        expect(london.clashesWith(colombo), isTrue);
        expect(colombo.clashesWith(london), isTrue);
      },
    );

    test('weekdays and a weekend-only set do not clash', () {
      final Schedule weekdays = _schedule(
        id: 'a',
        frequency: Frequency.weekdays,
      );
      final Schedule weekend = _schedule(
        id: 'b',
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.saturday, DateTime.sunday},
      );

      expect(weekend.clashesWith(weekdays), isFalse);
    });
  });

  group('pairingViolation — the domain\'s rule, not the schema\'s', () {
    test('the four well-formed shapes are accepted', () {
      expect(_schedule().pairingViolation(), isNull);
      expect(
        _schedule(frequency: Frequency.weekdays).pairingViolation(),
        isNull,
      );
      expect(
        _schedule(
          frequency: Frequency.specificDays,
          daysOfWeek: <int>{DateTime.wednesday},
        ).pairingViolation(),
        isNull,
      );
      expect(
        _schedule(
          frequency: Frequency.everyNDays,
          intervalDays: 2,
        ).pairingViolation(),
        isNull,
      );
    });

    test('specific days with no days is refused', () {
      expect(
        _schedule(frequency: Frequency.specificDays).pairingViolation(),
        contains('at least one day'),
      );
      expect(
        _schedule(
          frequency: Frequency.specificDays,
          daysOfWeek: <int>{},
        ).pairingViolation(),
        contains('at least one day'),
      );
    });

    test('every N days with no interval is refused', () {
      expect(
        _schedule(frequency: Frequency.everyNDays).pairingViolation(),
        contains('how many days apart'),
      );
    });

    test('an interval below two is refused', () {
      expect(Schedule.minimumIntervalDays, 2);
      expect(
        _schedule(
          frequency: Frequency.everyNDays,
          intervalDays: 1,
        ).pairingViolation(),
        isNotNull,
        reason: 'every 1 days is "every day" written the long way',
      );
    });

    test('a companion field on a frequency that has none is refused', () {
      expect(
        _schedule(daysOfWeek: <int>{DateTime.monday}).pairingViolation(),
        isNotNull,
      );
      expect(_schedule(intervalDays: 3).pairingViolation(), isNotNull);
      expect(
        _schedule(
          frequency: Frequency.specificDays,
          daysOfWeek: <int>{DateTime.monday},
          intervalDays: 3,
        ).pairingViolation(),
        isNotNull,
      );
      expect(
        _schedule(
          frequency: Frequency.everyNDays,
          intervalDays: 3,
          daysOfWeek: <int>{DateTime.monday},
        ).pairingViolation(),
        isNotNull,
      );
    });
  });

  group('Medicine holds calendar dates, not instants', () {
    test('a time of day is discarded, in the zone it was given in', () {
      final Medicine medicine = _medicine(
        startDate: DateTime(2026, 9, 7, 23, 45),
      );

      expect(medicine.startDate, DateTime(2026, 9, 7));
      expect(medicine.startDate.hour, 0);
      expect(
        medicine.startDate.isUtc,
        isFalse,
        reason:
            'a UTC midnight is the previous day for every user east of UTC, '
            'so "started today" would read as "started yesterday"',
      );
    });

    test('a null end date stays null', () {
      expect(_medicine().endDate, isNull);
    });

    test('an end date is truncated the same way', () {
      final Medicine medicine = _medicine(endDate: DateTime(2026, 12, 31, 6));
      expect(medicine.endDate, DateTime(2026, 12, 31));
    });

    test('active defaults to true', () {
      expect(_medicine().active, isTrue);
    });

    test('copyWith moves neither the identity nor the glyph', () {
      // AD-22: the glyph is assigned once and never recomputed, so an edit
      // must not be able to change it.
      final Medicine original = _medicine(glyphIndex: 2);
      final Medicine edited = original.copyWith(name: 'Metformin XR');

      expect(edited.id, original.id);
      expect(edited.glyphIndex, 2);
      expect(edited.name, 'Metformin XR');
      expect(edited.dosageAmount, original.dosageAmount);
    });
  });

  group('copyWith carries every field it does not replace', () {
    // D5. The previous version of this asserted `name`, `dosageAmount` and the
    // glyph and nothing else, so eleven separate mutations survived -- each of
    // them a field silently reset on every edit. The worst was Schedule's
    // `daysOfWeek`: dropping its `??` meant editing a specific-days Schedule's
    // TIME wiped the days it fell on, with no error and no visible cause.
    //
    // Every field is populated and distinct, one field is replaced, and every
    // other field is asserted individually. The whole-object `==` at the end
    // is the backstop for a field added later and forgotten here.

    test('Medicine keeps all ten other fields', () {
      final Medicine original = _fullMedicine();
      final Medicine edited = original.copyWith(name: 'Metformin XR');

      expect(edited.name, 'Metformin XR');
      expect(edited.id, 'medicine-id');
      expect(edited.condition, 'blood sugar');
      expect(edited.glyphIndex, 2);
      expect(edited.form, 'capsule');
      expect(edited.dosageAmount, 2.5);
      expect(edited.dosageUnit, 'ml');
      expect(edited.instructions, 'with food');
      expect(edited.startDate, DateTime(2026, 9, 7));
      expect(edited.endDate, DateTime(2026, 12, 31));
      expect(edited.active, isFalse);

      expect(
        edited,
        equals(original.copyWith(name: 'Metformin XR')),
        reason: 'two identical edits produce equal Medicines',
      );
    });

    test('Medicine replaces each field on its own, and only that one', () {
      final Medicine original = _fullMedicine();

      // One case per replaceable field: the field changes, and the object is
      // otherwise equal to the original with the same field set. A mutation
      // that dropped any `??` fails whichever case names the field it broke.
      expect(
        original.copyWith(condition: 'blood pressure').condition,
        'blood pressure',
      );
      expect(original.copyWith(form: 'tablet').form, 'tablet');
      expect(original.copyWith(dosageAmount: 1).dosageAmount, 1);
      expect(original.copyWith(dosageUnit: 'mg').dosageUnit, 'mg');
      expect(
        original.copyWith(instructions: 'before bed').instructions,
        'before bed',
      );
      expect(
        original.copyWith(startDate: DateTime(2026, 1, 1)).startDate,
        DateTime(2026, 1, 1),
      );
      expect(
        original.copyWith(endDate: DateTime(2027, 1, 1)).endDate,
        DateTime(2027, 1, 1),
      );
      expect(original.copyWith(active: true).active, isTrue);

      // And each of those leaves the rest alone.
      for (final Medicine edited in <Medicine>[
        original.copyWith(condition: 'blood pressure'),
        original.copyWith(form: 'tablet'),
        original.copyWith(dosageAmount: 1),
        original.copyWith(dosageUnit: 'mg'),
        original.copyWith(instructions: 'before bed'),
        original.copyWith(startDate: DateTime(2026, 1, 1)),
        original.copyWith(endDate: DateTime(2027, 1, 1)),
        original.copyWith(active: true),
      ]) {
        expect(edited.id, original.id);
        expect(edited.name, original.name);
        expect(edited.glyphIndex, original.glyphIndex);
      }
    });

    test('copyWith with nothing supplied is an equal Medicine', () {
      final Medicine original = _fullMedicine();
      expect(original.copyWith(), equals(original));
    });

    test('Schedule keeps all eight other fields', () {
      final Schedule original = _fullSchedule();
      final Schedule edited = original.copyWith(timeOfDay: '09:15');

      expect(edited.timeOfDay, '09:15');
      expect(edited.id, 'schedule-id');
      expect(
        edited.medicineId,
        'medicine-id',
        reason: 'a Schedule cannot change parents (AD-12)',
      );
      expect(edited.ianaTimezone, 'Europe/London');
      expect(edited.frequency, Frequency.specificDays);
      expect(
        edited.daysOfWeek,
        equals(<int>{DateTime.monday, DateTime.thursday}),
        reason:
            'editing the time must not wipe the days -- the mutation that '
            'dropped this `??` survived the whole suite once',
      );
      expect(edited.intervalDays, isNull);
      expect(edited.dosageAmount, 0.5);
      expect(edited.reminderOverride, 'PT45M');
    });

    test('Schedule replaces each field on its own, and only that one', () {
      final Schedule original = _fullSchedule();

      expect(
        original.copyWith(ianaTimezone: 'Asia/Colombo').ianaTimezone,
        'Asia/Colombo',
      );
      expect(
        original.copyWith(daysOfWeek: <int>{DateTime.friday}).daysOfWeek,
        equals(<int>{DateTime.friday}),
      );
      expect(original.copyWith(dosageAmount: 2).dosageAmount, 2);
      expect(
        original.copyWith(reminderOverride: 'PT10M').reminderOverride,
        'PT10M',
      );

      for (final Schedule edited in <Schedule>[
        original.copyWith(ianaTimezone: 'Asia/Colombo'),
        original.copyWith(daysOfWeek: <int>{DateTime.friday}),
        original.copyWith(dosageAmount: 2),
        original.copyWith(reminderOverride: 'PT10M'),
      ]) {
        expect(edited.id, original.id);
        expect(edited.medicineId, original.medicineId);
        expect(edited.timeOfDay, original.timeOfDay);
        expect(edited.frequency, original.frequency);
        expect(edited.intervalDays, original.intervalDays);
      }
    });

    test('Schedule keeps its interval when the frequency stays', () {
      final Schedule interval = _schedule(
        frequency: Frequency.everyNDays,
        intervalDays: 3,
      );

      expect(interval.copyWith(timeOfDay: '09:00').intervalDays, 3);
      expect(
        interval.copyWith(timeOfDay: '09:00').frequency,
        Frequency.everyNDays,
      );
      expect(interval.copyWith(intervalDays: 5).intervalDays, 5);
    });

    test('copyWith with nothing supplied is an equal Schedule', () {
      final Schedule original = _fullSchedule();
      expect(original.copyWith(), equals(original));
    });
  });

  group('value equality (Riverpod holds these)', () {
    // Identity equality would make every provider rebuild look like a change
    // and repaint every surface showing the Medicine. It also lets a test
    // compare two objects with one `expect` rather than field by field, so a
    // field added without being carried through the adapter's mapping shows up
    // as an inequality instead of as a field nobody thought to assert.

    test('two Medicines with the same fields are equal and hash alike', () {
      expect(_fullMedicine(), equals(_fullMedicine()));
      expect(_fullMedicine().hashCode, _fullMedicine().hashCode);
    });

    test('a difference in any single Medicine field breaks equality', () {
      final Medicine base = _fullMedicine();
      for (final Medicine other in <Medicine>[
        base.copyWith(name: 'Other'),
        base.copyWith(condition: 'other'),
        base.copyWith(form: 'other'),
        base.copyWith(dosageAmount: 99),
        base.copyWith(dosageUnit: 'other'),
        base.copyWith(instructions: 'other'),
        base.copyWith(startDate: DateTime(2020, 1, 1)),
        base.copyWith(endDate: DateTime(2030, 1, 1)),
        base.copyWith(active: true),
      ]) {
        expect(other, isNot(equals(base)));
      }
      expect(
        Medicine(
          id: 'a-different-id',
          name: base.name,
          condition: base.condition,
          glyphIndex: base.glyphIndex,
          form: base.form,
          dosageAmount: base.dosageAmount,
          dosageUnit: base.dosageUnit,
          instructions: base.instructions,
          startDate: base.startDate,
          endDate: base.endDate,
          active: base.active,
        ),
        isNot(equals(base)),
      );
    });

    test('two Schedules with the same fields are equal and hash alike', () {
      expect(_fullSchedule(), equals(_fullSchedule()));
      expect(
        _fullSchedule().hashCode,
        _fullSchedule().hashCode,
        reason:
            'a Set hashes by identity, so the day set has to be hashed by its '
            'contents or == and hashCode disagree',
      );
    });

    test('equal day sets in a different order are still equal', () {
      final Schedule a = _schedule(
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.thursday, DateTime.monday},
      );
      final Schedule b = _schedule(
        frequency: Frequency.specificDays,
        daysOfWeek: <int>{DateTime.monday, DateTime.thursday},
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a difference in any single Schedule field breaks equality', () {
      final Schedule base = _fullSchedule();
      for (final Schedule other in <Schedule>[
        base.copyWith(timeOfDay: '07:00'),
        base.copyWith(ianaTimezone: 'Asia/Colombo'),
        base.copyWith(daysOfWeek: <int>{DateTime.monday}),
        base.copyWith(dosageAmount: 9),
        base.copyWith(reminderOverride: 'PT1M'),
      ]) {
        expect(other, isNot(equals(base)));
      }
      expect(
        _schedule(frequency: Frequency.everyNDays, intervalDays: 3),
        isNot(
          equals(_schedule(frequency: Frequency.everyNDays, intervalDays: 4)),
        ),
      );
      expect(
        _schedule(),
        isNot(equals(_schedule(medicineId: 'another-medicine'))),
      );
    });

    test('a null day set is not an empty one', () {
      expect(
        _schedule(),
        isNot(
          equals(
            _schedule(frequency: Frequency.specificDays, daysOfWeek: <int>{1}),
          ),
        ),
      );
    });
  });

  group('Medicine enforces FR-1 and FR-2', () {
    test('a glyph outside the four that exist is a programming error', () {
      // AD-22 assigns it; no form can produce it. `glyphCount` is 4, so 4 is
      // the first index that does not exist.
      expect(() => _medicine(glyphIndex: -1), throwsArgumentError);
      expect(() => _medicine(glyphIndex: glyphCount), throwsArgumentError);
      expect(_medicine(glyphIndex: glyphCount - 1).glyphIndex, glyphCount - 1);
    });

    test('a dosage amount that is not a number is a programming error', () {
      // Rejected by the constructor rather than by `violation`, because it
      // poisons every later comparison: `NaN <= 0` is false, so it would slip
      // past a range check and be stored, and SQLite has no NaN to read back.
      expect(() => _medicine(dosageAmount: double.nan), throwsArgumentError);
      expect(
        () => _medicine(dosageAmount: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => _medicine(dosageAmount: double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('a well-formed Medicine has no violation', () {
      expect(_medicine().violation(), isNull);
      expect(_fullMedicine().violation(), isNull);
    });

    test('FR-1: a name is required', () {
      expect(_medicine(name: '').violation(), contains('name'));
      expect(
        _medicine(name: '   ').violation(),
        isNotNull,
        reason: 'whitespace is not a name',
      );
    });

    test('FR-1: a dosage amount above zero is required', () {
      expect(_medicine(dosageAmount: 0).violation(), isNotNull);
      expect(_medicine(dosageAmount: -1).violation(), isNotNull);
      expect(_medicine(dosageAmount: 0.5).violation(), isNull);
    });

    test('FR-1: a unit and a form are required', () {
      expect(_medicine(dosageUnit: '').violation(), contains('unit'));
      expect(_medicine(dosageUnit: ' ').violation(), isNotNull);
      expect(_medicine(form: '').violation(), contains('form'));
      expect(_medicine(form: ' ').violation(), isNotNull);
    });

    test('FR-2: an end date before the start date is refused', () {
      expect(
        _medicine(
          startDate: DateTime(2026, 9, 7),
          endDate: DateTime(2026, 9, 6),
        ).violation(),
        contains('end date'),
      );
      // The same day is a one-day regimen, which is legitimate.
      expect(
        _medicine(
          startDate: DateTime(2026, 9, 7),
          endDate: DateTime(2026, 9, 7),
        ).violation(),
        isNull,
      );
      expect(
        _medicine(
          startDate: DateTime(2026, 9, 7),
          endDate: DateTime(2026, 9, 8),
        ).violation(),
        isNull,
      );
    });

    test('the condition and the instructions are never validated', () {
      // The PRD forbids validating the condition: it is displayed and never
      // interpreted. An empty string and a paragraph are both fine.
      expect(_medicine(condition: '').violation(), isNull);
      expect(_medicine(condition: 'x' * 500).violation(), isNull);
      expect(_medicine(instructions: '').violation(), isNull);
    });
  });

  group('FR-1\'s dosage-unit vocabulary', () {
    test('is the five options FR-1 names, in FR-1\'s order', () {
      expect(
        dosageUnits,
        equals(<String>['tablet', 'capsule', 'ml', 'drop', 'other']),
        reason:
            'FR-1: "Dosage unit is selected from a defined set (tablet, '
            'capsule, ml, drop, other)". Story 1.5 renders this list rather '
            'than five string literals in a widget.',
      );
    });

    test('the free-text escape hatch is last and is named', () {
      expect(dosageUnitOther, 'other');
      expect(dosageUnits.last, dosageUnitOther);
    });

    test('a free-text unit is not one of the fixed options', () {
      expect(isFixedDosageUnit('tablet'), isTrue);
      expect(isFixedDosageUnit('puff'), isFalse);
      expect(
        _medicine(dosageUnit: 'puff').violation(),
        isNull,
        reason:
            'FR-1 permits a free-text unit behind the "other" option, so a '
            'Medicine does not require a unit from the list',
      );
    });
  });
}

Schedule _schedule({
  String id = 's1',
  String medicineId = 'm1',
  String timeOfDay = '08:00',
  String ianaTimezone = 'Asia/Colombo',
  Frequency frequency = Frequency.everyDay,
  Set<int>? daysOfWeek,
  int? intervalDays,
  double dosageAmount = 1,
  String? reminderOverride,
}) => Schedule(
  id: id,
  medicineId: medicineId,
  timeOfDay: timeOfDay,
  ianaTimezone: ianaTimezone,
  frequency: frequency,
  daysOfWeek: daysOfWeek,
  intervalDays: intervalDays,
  dosageAmount: dosageAmount,
  reminderOverride: reminderOverride,
);

Medicine _medicine({
  String id = 'm1',
  String name = 'Metformin',
  String? condition,
  int glyphIndex = 0,
  String form = 'tablet',
  double dosageAmount = 1,
  String dosageUnit = 'tablet',
  String? instructions,
  DateTime? startDate,
  DateTime? endDate,
  bool active = true,
}) => Medicine(
  id: id,
  name: name,
  condition: condition,
  glyphIndex: glyphIndex,
  form: form,
  dosageAmount: dosageAmount,
  dosageUnit: dosageUnit,
  instructions: instructions,
  startDate: startDate ?? DateTime(2026, 9, 7),
  endDate: endDate,
  active: active,
);

/// A Medicine with EVERY optional field populated and every value distinct.
///
/// The point of the distinctness: a `copyWith` test that used the defaults
/// could not tell a field that was carried through from a field that happened
/// to match the default it was rebuilt with.
Medicine _fullMedicine() => Medicine(
  id: 'medicine-id',
  name: 'Metformin',
  condition: 'blood sugar',
  glyphIndex: 2,
  form: 'capsule',
  dosageAmount: 2.5,
  dosageUnit: 'ml',
  instructions: 'with food',
  startDate: DateTime(2026, 9, 7),
  endDate: DateTime(2026, 12, 31),
  active: false,
);

/// A Schedule with every optional field populated. See [_fullMedicine].
Schedule _fullSchedule() => Schedule(
  id: 'schedule-id',
  medicineId: 'medicine-id',
  timeOfDay: '20:30',
  ianaTimezone: 'Europe/London',
  frequency: Frequency.specificDays,
  daysOfWeek: <int>{DateTime.monday, DateTime.thursday},
  dosageAmount: 0.5,
  reminderOverride: 'PT45M',
);
