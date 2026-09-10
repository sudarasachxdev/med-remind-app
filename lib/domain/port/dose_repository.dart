// The one path to a Dose (AD-12).
//
// AD-1: pure Dart. This file imports the sibling `Dose` model and the shared
// `DomainFailure` root, nothing else. `test/architecture_test.dart` fails the
// build if a `package:` import other than `package:meta/` (or `package:
// timezone/`, which this file needs neither of) appears anywhere under
// `lib/domain/`.
//
// AD-12: `Dose` is its own aggregate, not owned by `Medicine` the way
// `Schedule` is -- this port references a Medicine and a Schedule by id only,
// never by join. No DAO is exposed past the adapter that implements this,
// deliberately, for the same reason `MedicineRepository` gives: a second write
// path would put the natural-key discipline in two places, and one of the two
// copies would be the one that is wrong.
//
// Named for the role, not the technology (the spine's naming rule): the port
// is `DoseRepository`, the Drift adapter is `DriftDoseRepository`.
//
// STORY 1.7A ENDS AT THIS PORT, exactly as Story 1.4 ended at
// `MedicineRepository`. Nothing under `lib/features/` or `lib/app/` names
// either this type or its adapter -- Story 1.7b's `DoseGenerator` is the first
// caller. `test/story_scope_test.dart` guards the composition root against an
// early binding.

import '../model/dose.dart';
import '../model/domain_failure.dart';

/// Reads and writes generated Doses.
///
/// **What a failure does.** Every method on this port either completes the
/// write (or read) or throws. None of them returns a success flag, swallows an
/// exception or reports a partial result, per the spine's Errors convention
/// and PRD §9: a write this port did not actually make is never reported as
/// having happened. Specifically:
///
///   * every failure is a [DoseRepositoryFailure], and no other exception type
///     escapes: the adapter translates a malformed stored row into
///     [DoseRecordNotReadableFailure] at the boundary,
///   * [saveDose] throws [DuplicateDoseFailure] when writing would duplicate
///     the `(scheduleId, scheduledLocal)` natural key (AD-10) under an id
///     other than the row already stored there. Nothing is written.
///
/// A read of something absent is not a failure: [findDose] answers `null` and
/// [dosesForSchedule] answers an empty list.
///
/// **What this port deliberately does not have.** No query by Medicine, no
/// bulk upsert -- Story 1.7b, this port's first caller, needed exactly the
/// four methods below with no range query. Story 1.8 is the first caller that
/// needs "every Dose across every Schedule, in a window" -- Home's daily plan
/// -- and [dosesScheduledBetween] is that query, added only once a caller
/// existed to need it, the same discipline `MedicineRepository` was held to
/// through Story 1.4.
///
/// **What this port never does.** [saveDose] writes whatever [Dose] it is
/// given, including `takenAt`, `skippedAt`, `snoozedUntil` and `snoozeCount` --
/// but AD-4 restricts which *service* may orchestrate those specific writes
/// (plus the notification cancellation in the same unit of work) to
/// `DoseRecorder`, which does not exist until Epic 2. This port having a save
/// method is not that restriction lifted; it is the storage half AD-4 assumes
/// already exists.
abstract interface class DoseRepository {
  /// Every Dose generated from the Schedule with [scheduleId].
  ///
  /// Empty when the Schedule has none. Order is not part of this port's
  /// contract -- Story 1.8's ordering need belongs with the range query it
  /// will add, not with this method's shape today.
  Future<List<Dose>> dosesForSchedule(String scheduleId);

  /// Writes [dose] over any stored row of the same id, or inserts one if none
  /// exists -- an upsert, never a plain insert (AD-10: generation is
  /// idempotent, and this is the method it upserts through).
  ///
  /// [Dose.id] is deterministic and supplied by [dose] itself; this port
  /// mints no identity of its own, unlike `MedicineRepository.addMedicine`.
  ///
  /// Throws [DuplicateDoseFailure] when [dose]'s `(scheduleId, scheduledLocal)`
  /// natural key is already stored under a different id. This is the one case
  /// [Dose.id]'s own derivation cannot prevent by construction -- two Dose
  /// objects built from the same pair always compute the same id -- so the
  /// database's unique index is what refuses it, not a check reading sibling
  /// rows the way `MedicineRepository.addSchedule` reads Schedules; a Dose has
  /// no siblings to read (AD-12).
  Future<void> saveDose(Dose dose);

  /// The Dose with [id], or `null` when there is none.
  Future<Dose?> findDose(String id);

  /// Deletes the Dose with [id]. Idempotent: deleting an id that is not
  /// stored is not an error, matching `MedicineRepository.deleteSchedule`.
  Future<void> deleteDose(String id);

  /// Every Dose whose [Dose.scheduledAt] falls in `[start, end)`, across every
  /// Schedule and every Medicine, ascending by [Dose.scheduledAt].
  ///
  /// Half-open on purpose: [start] is inclusive and [end] is exclusive, so a
  /// caller asking for one calendar day after another -- as Home's controller
  /// does, today then tomorrow -- can never double-count a Dose landing
  /// exactly on the shared boundary, and never leaves a one-instant gap
  /// between the two calls either.
  ///
  /// Unlike [dosesForSchedule], order **is** part of this method's contract:
  /// Home's daily plan is fixed-order by scheduled time (UX-DR23), and this is
  /// the query that exists to answer it -- the range query
  /// `dose_repository.dart`'s own doc long named as Story 1.8's to add, now
  /// that Story 1.8 is the caller that needs it.
  ///
  /// Empty when nothing is scheduled in the window. Throws
  /// [DoseRecordNotReadableFailure] under the same conditions [dosesForSchedule]
  /// would.
  Future<List<Dose>> dosesScheduledBetween(DateTime start, DateTime end);
}

/// The base type of every failure [DoseRepository] throws.
///
/// Sealed for the same reason `MedicineRepositoryFailure` is: a caller that
/// switches over it is told by the compiler when a new case arrives, and it
/// sits under [DomainFailure] so a feature can catch every port's failures
/// with `on DomainFailure` if it genuinely needs to.
sealed class DoseRepositoryFailure extends DomainFailure {
  const DoseRepositoryFailure();
}

/// Saving a Dose would duplicate the `(scheduleId, scheduledLocal)` unique
/// index (AD-10) under an id different from the row already stored there.
///
/// Reachable only when some write other than this Dose's own derivation
/// already put a row on this natural key -- a raw statement, a row from a
/// build whose id formula differed, or a future bug. Ordinary regeneration
/// through [DoseRepository.saveDose] cannot reach this on its own: two Dose
/// objects sharing a natural key always compute the same [Dose.id], so that
/// path is the plain upsert row of the spec's I/O matrix, not this one.
final class DuplicateDoseFailure extends DoseRepositoryFailure {
  /// [scheduleId] and [scheduledLocal] name the natural key that collided.
  const DuplicateDoseFailure({
    required this.scheduleId,
    required this.scheduledLocal,
  });

  /// The `Schedule.id` both the stored row and the rejected write share.
  final String scheduleId;

  /// The wall-clock time both the stored row and the rejected write share.
  final DateTime scheduledLocal;

  @override
  String get message =>
      'A dose already exists for this schedule at this time. Nothing has '
      'been changed.';
}

/// A stored row could not be read back as a Dose.
///
/// The spine's Errors convention, mirroring
/// `MedicineRecordNotReadableFailure`: adapters translate platform exceptions
/// into typed domain failures at the boundary, and nothing is swallowed.
/// Genuinely exceptional -- every write path validates and the schema's own
/// constraints reject most malformed shapes -- so the message is about the
/// record rather than about a field.
final class DoseRecordNotReadableFailure extends DoseRepositoryFailure {
  const DoseRecordNotReadableFailure({
    required this.detail,
    required this.cause,
  });

  /// What could not be read, in engineering terms, for the local log.
  final String detail;

  /// The exception the read actually threw, kept so the log has the original.
  final Object cause;

  @override
  String get message =>
      'Part of this dose\'s record could not be read. Nothing has been '
      'changed.';

  @override
  String toString() => 'DoseRecordNotReadableFailure: $detail ($cause)';
}
