// AD-7: notification identifiers are derived, never allocated and stored.
// This file is the sole authority for that derivation across the whole
// product -- `FlutterLocalNotificationsDoseNotifier.schedule` and
// `.cancelPending` both call [notificationId] rather than keeping a table of
// which ids are outstanding for which Dose.
//
// AD-1: pure Dart, no imports beyond `dart:core` -- this is a policy, exactly
// like `dose_resolution_policy.dart`'s named constants, not a service that
// touches a port.

/// The four kinds of notification a Dose may have pending at once (AD-7,
/// AD-8): the primary reminder at `Dose.scheduledAt`, the two follow-up
/// escalations, and a re-scheduled reminder once a snooze is in effect.
///
/// Exactly four members -- there is no fifth "second final" or "+60 reminder"
/// slot. See `dose_resolution_policy.dart`'s own doc comment on
/// `defaultFollowUpOffsetsMinutes` for why index `[2]` of that list (60) is
/// not a fifth tier: it is `Dose.escalationWindowMinutes`'s own illustrative
/// value under the default formula, not a notification offset.
enum NotificationTier {
  /// The reminder at the Dose's own scheduled time.
  primary,

  /// The first escalation, at `Dose.scheduledAt + followUpOffsetsMinutes[0]`.
  followUp,

  /// The second escalation, at
  /// `Dose.scheduledAt + followUpOffsetsMinutes[1]`.
  finalFollowUp,

  /// The reminder re-scheduled for `Dose.snoozedUntil`, once a snooze is in
  /// effect.
  snooze,
}

/// Derives the OS notification id for [doseId]'s [tier] (AD-7).
///
/// Deterministic and stateless: the same `(doseId, tier)` pair always
/// produces the same id, with nothing stored anywhere to look up. That is
/// what lets `DoseRecorder.cancelPending` -- by way of
/// `FlutterLocalNotificationsDoseNotifier.cancelPending` -- recompute every
/// tier's id for a Dose it holds only the id of, and cancel each one whether
/// or not it was ever actually scheduled (idempotent, per
/// `DoseNotifier.cancelPending`'s own contract).
///
/// A collision between two different `(doseId, tier)` pairs hashing to the
/// same id is possible -- [stableHash32] does not guarantee uniqueness -- and
/// is accepted per AD-7: resolving it is a generator's concern, not this
/// function's, and the plugin already treats a repeated id as a harmless
/// replace rather than a corrupt state.
int notificationId(String doseId, NotificationTier tier) =>
    stableHash32('$doseId:${tier.name}');

/// A pure, deterministic hash of [input] (AD-7's own vocabulary: "a pure
/// 32-bit string hash"), returned as a non-negative value that always fits a
/// signed 32-bit integer.
///
/// FNV-1a over [input]'s UTF-16 code units: simple, well-understood, and
/// stable across Dart SDK versions and process restarts -- unlike
/// `Object.hash`/`String.hashCode`, both explicitly documented as unstable
/// across runs and never suitable for a value a caller persists or hands to
/// a platform API.
///
/// The 32-bit FNV-1a state is masked to its low 31 bits before it is
/// returned, not to the full 32. `flutter_local_notifications`' own
/// `validateId` (via `flutter_local_notifications_platform_interface`)
/// rejects any id outside `[-2^31, 2^31 - 1]` -- the *signed* 32-bit range --
/// and a full unsigned 32-bit value is outside that range roughly half the
/// time. Masking to 31 bits keeps every returned id inside `[0, 2^31 - 1]`,
/// which is both a valid signed 32-bit integer and, trivially, within the
/// wider 32-bit unsigned range this function's own name promises.
int stableHash32(String input) {
  const int fnvPrime = 0x01000193;
  const int fnvOffsetBasis = 0x811c9dc5;
  const int mask32 = 0xFFFFFFFF;

  int hash = fnvOffsetBasis;
  for (final int unit in input.codeUnits) {
    hash = (hash ^ unit) & mask32;
    hash = (hash * fnvPrime) & mask32;
  }
  return hash & 0x7FFFFFFF;
}
