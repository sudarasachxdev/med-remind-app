// The Drift adapter behind `DoseRepository`.
//
// Named for the technology, as the spine's naming rule asks: the port is
// `DoseRepository`, the adapter is `DriftDoseRepository`. This is the only
// code that knows a Dose is a row (AD-12) -- it never joins to `medicines` or
// `schedules`, exactly as the port's own doc-comment promises, because a Dose
// carries its own frozen snapshot (AD-11) and its own denormalised
// `medicineId` (AD-20) precisely so that no join is ever needed to answer a
// question about it.
//
// This file is also the translation boundary the spine's Errors convention
// names: nothing that is not a `DoseRepositoryFailure` leaves it.

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../domain/model/dose.dart';
import '../../domain/port/dose_repository.dart';
import '../db/app_database.dart';

/// Stores generated Doses in [AppDatabase].
final class DriftDoseRepository implements DoseRepository {
  /// Wraps [database]. The instance is owned by the composition root (AD-3);
  /// this adapter neither opens nor closes it.
  ///
  /// Unlike `DriftMedicineRepository`, this adapter mints no identity: `Dose.id`
  /// is already deterministic (Story 1.6), so there is no `newId` to inject.
  DriftDoseRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Dose>> dosesForSchedule(String scheduleId) async {
    final List<DoseRow> rows = await (_database.select(
      _database.doses,
    )..where(($DosesTable t) => t.scheduleId.equals(scheduleId))).get();
    return rows.map(_doseFromRow).toList();
  }

  @override
  Future<Dose?> findDose(String id) async {
    final DoseRow? row = await (_database.select(
      _database.doses,
    )..where(($DosesTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _doseFromRow(row);
  }

  @override
  Future<void> saveDose(Dose dose) async {
    // `insertOnConflictUpdate` targets the PRIMARY KEY by default (drift's own
    // documented default for `DoUpdate` with no explicit `target`) -- exactly
    // `id`, and nothing else. That is what makes this an upsert on [Dose.id]
    // (the spec's "Save the same Dose again" row) while leaving the OTHER
    // unique constraint -- `(schedule_id, scheduled_local)`, AD-10's natural
    // key -- untouched by the conflict clause: a write that collides there
    // instead is not the target this statement names, so SQLite raises its
    // own UNIQUE-constraint error rather than silently overwriting a row
    // this Dose does not own. That is "the unique index is the truth, not
    // the id string": the very same statement upserts on one column and
    // refuses on the other, because only one of them is named as the target.
    try {
      await _database
          .into(_database.doses)
          .insertOnConflictUpdate(_doseToRow(dose));
    } on SqliteException catch (cause) {
      if (cause.message.contains('UNIQUE constraint failed')) {
        throw DuplicateDoseFailure(
          scheduleId: dose.scheduleId,
          scheduledLocal: dose.scheduledLocal,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteDose(String id) async {
    await (_database.delete(
      _database.doses,
    )..where(($DosesTable t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Mapping. Every conversion between a row and a `Dose` goes through exactly
  // one of the two functions below, mirroring `DriftMedicineRepository`'s own
  // `_medicineFromRow`/`_medicineToRow` pair.

  Dose _doseFromRow(DoseRow row) => _readRecord(
    'dose ${row.id}',
    () => Dose(
      scheduleId: row.scheduleId,
      medicineId: row.medicineId,
      scheduledLocal: DateTime.parse(row.scheduledLocal),
      ianaTimezone: row.ianaTimezone,
      takenAt: row.takenAt == null ? null : DateTime.parse(row.takenAt!),
      skippedAt: row.skippedAt == null ? null : DateTime.parse(row.skippedAt!),
      snoozedUntil: row.snoozedUntil == null
          ? null
          : DateTime.parse(row.snoozedUntil!),
      snoozeCount: row.snoozeCount,
      escalationWindowMinutes: row.escalationWindowMinutes,
      followUpOffsetsMinutes: _parseOffsets(row.followUpOffsetsMinutes),
      medicineName: row.medicineName,
      dosageAmount: row.dosageAmount,
      dosageUnit: row.dosageUnit,
      form: row.form,
    ),
  );

  DosesCompanion _doseToRow(Dose dose) => DosesCompanion(
    id: Value<String>(dose.id),
    scheduleId: Value<String>(dose.scheduleId),
    medicineId: Value<String>(dose.medicineId),
    // Wall-clock text, with no zone of its own (AD-6) -- the stored truth.
    scheduledLocal: Value<String>(dose.scheduledLocal.toIso8601String()),
    ianaTimezone: Value<String>(dose.ianaTimezone),
    // `.toUtc()` first: `scheduledAt` is a `TZDateTime` in the Dose's own
    // zone, and this column exists purely as a UTC ordering value (AD-6). A
    // zone-local ISO string would carry no zone marker at all -- Dart only
    // appends one for a UTC-flavoured DateTime -- so two Doses in different
    // zones would not sort correctly against it.
    scheduledUtc: Value<String>(dose.scheduledAt.toUtc().toIso8601String()),
    takenAt: Value<String?>(dose.takenAt?.toUtc().toIso8601String()),
    skippedAt: Value<String?>(dose.skippedAt?.toUtc().toIso8601String()),
    snoozedUntil: Value<String?>(dose.snoozedUntil?.toUtc().toIso8601String()),
    snoozeCount: Value<int>(dose.snoozeCount),
    medicineName: Value<String>(dose.medicineName),
    dosageAmount: Value<double>(dose.dosageAmount),
    dosageUnit: Value<String>(dose.dosageUnit),
    form: Value<String>(dose.form),
    escalationWindowMinutes: Value<int>(dose.escalationWindowMinutes),
    followUpOffsetsMinutes: Value<String>(
      dose.followUpOffsetsMinutes.join(','),
    ),
  );

  /// The inverse of the `.join(',')` above. Order-preserving, unlike
  /// `DriftMedicineRepository.parseDaysOfWeek`: these are chain offsets, not a
  /// set, so sorting them would silently reorder the escalation chain.
  static List<int> _parseOffsets(String stored) =>
      stored.isEmpty ? <int>[] : stored.split(',').map(int.parse).toList();

  /// Runs [read] and turns anything it throws into a typed failure. See
  /// `DriftMedicineRepository._readRecord` for the fuller reasoning; the same
  /// one applies here.
  static T _readRecord<T>(String what, T Function() read) {
    try {
      return read();
    } on DoseRepositoryFailure {
      rethrow;
    } catch (cause) {
      throw DoseRecordNotReadableFailure(detail: what, cause: cause);
    }
  }
}
