// The one path to a Medicine or a Schedule (AD-12).
//
// AD-1: pure Dart. This file imports sibling domain models and nothing else --
// no Drift, no Flutter. `test/architecture_test.dart` fails the build if a
// `package:` import other than `package:meta/` appears anywhere under
// `lib/domain/`.
//
// AD-12: `Medicine` is the aggregate root for its `Schedule`s, and this is the
// only interface that creates, edits or deletes either. No DAO is exposed past
// the adapter that implements this, deliberately: a second write path to
// `schedules` would put the duplicate-schedule rule and the delete cascade in
// two places, and one of the two copies would be the one that is wrong.
//
// Named for the role, not the technology (the spine's naming rule): the port is
// `MedicineRepository`, the Drift adapter is `DriftMedicineRepository`. It is a
// *repository* rather than a store because it owns an aggregate -- contrast
// `OnboardingStateStore`, which owns a single boolean.

import '../model/domain_failure.dart';
import '../model/frequency.dart';
import '../model/medicine.dart';
import '../model/schedule.dart';

/// Reads and writes Medicines and the Schedules they own.
///
/// **What a failure does.** Every method on this port either completes the
/// write or throws. None of them returns a success flag, swallows an exception
/// or reports a partial result, because PRD §9 forbids the app reporting a
/// success it did not achieve -- a saved medicine that was not saved is the
/// worst bug this product can have. Specifically:
///
///   * every failure is a [MedicineRepositoryFailure], and no other exception
///     type escapes: the adapter translates a malformed row, an unparseable
///     date and a frequency it cannot read into
///     [MedicineRecordNotReadableFailure] at the boundary, per the spine's
///     Errors convention,
///   * [addMedicine] and [saveMedicine] throw [MedicineNotValidFailure] when
///     `Medicine.violation` reports one -- FR-1's name, amount and unit,
///     FR-2's end date -- and nothing is written,
///   * [addSchedule] and [saveSchedule] throw [ScheduleNotValidFailure] when a
///     Schedule's frequency and its companion fields do not agree, and
///     [DuplicateScheduleFailure] when the result would duplicate an existing
///     Schedule. In both cases nothing is written,
///   * [deleteMedicine] removes the Medicine and every Schedule it owns in one
///     transaction. A failure part-way leaves *neither* removed -- never the
///     Medicine without its Schedules, which would orphan reminders, and never
///     the Schedules without their Medicine, which would silently stop them.
///
/// A read of something absent is not a failure: [findMedicine] answers `null`
/// and [schedulesFor] answers an empty list.
abstract interface class MedicineRepository {
  /// Every Medicine, active or not, oldest first.
  ///
  /// Insertion order rather than alphabetical: the glyph sequence AD-22
  /// assigns is an insertion-order sequence, and a list that reordered it would
  /// make the 0,1,2,3 pattern unverifiable from the outside.
  Future<List<Medicine>> allMedicines();

  /// The Medicine with [id], or `null` when there is none.
  Future<Medicine?> findMedicine(String id);

  /// Creates a Medicine and returns it, with its [Medicine.id] and its
  /// [Medicine.glyphIndex] assigned.
  ///
  /// Neither is a parameter, and that is the point. The id is a UUID v4 minted
  /// by the implementation, and the glyph is `count(existing medicines) mod 4`
  /// read inside the same transaction as the insert (AD-22) -- a caller that
  /// could pass either one could hand two Medicines the same identity, or pick
  /// its own glyph and defeat the decision that exists to stop every surface
  /// deriving one its own way.
  ///
  /// [startDate] is the caller's answer to FR-1's "a start date of today". This
  /// port takes no `Clock` and reads none: AD-5 confines the ambient clock to
  /// `lib/platform/clock/`, so "today" is decided by the feature that has a
  /// clock injected and passed in here as a plain calendar date.
  ///
  /// [active] defaults to `true` -- declared here rather than left to the
  /// implementation, so that a fake cannot quietly default it the other way and
  /// change what every caller means.
  ///
  /// Throws [MedicineNotValidFailure] when the resulting Medicine has a
  /// `Medicine.violation`.
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
  });

  /// Writes [medicine] over the stored row of the same id.
  ///
  /// [Medicine.glyphIndex] travels with the object and is written back
  /// unchanged; AD-22 forbids recomputing it, and `Medicine.copyWith` gives no
  /// way to alter it.
  ///
  /// Throws [MedicineNotValidFailure] when [medicine] has a
  /// `Medicine.violation`, and [MedicineNotFoundFailure] when no Medicine with
  /// that id is stored. An update that silently inserted would resurrect a
  /// medicine the user deleted on another surface.
  Future<void> saveMedicine(Medicine medicine);

  /// Deletes the Medicine with [id] and every Schedule it owns, in one
  /// transaction (AD-12).
  ///
  /// Idempotent: deleting an id that is not stored is not an error, so a second
  /// tap on a confirmed delete needs no guard at the call site.
  ///
  /// AD-12 and FR-3 name three tables, not two: a Medicine's Doses go with it
  /// as well. `doses` does not exist yet -- Story 1.7 owns it -- so Story 1.7
  /// must extend this transaction rather than delete doses from somewhere else.
  Future<void> deleteMedicine(String id);

  /// The Schedules of the Medicine with [medicineId], earliest time first.
  ///
  /// Empty when the Medicine has none, and empty when there is no such
  /// Medicine -- the two are not distinguished, because a caller that wants to
  /// know whether the Medicine exists asks [findMedicine].
  ///
  /// Throws [MedicineRecordNotReadableFailure] when a stored row cannot be read
  /// as a Schedule.
  Future<List<Schedule>> schedulesFor(String medicineId);

  /// Creates a Schedule on the Medicine with [medicineId] and returns it, with
  /// its [Schedule.id] assigned.
  ///
  /// The id is a UUID v4 minted by the implementation, for the same reason as
  /// in [addMedicine].
  ///
  /// Throws:
  ///   * [ScheduleNotValidFailure] when [frequency] and the companion fields do
  ///     not agree -- see `Schedule.pairingViolation`,
  ///   * [DuplicateScheduleFailure] when the Medicine already has a Schedule at
  ///     the same wall-clock time on an overlapping day set,
  ///   * [MedicineNotFoundFailure] when [medicineId] names no stored Medicine.
  ///     The foreign key would reject it anyway; this names what happened.
  ///
  /// In all three cases nothing is written.
  Future<Schedule> addSchedule({
    required String medicineId,
    required String timeOfDay,
    required String ianaTimezone,
    required Frequency frequency,
    Set<int>? daysOfWeek,
    int? intervalDays,
    required double dosageAmount,
    String? reminderOverride,
  });

  /// Writes [schedule] over the stored row of the same id.
  ///
  /// Throws the same three failures as [addSchedule], plus
  /// [ScheduleNotFoundFailure] when no Schedule with that id is stored. A
  /// Schedule never counts as a duplicate of itself, so saving one unchanged
  /// succeeds.
  ///
  /// A Schedule cannot be moved to another Medicine. `Schedule.copyWith` offers
  /// no way to change `medicineId`, and a hand-constructed Schedule whose
  /// `medicineId` differs from the stored row's is rejected with
  /// [ScheduleNotFoundFailure] naming the id -- it is not this Medicine's
  /// Schedule to save. A move would check for duplicates against the new parent
  /// only and could strand one on the old parent.
  Future<void> saveSchedule(Schedule schedule);

  /// Deletes the Schedule with [id]. Idempotent, like [deleteMedicine].
  ///
  /// Deleting the last Schedule of a Medicine leaves the Medicine with none.
  /// That is a legitimate state -- an as-needed medicine with no reminders --
  /// and not this port's business to prevent.
  Future<void> deleteSchedule(String id);
}

/// The base type of every failure [MedicineRepository] throws.
///
/// Sealed so that a caller switching over it is told by the compiler when a
/// case is added, rather than discovering the new failure as an unhandled
/// exception in front of a user. Grouped under [DomainFailure] so a feature can
/// catch one port's failures with `on MedicineRepositoryFailure` or every
/// port's with `on DomainFailure`.
sealed class MedicineRepositoryFailure extends DomainFailure {
  const MedicineRepositoryFailure();
}

/// A Schedule would duplicate one the Medicine already has.
///
/// "Duplicate" means all three of: the same Medicine, the identical wall-clock
/// time, and at least one day of the week in common -- `Schedule.clashesWith`.
/// The same time on disjoint days is a legitimate pair and is accepted.
final class DuplicateScheduleFailure extends MedicineRepositoryFailure {
  /// [existingScheduleId] and [timeOfDay] describe the Schedule already
  /// stored; [overlappingDays] are the days the two have in common, as 1
  /// (Monday) .. 7 (Sunday).
  const DuplicateScheduleFailure({
    required this.existingScheduleId,
    required this.timeOfDay,
    required this.overlappingDays,
  });

  /// The id of the Schedule that is already there.
  final String existingScheduleId;

  /// The wall-clock time both Schedules hold, as `HH:mm`.
  final String timeOfDay;

  /// The days of the week the two have in common, ascending.
  final Set<int> overlappingDays;

  /// The three-letter day names, indexed by `DateTime.monday`..`sunday`.
  ///
  /// Index 0 is unused so that `dayNames[DateTime.monday]` is Monday; a
  /// zero-based list would make every lookup an off-by-one waiting to happen.
  static const List<String> dayNames = <String>[
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// The sentence used when the overlap is the whole week.
  ///
  /// Public so a test asserts the copy the user will actually read rather than
  /// a second copy of it written next to the assertion.
  static const String everyDayPhrase = 'every day';

  /// The message names the clash: the time, and the days it falls on.
  ///
  /// Not "invalid input" and not "duplicate schedule". The user set a time and
  /// a set of days; the sentence says which of them already exists, so the
  /// change to make is obvious without opening the list again.
  ///
  /// A full week collapses to "every day" rather than listing all seven names.
  /// Two `everyDay` schedules are the commonest clash there is, and
  /// "already has a dose at 08:00 on Mon, Tue, Wed, Thu, Fri, Sat, Sun" reads
  /// as a system dump of an internal day set -- and it is one, since
  /// `Schedule.occupiedDaysOfWeek` over-claims the week for an interval
  /// schedule on purpose. Stating the fact plainly is the product's voice.
  @override
  String get message {
    final List<int> days = overlappingDays.toList()..sort();
    final String named = days.length == 7
        ? everyDayPhrase
        : days.map((int day) => dayNames[day]).join(', ');
    return 'This medicine already has a dose at $timeOfDay on $named.';
  }
}

/// A Schedule's frequency and its companion fields do not agree.
///
/// The pairing is the domain's rule rather than the schema's -- see
/// `Schedule.pairingViolation`, whose message this carries.
final class ScheduleNotValidFailure extends MedicineRepositoryFailure {
  const ScheduleNotValidFailure(this.message);

  @override
  final String message;
}

/// A Medicine is missing something FR-1 or FR-2 requires.
///
/// Carries `Medicine.violation`'s message, which is written to be shown as it
/// stands.
final class MedicineNotValidFailure extends MedicineRepositoryFailure {
  const MedicineNotValidFailure(this.message);

  @override
  final String message;
}

/// No Medicine with the given id is stored.
final class MedicineNotFoundFailure extends MedicineRepositoryFailure {
  const MedicineNotFoundFailure(this.medicineId);

  /// The id that was not found.
  final String medicineId;

  @override
  String get message => 'That medicine is no longer in your list.';
}

/// No Schedule with the given id is stored on the Medicine it names.
final class ScheduleNotFoundFailure extends MedicineRepositoryFailure {
  const ScheduleNotFoundFailure(this.scheduleId);

  /// The id that was not found.
  final String scheduleId;

  @override
  String get message => 'That dose time is no longer on this medicine.';
}

/// A stored row could not be read back as a Medicine or a Schedule.
///
/// The spine's Errors convention: adapters translate platform exceptions into
/// typed domain failures at the boundary, and nothing is swallowed. Without
/// this, a row holding `'99:99'` or a frequency name this build does not know
/// reaches a caller as a bare `ArgumentError`, `FormatException` or
/// `StateError` -- exception types the port never documented, from a layer the
/// caller is not supposed to know exists.
///
/// It is a genuinely exceptional case: every write path validates, and the
/// schema's own `CHECK` constraints reject most shapes. What is left is a row
/// written by a raw statement, a file touched outside the app, or a row from a
/// newer build that knows a frequency this one does not -- which is why the
/// message is about the record rather than about the field.
final class MedicineRecordNotReadableFailure extends MedicineRepositoryFailure {
  const MedicineRecordNotReadableFailure({
    required this.detail,
    required this.cause,
  });

  /// What could not be read, in engineering terms, for the local log.
  final String detail;

  /// The exception the read actually threw, kept so the log has the original.
  final Object cause;

  @override
  String get message =>
      'Part of this medicine\'s record could not be read. Nothing has been '
      'changed.';

  @override
  String toString() => 'MedicineRecordNotReadableFailure: $detail ($cause)';
}
