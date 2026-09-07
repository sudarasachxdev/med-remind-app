// One repeating time at which a Medicine is taken (FR-4), and the rule that
// decides when two of them collide.
//
// AD-1: pure Dart. The only import is the sibling `Frequency`.
//
// AD-6 is the load-bearing decision in this file: a Schedule stores a **local
// wall-clock time plus an IANA zone identifier, and no UTC instant**. "Every
// day at 8:00" has to keep its plain meaning across a DST transition, and it
// only does so if 8:00 is what was stored. A UTC instant computed once at
// creation would drift by an hour twice a year -- the failure class the PRD
// found in competitor app-store reviews. There is deliberately no
// `scheduledUtc`, no epoch field, and no member of any date-time type on this
// class at all; the only UTC value in the product is the ordering column on a
// generated Dose, which Story 1.7 owns.
//
// That last claim is enforced rather than asserted: `test/story_scope_test.dart`
// reads this file and fails on a member whose name or type names an instant.
// A test over behaviour cannot see a member that was merely ADDED, which is how
// a second representation of the time would arrive.

import 'frequency.dart';

/// A time of day, a zone and a repeat pattern: one recurring dose of one
/// Medicine.
///
/// Owned by its Medicine (AD-12). A Schedule has no independent lifecycle: it
/// is created, edited and deleted only through `MedicineRepository`, and it
/// goes when its Medicine goes.
final class Schedule {
  /// Creates a Schedule.
  ///
  /// Throws [ArgumentError] when [timeOfDay] is not a real 24-hour `HH:mm`,
  /// when [ianaTimezone] is not shaped like a zone identifier, or when
  /// [daysOfWeek] holds a value outside 1..7. All three are programming errors
  /// rather than domain failures -- a caller reached this with a value no user
  /// input can produce, because each is chosen from a picker -- and all three
  /// must be loud: a malformed time silently stored is a reminder that never
  /// fires, an unresolvable zone is a reminder that cannot be scheduled at all,
  /// and the schema cannot catch either because both columns are text.
  ///
  /// The [frequency]/companion-field pairing is checked by [pairingViolation]
  /// rather than here, so that a half-built Schedule can exist while a user is
  /// still filling in the Story 1.5 form.
  Schedule({
    required this.id,
    required this.medicineId,
    required this.timeOfDay,
    required this.ianaTimezone,
    required this.frequency,
    Set<int>? daysOfWeek,
    this.intervalDays,
    required this.dosageAmount,
    this.reminderOverride,
  }) : daysOfWeek = daysOfWeek == null
           ? null
           : Set<int>.unmodifiable(daysOfWeek) {
    if (!isValidTimeOfDay(timeOfDay)) {
      throw ArgumentError.value(
        timeOfDay,
        'timeOfDay',
        'must be a 24-hour wall-clock time in HH:mm form',
      );
    }
    if (!isValidIanaTimezone(ianaTimezone)) {
      throw ArgumentError.value(
        ianaTimezone,
        'ianaTimezone',
        'must be an IANA zone identifier such as Asia/Colombo',
      );
    }
    final Set<int>? days = this.daysOfWeek;
    if (days != null) {
      for (final int day in days) {
        if (day < DateTime.monday || day > DateTime.sunday) {
          throw ArgumentError.value(
            day,
            'daysOfWeek',
            'must be 1 (Monday) through 7 (Sunday)',
          );
        }
      }
    }
  }

  /// UUID v4, as text (the spine's Identifiers convention).
  final String id;

  /// The `Medicine.id` this Schedule belongs to.
  ///
  /// A foreign key in the schema, enforced by `PRAGMA foreign_keys = ON`: a
  /// Schedule pointing at no Medicine is an orphan reminder, which would fire
  /// for a medicine the user cannot see.
  ///
  /// Fixed for the life of the Schedule. [copyWith] cannot change it, and
  /// `MedicineRepository.saveSchedule` rejects a Schedule whose stored row
  /// belongs to a different Medicine -- a move would strand the Schedule's
  /// duplicate check on the wrong parent.
  final String medicineId;

  /// The local wall-clock time, as 24-hour `HH:mm` (AD-6).
  ///
  /// Wall clock, not an instant. Stored as written and interpreted in
  /// [ianaTimezone] at the moment each Dose is generated, so 08:00 stays 08:00
  /// across a DST transition instead of becoming 07:00 or 09:00.
  final String timeOfDay;

  /// The IANA zone [timeOfDay] is read in -- for example `Asia/Colombo`.
  ///
  /// Stored per Schedule rather than read from the device, so that a Schedule
  /// keeps its meaning when the user travels: the zone is part of what the
  /// user said, and re-reading the device zone would move every existing
  /// reminder on landing.
  final String ianaTimezone;

  /// Which of FR-4's four patterns this Schedule repeats on.
  final Frequency frequency;

  /// The days [Frequency.specificDays] names, as 1 (Monday) .. 7 (Sunday).
  ///
  /// `DateTime.monday` .. `DateTime.sunday`, so a caller never has to guess
  /// whether the week starts at 0 or on Sunday. `null` for every other
  /// frequency. Unmodifiable once constructed.
  final Set<int>? daysOfWeek;

  /// The interval [Frequency.everyNDays] counts in days. `null` otherwise.
  final int? intervalDays;

  /// How much is taken at this occurrence.
  ///
  /// Defaults to the Medicine's amount at the point the user creates it (Story
  /// 1.5), and is stored per Schedule so that "two in the morning, one at
  /// night" needs no second Medicine.
  final double dosageAmount;

  /// A per-Schedule escalation-window override, or `null` to inherit.
  ///
  /// Story 1.6 gives this a type and AD-16 the resolution order -- per-Schedule
  /// override, then app-wide override, then the formula. It is carried as
  /// opaque text here so that the column exists before the policy does and the
  /// schema does not need a second migration to gain it.
  final String? reminderOverride;

  /// The minimum [intervalDays] [Frequency.everyNDays] admits.
  ///
  /// An interval of 1 is [Frequency.everyDay] written the long way, and two
  /// spellings of one pattern would have to be kept in step by every reader.
  static const int minimumIntervalDays = 2;

  /// Whether [value] is a 24-hour wall-clock time in `HH:mm` form.
  ///
  /// Strict on purpose: exactly two digits, a colon, exactly two digits, hours
  /// 00..23 and minutes 00..59. `8:00` is rejected because two spellings of one
  /// time would compare unequal, and [clashesWith] decides whether a duplicate
  /// exists by comparing these strings.
  static bool isValidTimeOfDay(String value) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return false;
    final int hour = int.parse(value.substring(0, 2));
    final int minute = int.parse(value.substring(3, 5));
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  /// Whether [value] is shaped like an IANA zone identifier.
  ///
  /// A shape check, not a lookup: `Area/Location`, optionally
  /// `Area/Region/Location`, in the character set the IANA database uses. It
  /// accepts `Asia/Colombo` and `America/Argentina/Buenos_Aires`, and rejects
  /// the four things that actually arrive by mistake -- an empty string, a bare
  /// city (`Colombo`), a fixed offset (`+05:30`) and an abbreviation (`IST`,
  /// which is ambiguous between three zones).
  ///
  /// It deliberately does NOT consult `package:timezone`. Three reasons, in
  /// order of weight: AD-1 forbids the domain a package import, so the check
  /// would have to move to the adapter and the model would go back to accepting
  /// anything; the zone database is versioned, so a zone this build has never
  /// heard of is a reason to reject a WRITE and never a reason to fail a READ
  /// of a row a newer build stored; and loading the database costs a
  /// `tz.initializeTimeZones()` that AD-3's one-process rule puts in the
  /// composition root. Epic 3's Reconciler resolves the zone for real, where it
  /// has the database in hand -- this only stops a value that could never
  /// resolve anywhere.
  static bool isValidIanaTimezone(String value) => RegExp(
    r'^[A-Za-z][A-Za-z0-9_+-]*(?:/[A-Za-z0-9_+-]+){1,2}$',
  ).hasMatch(value);

  /// Why this Schedule's [frequency] and companion fields do not agree, or
  /// `null` when they do.
  ///
  /// The pairing is the domain's rule and not the schema's: `daysOfWeek` and
  /// `intervalDays` are both nullable columns because three of the four
  /// frequencies leave each one empty, so nothing in SQLite can tell that
  /// [Frequency.everyNDays] without an interval is meaningless. Returned as a
  /// message rather than thrown so a form can show it while the user is still
  /// choosing -- and checked again by the adapter on READ, so a row written by
  /// a raw statement cannot reach a caller in a shape no frequency admits.
  String? pairingViolation() {
    switch (frequency) {
      case Frequency.everyDay:
      case Frequency.weekdays:
        if (daysOfWeek != null) {
          return 'A ${frequency.name} schedule does not name days of the week.';
        }
        if (intervalDays != null) {
          return 'A ${frequency.name} schedule does not have an interval.';
        }
        return null;
      case Frequency.specificDays:
        if (daysOfWeek == null || daysOfWeek!.isEmpty) {
          return 'Choose at least one day of the week.';
        }
        if (intervalDays != null) {
          return 'A specific-days schedule does not have an interval.';
        }
        return null;
      case Frequency.everyNDays:
        if (intervalDays == null) {
          return 'Choose how many days apart the doses are.';
        }
        if (intervalDays! < minimumIntervalDays) {
          return 'An interval of $minimumIntervalDays days or more. '
              'Every day is a separate option.';
        }
        if (daysOfWeek != null) {
          return 'An every-N-days schedule does not name days of the week.';
        }
        return null;
    }
  }

  /// The days of the week on which this Schedule can produce a dose.
  ///
  /// [Frequency.everyNDays] answers all seven, deliberately. An interval
  /// schedule is anchored to a date rather than to a weekday, so it has no
  /// day-of-week set -- over enough weeks it lands on every day unless the
  /// interval is a multiple of seven, and even then which day depends on the
  /// start date rather than on anything stored here. Claiming all seven makes
  /// [clashesWith] err towards rejecting; the alternative errs towards two
  /// reminders for the same medicine at the same minute, which is the failure
  /// the PRD names.
  Set<int> get occupiedDaysOfWeek {
    switch (frequency) {
      case Frequency.everyDay:
      case Frequency.everyNDays:
        return const <int>{1, 2, 3, 4, 5, 6, 7};
      case Frequency.weekdays:
        return const <int>{
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        };
      case Frequency.specificDays:
        return daysOfWeek ?? const <int>{};
    }
  }

  /// Whether [other] is a duplicate of this Schedule: same Medicine, identical
  /// wall-clock time, and at least one day of the week in common.
  ///
  /// A Schedule never clashes with itself, so editing a Schedule and saving it
  /// unchanged is not a duplicate.
  ///
  /// All three conditions are required. Same time on disjoint day sets --
  /// Monday at 08:00 and Tuesday at 08:00 -- is a legitimate pair and the PRD's
  /// own example of one, so day overlap cannot be dropped from the test. Nor
  /// can the time: two schedules on the same day at different times are the
  /// ordinary case.
  ///
  /// [ianaTimezone] is deliberately NOT compared, so 08:00 Asia/Colombo and
  /// 08:00 Europe/London on one Medicine count as a clash even though they are
  /// different instants. Two reasons. The zone is not something the user picks
  /// per Schedule -- it is the device zone at the moment of writing -- so two
  /// zones on one Medicine means the user travelled between adding them, and
  /// what they see in the list is two doses at "8:00". And comparing zones
  /// would make the duplicate rule evadable by a flight: the same 08:00 dose
  /// entered twice in two cities would be accepted, which is the "two reminders
  /// at the same minute" failure FR-4 exists to prevent, arriving by the one
  /// route a user cannot see coming. Epic 3, which resolves zones for real, is
  /// where a same-instant comparison would belong if one is ever wanted.
  bool clashesWith(Schedule other) {
    if (other.id == id) return false;
    if (other.medicineId != medicineId) return false;
    if (other.timeOfDay != timeOfDay) return false;
    return occupiedDaysOfWeek.intersection(other.occupiedDaysOfWeek).isNotEmpty;
  }

  /// A copy with the given fields replaced. [id] and [medicineId] are absent:
  /// an edit may not move a Schedule between Medicines or change its identity.
  ///
  /// Nullable fields cannot be cleared through this method -- `null` means "not
  /// supplied" -- so a change of [frequency] that drops `daysOfWeek` or
  /// `intervalDays` is made by constructing the Schedule directly.
  Schedule copyWith({
    String? timeOfDay,
    String? ianaTimezone,
    Frequency? frequency,
    Set<int>? daysOfWeek,
    int? intervalDays,
    double? dosageAmount,
    String? reminderOverride,
  }) => Schedule(
    id: id,
    medicineId: medicineId,
    timeOfDay: timeOfDay ?? this.timeOfDay,
    ianaTimezone: ianaTimezone ?? this.ianaTimezone,
    frequency: frequency ?? this.frequency,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    intervalDays: intervalDays ?? this.intervalDays,
    dosageAmount: dosageAmount ?? this.dosageAmount,
    reminderOverride: reminderOverride ?? this.reminderOverride,
  );

  /// Value equality over every field. See `Medicine.==` for why.
  @override
  bool operator ==(Object other) =>
      other is Schedule &&
      other.id == id &&
      other.medicineId == medicineId &&
      other.timeOfDay == timeOfDay &&
      other.ianaTimezone == ianaTimezone &&
      other.frequency == frequency &&
      _sameDays(other.daysOfWeek, daysOfWeek) &&
      other.intervalDays == intervalDays &&
      other.dosageAmount == dosageAmount &&
      other.reminderOverride == reminderOverride;

  @override
  int get hashCode => Object.hash(
    id,
    medicineId,
    timeOfDay,
    ianaTimezone,
    frequency,
    // A Set's own hashCode is identity-based, so two equal day sets would
    // otherwise hash differently and break the == / hashCode contract.
    daysOfWeek == null ? null : Object.hashAllUnordered(daysOfWeek!),
    intervalDays,
    dosageAmount,
    reminderOverride,
  );

  static bool _sameDays(Set<int>? a, Set<int>? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.length == b.length && a.containsAll(b);
  }

  @override
  String toString() =>
      'Schedule($id, medicine $medicineId, $timeOfDay $ianaTimezone, '
      '${frequency.name})';
}
