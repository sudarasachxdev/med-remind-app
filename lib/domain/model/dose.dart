// One occurrence of a Schedule, generated ahead of time: the facts `resolve()`
// derives a state from, and nothing else (AD-2).
//
// AD-1, as amended 2026-09-09: pure Dart, `package:meta/` and
// `package:timezone/` only. `package:timezone/timezone.dart` imports only
// `dart:collection` and `dart:typed_data`; `package:timezone/standalone.dart`,
// which pulls in `dart:io`, is never imported here. See
// `logical_day_policy.dart` for the fuller note.
//
// NO STATUS FIELD. That is this story's keystone constraint, not a detail:
// `doses` is Story 1.7's table, and a `status` column here would be the exact
// mistake AD-2 exists to prevent -- a persisted answer that only stays right
// while something is running to update it. This class stores facts a user
// action or the generator wrote, plus the escalation policy frozen at
// generation, and nothing that a clock tick could make stale.

import 'package:timezone/timezone.dart' as tz;

import '../policy/dose_resolution_policy.dart';
import 'schedule.dart';

/// One generated occurrence of a `Schedule`, and the facts `resolve()` reads
/// to decide its `DoseState`.
///
/// A Dose is its own aggregate (AD-12), referencing its `Schedule` and
/// `Medicine` by id only. AD-6 is why both [scheduledLocal] and
/// [ianaTimezone] are stored rather than a single instant: "every day at
/// 8:00" has to keep meaning 8:00 local across a DST change, so the wall
/// clock and the zone it is read in are the truth, and [scheduledAt] --
/// AD-6's `scheduledUtc` -- is a value derived from them for ordering and for
/// the comparisons `resolve()` makes against `now`.
final class Dose {
  /// Creates a Dose.
  ///
  /// [scheduledLocal] is the wall-clock time this occurrence falls at, with no
  /// zone of its own -- it is interpreted in [ianaTimezone], exactly as
  /// `Schedule.timeOfDay` is. [id] is derived, never supplied, per the
  /// spine's Identifiers convention: `"{scheduleId}:{scheduledLocal
  /// ISO-8601}"`, so a Dose is addressable from a notification payload
  /// without a lookup and regeneration is naturally idempotent (AD-10).
  ///
  /// [escalationWindowMinutes] and [followUpOffsetsMinutes] are the
  /// Escalation Window policy already resolved and frozen at generation
  /// (AD-16) -- this constructor does not compute them and does not clamp
  /// them; a caller that wants the formula applied uses
  /// `escalation_window_policy.dart` first.
  ///
  /// [medicineName], [dosageAmount], [dosageUnit] and [form] are AD-11's
  /// frozen snapshot, required rather than defaulted: `resolve()` never reads
  /// them, which is why Story 1.6 could leave them out, but Story 1.7a's
  /// `DoseRepository` cannot round-trip a row that is missing columns it must
  /// persist.
  ///
  /// Throws [ArgumentError] when [ianaTimezone] is not shaped like a zone
  /// identifier (reusing `Schedule.isValidIanaTimezone`, so the two agree on
  /// what a zone looks like), when [escalationWindowMinutes] is not positive,
  /// or when [snoozeCount] is negative. All three are programming errors: a
  /// caller reached this with a value no generator or `DoseRecorder` can
  /// produce.
  Dose({
    required this.scheduleId,
    required this.medicineId,
    required DateTime scheduledLocal,
    required this.ianaTimezone,
    this.takenAt,
    this.skippedAt,
    this.snoozedUntil,
    this.snoozeCount = 0,
    required this.escalationWindowMinutes,
    List<int> followUpOffsetsMinutes = defaultFollowUpOffsetsMinutes,
    required this.medicineName,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.form,
  }) : scheduledLocal = scheduledLocal,
       followUpOffsetsMinutes = List<int>.unmodifiable(followUpOffsetsMinutes),
       id = '$scheduleId:${scheduledLocal.toIso8601String()}',
       scheduledAt = _asInstant(scheduledLocal, ianaTimezone) {
    if (!Schedule.isValidIanaTimezone(ianaTimezone)) {
      throw ArgumentError.value(
        ianaTimezone,
        'ianaTimezone',
        'must be an IANA zone identifier such as Asia/Colombo',
      );
    }
    if (escalationWindowMinutes <= 0) {
      throw ArgumentError.value(
        escalationWindowMinutes,
        'escalationWindowMinutes',
        'must be positive: a Dose is never generated without a resolved '
            'Escalation Window (AD-16)',
      );
    }
    if (snoozeCount < 0) {
      throw ArgumentError.value(
        snoozeCount,
        'snoozeCount',
        'a snooze count cannot be negative',
      );
    }
  }

  /// Deterministic per the spine's Identifiers convention:
  /// `"{scheduleId}:{scheduledLocal ISO-8601}"`. `(scheduleId, scheduledLocal)`
  /// is unique, so regenerating a Dose that already exists overwrites the same
  /// row rather than duplicating it (AD-10).
  final String id;

  /// The `Schedule.id` this occurrence was generated from.
  final String scheduleId;

  /// The `Medicine.id` this occurrence belongs to.
  ///
  /// Denormalised from the Schedule rather than looked up, because AD-20's
  /// Escalation Window formula measures the interval to the next dose of the
  /// *same Medicine across all its Schedules* -- a question `escalation_
  /// window_policy.dart` cannot answer without knowing which Medicine each
  /// candidate belongs to.
  final String medicineId;

  /// The wall-clock time this occurrence falls at, with no zone of its own
  /// (AD-6). Interpreted in [ianaTimezone].
  final DateTime scheduledLocal;

  /// The IANA zone [scheduledLocal] is read in, and the zone `logicalDay()` is
  /// evaluated in for this Dose (AD-2) -- never the device's current zone,
  /// so a dose keeps the day it belongs to even if the user travels.
  final String ianaTimezone;

  /// [scheduledLocal] interpreted in [ianaTimezone], as an absolute instant --
  /// AD-6's `scheduledUtc`. Exists only for ordering and for the direct
  /// comparisons `resolve()` makes against `now`; [scheduledLocal] plus
  /// [ianaTimezone] remains the stored truth.
  final DateTime scheduledAt;

  /// When the user recorded taking this Dose, or `null`.
  final DateTime? takenAt;

  /// When the user recorded skipping this Dose, or `null`. Wins over every
  /// other fact, including [takenAt] (AD-2).
  final DateTime? skippedAt;

  /// The instant a live snooze runs out, or `null` when none is in effect.
  /// An expired snooze (`now >= snoozedUntil`) is not cleared here -- it falls
  /// through to the time-driven branches on its own (AD-2).
  final DateTime? snoozedUntil;

  /// How many times this Dose has been snoozed.
  final int snoozeCount;

  /// The Escalation Window's length in minutes, resolved and frozen at
  /// generation (AD-16). `resolve()` reads this, never a live
  /// `ReminderSettings` value -- otherwise a Settings change would
  /// retroactively rewrite whether a past Dose was logged late.
  final int escalationWindowMinutes;

  /// The follow-up offsets, in minutes after [scheduledAt], that made up this
  /// Dose's escalation chain at generation (AD-16). Unmodifiable.
  final List<int> followUpOffsetsMinutes;

  /// The Medicine's name, frozen at generation (AD-11).
  ///
  /// A Medicine edit refreshes this on a Dose with no user action and never
  /// touches one where [takenAt], [skippedAt] or [snoozedUntil] is set --
  /// History reads this snapshot, never a live join to the Medicine, so a
  /// later rename cannot rewrite what a recorded dose is shown as.
  final String medicineName;

  /// How much was taken at this occurrence, frozen at generation (AD-11). See
  /// [medicineName] for why a live Medicine or Schedule edit must not reach
  /// backwards through this Dose.
  final double dosageAmount;

  /// The unit [dosageAmount] is counted in, frozen at generation (AD-11). See
  /// [medicineName].
  final String dosageUnit;

  /// Tablet, capsule, drops -- frozen at generation (AD-11). See
  /// [medicineName]. Named explicitly here because the spine's ERD diagram
  /// omits it from `DOSE`'s columns; that is a diagram error, not a second
  /// source of truth -- AD-11's prose lists all four frozen fields and this is
  /// one of them.
  final String form;

  /// [escalationWindowMinutes] as a [Duration] -- what AD-2's pseudocode calls
  /// `p.window`, read from this Dose rather than from a separate policy
  /// argument (AD-16: the window comes from the Dose, never from current
  /// settings).
  Duration get window => Duration(minutes: escalationWindowMinutes);

  /// Whether [now] is still within the [doseResolveWindowDays]-day limit that
  /// lets a `Missed` Dose be resolved by a late user action (AD-4).
  ///
  /// The refusal itself belongs to `DoseRecorder`, which this story does not
  /// build; this only answers the question so that a caller checking whether
  /// an action is still possible has one place to ask.
  bool isResolvable(DateTime now) => !now.isAfter(
    scheduledAt.add(const Duration(days: doseResolveWindowDays)),
  );

  static DateTime _asInstant(DateTime local, String ianaTimezone) {
    final tz.Location location = tz.getLocation(ianaTimezone);
    return tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Dose &&
      other.id == id &&
      other.scheduleId == scheduleId &&
      other.medicineId == medicineId &&
      other.scheduledLocal == scheduledLocal &&
      other.ianaTimezone == ianaTimezone &&
      other.takenAt == takenAt &&
      other.skippedAt == skippedAt &&
      other.snoozedUntil == snoozedUntil &&
      other.snoozeCount == snoozeCount &&
      other.escalationWindowMinutes == escalationWindowMinutes &&
      _sameOffsets(other.followUpOffsetsMinutes, followUpOffsetsMinutes) &&
      other.medicineName == medicineName &&
      other.dosageAmount == dosageAmount &&
      other.dosageUnit == dosageUnit &&
      other.form == form;

  @override
  int get hashCode => Object.hash(
    id,
    scheduleId,
    medicineId,
    scheduledLocal,
    ianaTimezone,
    takenAt,
    skippedAt,
    snoozedUntil,
    snoozeCount,
    escalationWindowMinutes,
    Object.hashAll(followUpOffsetsMinutes),
    Object.hash(medicineName, dosageAmount, dosageUnit, form),
  );

  static bool _sameOffsets(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'Dose($id, medicine $medicineId)';
}
