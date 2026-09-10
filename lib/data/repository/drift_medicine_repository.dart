// The Drift adapter behind `MedicineRepository`.
//
// Named for the technology, as the spine's naming rule asks: the port is
// `MedicineRepository`, the adapter is `DriftMedicineRepository`. This is the
// only code that knows a Medicine is a row and a Schedule is a foreign key,
// and -- AD-12 -- it is the only write path to either. No DAO is exposed past
// this class: a second writer would need its own copy of the glyph rule, the
// duplicate-schedule rule and the delete cascade, and one of the two copies
// would be the one that is wrong.
//
// `deleteMedicine` also deletes matching rows from `doses` directly, rather
// than through `DriftDoseRepository` -- AD-12's "in one transaction" promise
// (FR-3) needs one transaction spanning all three tables, and Dose's own
// aggregate boundary (AD-12) is about the DOMAIN reaching doses only through
// `DoseRepository`, not about which adapter may hold the connection. This is
// the one sanctioned place that reaches past it; `DriftDoseRepository` itself
// still owns every other write to `doses`.
//
// This file is also the translation boundary the spine's Errors convention
// names. Nothing that is not a `MedicineRepositoryFailure` leaves it: a row
// SQLite hands back in a shape the domain refuses -- a malformed date, a
// frequency name this build does not know, a `time_of_day` a raw statement
// wrote -- becomes a `MedicineRecordNotReadableFailure` here rather than
// travelling to a widget as a `FormatException`.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/model/frequency.dart';
import '../../domain/model/medicine.dart';
import '../../domain/model/schedule.dart';
import '../../domain/policy/glyph_policy.dart';
import '../../domain/port/medicine_repository.dart';
import '../db/app_database.dart';

/// Stores Medicines and the Schedules they own in [AppDatabase].
final class DriftMedicineRepository implements MedicineRepository {
  /// Wraps [database]. The instance is owned by the composition root (AD-3);
  /// this adapter neither opens nor closes it.
  ///
  /// [newId] mints the UUID v4 identities. It is injectable so a test can
  /// assert on a known id without matching a random one, and defaults to
  /// `package:uuid`'s v4 -- the spine's Identifiers convention.
  DriftMedicineRepository(this._database, {String Function()? newId})
    : _newId = newId ?? _uuidV4;

  final AppDatabase _database;
  final String Function() _newId;

  static const Uuid _uuid = Uuid();
  static String _uuidV4() => _uuid.v4();

  /// SQLite's implicit row counter, used as insertion order.
  ///
  /// `medicines` has no created-at column -- the spine's ERD does not give it
  /// one -- and the glyph sequence AD-22 assigns is an insertion-order
  /// sequence, so the order rows come back in has to be insertion order or the
  /// 0,1,2,3 pattern is unobservable from outside the repository. `rowid` is
  /// exactly that and is stable: the table is not `WITHOUT ROWID`, and SQLite
  /// never renumbers an existing row. Relying on the *default* order of a
  /// `SELECT` with no `ORDER BY` would be relying on the same thing without
  /// saying so, and SQLite does not promise it.
  static const CustomExpression<int> _insertionOrder = CustomExpression<int>(
    'rowid',
  );

  @override
  Future<List<Medicine>> allMedicines() async {
    final List<MedicineRow> rows =
        await (_database.select(_database.medicines)
              ..orderBy(<OrderClauseGenerator<$MedicinesTable>>[
                ($MedicinesTable t) =>
                    OrderingTerm(expression: _insertionOrder),
              ]))
            .get();
    return rows.map(_medicineFromRow).toList();
  }

  @override
  Future<Medicine?> findMedicine(String id) async {
    final MedicineRow? row = await (_database.select(
      _database.medicines,
    )..where(($MedicinesTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _medicineFromRow(row);
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
  }) {
    // The count and the insert are in ONE transaction. AD-22 assigns the glyph
    // from `count(existing medicines)`, and a count read outside the
    // transaction that then inserts is a read-modify-write: two medicines added
    // in the same moment would both read the same count and be handed the same
    // glyph, which is precisely the "consecutive additions differ" half of the
    // decision.
    return _database.transaction<Medicine>(() async {
      final int existing = await _database.medicines.count().getSingle();

      final Medicine medicine = Medicine(
        id: _newId(),
        name: name,
        condition: condition,
        glyphIndex: glyphIndexForNewMedicine(existing),
        form: form,
        dosageAmount: dosageAmount,
        dosageUnit: dosageUnit,
        instructions: instructions,
        startDate: startDate,
        endDate: endDate,
        active: active,
      );
      _requireValid(medicine);

      await _database
          .into(_database.medicines)
          .insert(_medicineToRow(medicine));
      return medicine;
    });
  }

  @override
  Future<void> saveMedicine(Medicine medicine) async {
    _requireValid(medicine);

    // `replace` writes every column of the row with the matching primary key
    // and reports whether it found one. It cannot insert, which is what makes
    // it right here: an update that fell back to an insert would resurrect a
    // medicine the user deleted on another surface.
    //
    // Writing the whole row is correct for a Medicine and would be wrong for
    // `app_settings` -- see `DriftOnboardingStateStore.markOnboardingComplete`
    // for why. The difference is that a Medicine object carries every column
    // it has, including its glyph, so there is nothing for a full-row write to
    // reset to a default.
    final bool found = await _database
        .update(_database.medicines)
        .replace(_medicineToRow(medicine));
    if (!found) {
      throw MedicineNotFoundFailure(medicine.id);
    }
  }

  @override
  Future<void> deleteMedicine(String id) {
    // One transaction, all three deletes (AD-12) -- FR-3's full promise as of
    // Story 1.7a: "deleting a Medicine cascades to its Schedules and its Doses
    // in one transaction." `schedules.medicine_id` and `doses.medicine_id` both
    // also declare ON DELETE CASCADE, so the database would remove every row
    // anyway -- that is the guarantee for any future path, including a raw
    // statement. The explicit deletes are here because AD-12's promise is "in
    // one transaction", and a promise that only a pragma keeps is a promise
    // that silently stops being kept the day the pragma is not set. All three
    // either happen or none does; a failure part-way can never leave a
    // Medicine without its Schedules or Doses, Schedules without their
    // Medicine, or a Dose outliving either the Schedule that generated it or
    // the Medicine it belongs to.
    //
    // Doses first, then Schedules, then the Medicine: with `PRAGMA
    // foreign_keys` on, deleting a parent while a child still references it is
    // rejected by the foreign key. A Dose's `medicine_id` is denormalised
    // (AD-20) so it names the SAME Medicine as the Schedule that generated it
    // -- filtering on `medicine_id` here removes every Dose of every Schedule
    // this Medicine owns in one statement, so Doses are safely gone before
    // Schedules are touched, regardless of whether `doses.schedule_id`'s own
    // cascade would also have caught them.
    return _database.transaction<void>(() async {
      await (_database.delete(
        _database.doses,
      )..where(($DosesTable t) => t.medicineId.equals(id))).go();
      await (_database.delete(
        _database.schedules,
      )..where(($SchedulesTable t) => t.medicineId.equals(id))).go();
      await (_database.delete(
        _database.medicines,
      )..where(($MedicinesTable t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<List<Schedule>> schedulesFor(String medicineId) async {
    final List<ScheduleRow> rows =
        await (_database.select(_database.schedules)
              ..where(($SchedulesTable t) => t.medicineId.equals(medicineId))
              ..orderBy(<OrderClauseGenerator<$SchedulesTable>>[
                ($SchedulesTable t) => OrderingTerm(expression: t.timeOfDay),
                // A second term so two Schedules at the same time on disjoint
                // days come back in a stable order rather than whichever the
                // query planner chose this run.
                ($SchedulesTable t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return rows.map(_scheduleFromRow).toList();
  }

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
  }) {
    final Schedule candidate = Schedule(
      id: _newId(),
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      ianaTimezone: ianaTimezone,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
      intervalDays: intervalDays,
      dosageAmount: dosageAmount,
      reminderOverride: reminderOverride,
    );

    // ONE transaction around the check and the insert. The clash test reads the
    // Medicine's other Schedules and then writes; run outside a transaction,
    // two saves of the same time could both read a clash-free list and both
    // insert, which is the "two reminders for the same medicine at the same
    // minute" failure FR-4 exists to prevent -- and it would be invisible
    // afterwards, because the rule would have been satisfied at the moment each
    // one checked.
    return _database.transaction<Schedule>(() async {
      await _requireMedicine(medicineId);
      await _requireNoClash(candidate);
      await _database
          .into(_database.schedules)
          .insert(_scheduleToRow(candidate));
      return candidate;
    });
  }

  @override
  Future<void> saveSchedule(Schedule schedule) {
    // One transaction, for the same reason as `addSchedule`: an edit that moves
    // a Schedule onto a time another one already holds must not be able to slip
    // between a rival's check and its write.
    return _database.transaction<void>(() async {
      await _requireOwnedBy(schedule);
      await _requireMedicine(schedule.medicineId);
      await _requireNoClash(schedule);
      final bool found = await _database
          .update(_database.schedules)
          .replace(_scheduleToRow(schedule));
      if (!found) {
        throw ScheduleNotFoundFailure(schedule.id);
      }
    });
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await (_database.delete(
      _database.schedules,
    )..where(($SchedulesTable t) => t.id.equals(id))).go();
  }

  /// Throws [MedicineNotValidFailure] if [medicine] may not be stored.
  ///
  /// One place, so `addMedicine` and `saveMedicine` cannot disagree about what
  /// FR-1 requires. The rule itself is the domain's -- `Medicine.violation` --
  /// and this only turns its sentence into the port's typed failure.
  void _requireValid(Medicine medicine) {
    final String? violation = medicine.violation();
    if (violation != null) {
      throw MedicineNotValidFailure(violation);
    }
  }

  /// Throws [ScheduleNotFoundFailure] unless the stored row for [schedule]'s id
  /// belongs to the Medicine [schedule] names.
  ///
  /// A Schedule has no independent lifecycle (AD-12) and cannot change parents.
  /// `Schedule.copyWith` offers no way to, but `saveSchedule` accepts any
  /// hand-constructed Schedule and `replace` matches on the primary key alone,
  /// so without this a caller could rewrite `medicine_id` and move the row.
  /// That is worse than it looks: the clash check below would then run against
  /// the NEW parent only, so a duplicate could be left standing on the old one,
  /// and the Medicine the user was editing would silently lose a dose time.
  ///
  /// Reported as "not found" rather than as its own failure because that is
  /// what it is from the caller's side: this Medicine has no Schedule with that
  /// id. A missing row and a row belonging to someone else are the same answer.
  Future<void> _requireOwnedBy(Schedule schedule) async {
    final ScheduleRow? stored =
        await (_database.select(_database.schedules)
              ..where(($SchedulesTable t) => t.id.equals(schedule.id)))
            .getSingleOrNull();
    if (stored != null && stored.medicineId != schedule.medicineId) {
      throw ScheduleNotFoundFailure(schedule.id);
    }
  }

  /// Throws [MedicineNotFoundFailure] unless [medicineId] names a stored
  /// Medicine.
  ///
  /// The foreign key would reject the insert regardless, with a
  /// `SqliteException` naming a constraint. This turns that into the typed
  /// failure the port documents, at the boundary, which is the spine's Errors
  /// convention: adapters translate platform exceptions into domain failures
  /// rather than letting them travel.
  Future<void> _requireMedicine(String medicineId) async {
    final int matches = await _database.medicines
        .count(where: ($MedicinesTable t) => t.id.equals(medicineId))
        .getSingle();
    if (matches == 0) {
      throw MedicineNotFoundFailure(medicineId);
    }
  }

  /// Throws [ScheduleNotValidFailure] or [DuplicateScheduleFailure] if
  /// [candidate] may not be stored.
  ///
  /// The clash test reads every Schedule of the same Medicine and asks the
  /// domain -- `Schedule.clashesWith` -- rather than expressing the rule as a
  /// `WHERE`. Overlap is a set intersection over a frequency-dependent day set,
  /// which SQL would have to re-derive from `frequency`, `days_of_week` and
  /// `interval_days`; the second implementation would be the one that is wrong.
  /// A Medicine has a handful of Schedules, so reading them costs nothing.
  Future<void> _requireNoClash(Schedule candidate) async {
    final String? violation = candidate.pairingViolation();
    if (violation != null) {
      throw ScheduleNotValidFailure(violation);
    }

    final List<Schedule> siblings = await schedulesFor(candidate.medicineId);
    for (final Schedule sibling in siblings) {
      if (candidate.clashesWith(sibling)) {
        throw DuplicateScheduleFailure(
          existingScheduleId: sibling.id,
          timeOfDay: sibling.timeOfDay,
          overlappingDays: candidate.occupiedDaysOfWeek.intersection(
            sibling.occupiedDaysOfWeek,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping. Every conversion between a row and a domain object goes through
  // exactly one of the four functions below, so the storage format is stated
  // once. AD-6 lives here in the negative: there is no instant to convert.
  //
  // The two READ functions are the translation boundary. The domain models
  // refuse a malformed value by throwing -- `ArgumentError` from a `Schedule`
  // whose `time_of_day` is not a wall clock, `FormatException` from a date
  // whose digits are not digits, `StateError` from a frequency name this build
  // does not know -- and none of those types is in the port's contract, so each
  // read wraps them into `MedicineRecordNotReadableFailure`. A
  // `MedicineRepositoryFailure` raised deliberately inside the block (the
  // pairing check) is rethrown untouched: it is already the port's own answer.

  Medicine _medicineFromRow(MedicineRow row) => _readRecord(
    'medicine ${row.id}',
    () => Medicine(
      id: row.id,
      name: row.name,
      condition: row.condition,
      glyphIndex: row.glyphIndex,
      form: row.form,
      dosageAmount: row.dosageAmount,
      dosageUnit: row.dosageUnit,
      instructions: row.instructions,
      startDate: parseIsoDate(row.startDate),
      endDate: row.endDate == null ? null : parseIsoDate(row.endDate!),
      active: row.active,
    ),
  );

  MedicinesCompanion _medicineToRow(Medicine medicine) => MedicinesCompanion(
    id: Value<String>(medicine.id),
    name: Value<String>(medicine.name),
    condition: Value<String?>(medicine.condition),
    glyphIndex: Value<int>(medicine.glyphIndex),
    form: Value<String>(medicine.form),
    dosageAmount: Value<double>(medicine.dosageAmount),
    dosageUnit: Value<String>(medicine.dosageUnit),
    instructions: Value<String?>(medicine.instructions),
    startDate: Value<String>(formatIsoDate(medicine.startDate)),
    endDate: Value<String?>(
      medicine.endDate == null ? null : formatIsoDate(medicine.endDate!),
    ),
    active: Value<bool>(medicine.active),
  );

  Schedule _scheduleFromRow(ScheduleRow row) => _readRecord(
    'schedule ${row.id}',
    () {
      final Schedule schedule = Schedule(
        id: row.id,
        medicineId: row.medicineId,
        timeOfDay: row.timeOfDay,
        ianaTimezone: row.ianaTimezone,
        frequency: parseFrequency(row.frequency),
        daysOfWeek: parseDaysOfWeek(row.daysOfWeek),
        intervalDays: row.intervalDays,
        dosageAmount: row.dosageAmount,
        reminderOverride: row.reminderOverride,
      );

      // The frequency/companion pairing is checked on the way OUT as well as
      // on the way in. The columns are independently nullable -- three of the
      // four frequencies leave each one empty -- so no `CHECK` can express the
      // rule, and an `everyNDays` row with a null interval would otherwise
      // reach a caller that has no legal way to interpret it. Dose generation
      // would then either skip it silently or throw somewhere far from the row
      // that caused it.
      final String? violation = schedule.pairingViolation();
      if (violation != null) {
        throw MedicineRecordNotReadableFailure(
          detail:
              'schedule ${row.id} stores frequency '
              '"${row.frequency}" with days_of_week=${row.daysOfWeek} and '
              'interval_days=${row.intervalDays}',
          cause: StateError(violation),
        );
      }
      return schedule;
    },
  );

  SchedulesCompanion _scheduleToRow(Schedule schedule) => SchedulesCompanion(
    id: Value<String>(schedule.id),
    medicineId: Value<String>(schedule.medicineId),
    timeOfDay: Value<String>(schedule.timeOfDay),
    ianaTimezone: Value<String>(schedule.ianaTimezone),
    frequency: Value<String>(schedule.frequency.name),
    daysOfWeek: Value<String?>(formatDaysOfWeek(schedule.daysOfWeek)),
    intervalDays: Value<int?>(schedule.intervalDays),
    dosageAmount: Value<double>(schedule.dosageAmount),
    reminderOverride: Value<String?>(schedule.reminderOverride),
  );

  /// Runs [read] and turns anything it throws into a typed failure.
  ///
  /// [what] names the row for the local log (`dart:developer`, per the spine's
  /// logging convention) -- never for the user, whose message says the record
  /// could not be read and that nothing was changed.
  ///
  /// A `MedicineRepositoryFailure` passes through unchanged: it was raised on
  /// purpose and already is the port's answer. Everything else is wrapped,
  /// including `Error` subtypes -- an `ArgumentError` from a domain constructor
  /// is a fact about the stored row here, not a bug in the caller, and letting
  /// it escape would break the port's promise that only its own failures leave.
  static T _readRecord<T>(String what, T Function() read) {
    try {
      return read();
    } on MedicineRepositoryFailure {
      rethrow;
    } catch (cause) {
      throw MedicineRecordNotReadableFailure(detail: what, cause: cause);
    }
  }

  /// [value] as a calendar date, rejecting anything that is not one.
  ///
  /// Range-checked rather than handed straight to `DateTime`, because
  /// `DateTime(2026, 13, 45)` does not throw -- Dart rolls it over to
  /// 2027-02-14. A start date silently moved five months is exactly the class
  /// of bug that has no symptom until doses stop being generated, so the
  /// rollover is refused here and the schema's `GLOB` refuses most of it a
  /// layer earlier.
  ///
  /// Throws [FormatException]; the callers above translate it.
  static DateTime parseIsoDate(String value) {
    if (value.length != 10 || value[4] != '-' || value[7] != '-') {
      throw FormatException('not a YYYY-MM-DD calendar date', value);
    }
    final int year = int.parse(value.substring(0, 4));
    final int month = int.parse(value.substring(5, 7));
    final int day = int.parse(value.substring(8, 10));
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw FormatException('month or day out of range', value);
    }
    final DateTime date = DateTime(year, month, day);
    // Catches 31 February, which passes the range check above: Dart rolls it
    // into March, so the parsed date no longer matches what was stored.
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('no such calendar date', value);
    }
    return date;
  }

  /// [date] as `YYYY-MM-DD`, in the zone [date] is already in.
  ///
  /// Not `toIso8601String()` and not `toUtc()`: a calendar date has no instant
  /// to convert, and converting one would move a medicine started today to
  /// yesterday for every user east of UTC. Public so the schema test can assert
  /// the stored text against the same formatter the adapter writes with.
  static String formatIsoDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  /// [days] as ascending comma-separated `1`..`7`, or null when [days] is null.
  ///
  /// Sorted so that the same day set always produces the same text, and an
  /// empty set becomes null rather than an empty string: "no day set" and "an
  /// empty day set" are different, and only the first is legal.
  static String? formatDaysOfWeek(Set<int>? days) {
    if (days == null || days.isEmpty) return null;
    final List<int> sorted = days.toList()..sort();
    return sorted.join(',');
  }

  /// The inverse of [formatDaysOfWeek].
  ///
  /// Throws [FormatException] on anything that is not a comma-separated list of
  /// integers -- `'1,,5'`, `'mon'`, a trailing comma. `Schedule`'s own
  /// constructor rejects a day outside 1..7, so this only has to get the shape
  /// right. Both throws are translated by the caller.
  static Set<int>? parseDaysOfWeek(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    return stored.split(',').map(int.parse).toSet();
  }

  /// The [Frequency] whose `name` is [stored].
  ///
  /// Throws [StateError] on anything else, and the caller translates it into
  /// [MedicineRecordNotReadableFailure]. Loudly, and not a silent fallback to
  /// `everyDay`: a row whose frequency this build cannot read is a row that
  /// would generate the wrong doses, and quietly treating it as daily would
  /// produce reminders the user never asked for.
  static Frequency parseFrequency(String stored) => Frequency.values.firstWhere(
    (Frequency value) => value.name == stored,
    orElse: () => throw StateError(
      'Unknown Frequency "$stored" in the schedules table. Known values: '
      '${Frequency.values.map((Frequency f) => f.name).join(', ')}.',
    ),
  );
}
