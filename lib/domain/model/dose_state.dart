// The seven states `resolve()` can produce (AD-2), and the value that carries
// `loggedLate` alongside `Taken`.
//
// AD-1: pure Dart, no imports.
//
// Vocabulary is PRD §3's, verbatim: `DoseState`, used exactly this way
// everywhere it appears -- in this type, in UI copy, nowhere renamed.

/// The state a `Dose` is in, as decided by `resolve()` over stored facts and
/// the clock -- never stored itself (AD-2).
///
/// Order here is declaration order for readability only; it carries no
/// meaning of its own. The order that matters is `resolve()`'s branch order,
/// which AD-2 fixes and this enum does not repeat.
enum DoseState {
  /// The scheduled time has not arrived yet: `now < scheduledAt`.
  scheduled,

  /// The scheduled time has arrived and the escalation window has not
  /// elapsed: `scheduledAt <= now < scheduledAt + window`.
  due,

  /// The escalation window has elapsed, but it is still the scheduled day
  /// (AD-2's `logicalDay`, not a raw date comparison).
  overdue,

  /// The escalation window has elapsed and the logical day has moved on. The
  /// last stop on the time-driven branch; a Dose does not return from here on
  /// its own.
  missed,

  /// The user recorded taking it: `takenAt != null`. See [DoseResolution]
  /// for whether it was late.
  taken,

  /// A snooze is in effect and has not expired: `now < snoozedUntil`. An
  /// expired snooze falls through to the time-driven branches instead of
  /// staying here (AD-2) -- there is no separate "snooze expired" state.
  snoozed,

  /// The user recorded skipping it: `skippedAt != null`. Wins over every
  /// other branch, including a `takenAt` set on the same Dose -- AD-2's
  /// branch order is the rule, and this is the case that proves it is not an
  /// accident of the happy path.
  skipped,
}

/// The result of `resolve()`: a [DoseState], plus whether a [DoseState.taken]
/// Dose was logged after its window closed.
///
/// A plain `DoseState` cannot carry `loggedLate` -- an enum case takes no
/// payload -- and the spine's I/O matrix requires it precisely for the
/// `taken` branch ("Taken after the window -> Taken, loggedLate == true").
/// [loggedLate] is meaningless for every other state and is fixed at `false`
/// for all of them, rather than left `null`, so a caller can read it without
/// checking [state] first and never mistakes an unrelated `false` for "on
/// time".
final class DoseResolution {
  /// Creates a resolution. [loggedLate] must be `false` unless [state] is
  /// [DoseState.taken] -- no other state has a meaning for it.
  DoseResolution(this.state, {this.loggedLate = false}) {
    if (loggedLate && state != DoseState.taken) {
      throw ArgumentError.value(
        state,
        'state',
        'loggedLate only has a meaning when state is DoseState.taken',
      );
    }
  }

  /// The resolved state.
  final DoseState state;

  /// Whether a [DoseState.taken] Dose was recorded after its escalation
  /// window closed (AD-16: decided by the Dose's own frozen window, never by
  /// current `ReminderSettings`). Always `false` for every other [state].
  final bool loggedLate;

  @override
  bool operator ==(Object other) =>
      other is DoseResolution &&
      other.state == state &&
      other.loggedLate == loggedLate;

  @override
  int get hashCode => Object.hash(state, loggedLate);

  @override
  String toString() => state == DoseState.taken
      ? 'DoseResolution(${state.name}, loggedLate: $loggedLate)'
      : 'DoseResolution(${state.name})';
}
