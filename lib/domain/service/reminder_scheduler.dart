// FR-6/FR-11: builds a primary reminder's content and gates it on a
// Schedule's own reminders toggle.
//
// AD-1: pure Dart, `package:meta/` and `package:timezone/` only, transitively
// through `Dose`. This file's own imports are `Dose`, `NotificationTier` and
// `DoseNotifier` -- a port and sibling domain types, nothing platform-bound.
//
// A domain SERVICE, not a policy, matching `DoseRecorder`'s own reasoning
// (see that file's header comment): it orchestrates one port (`DoseNotifier`)
// rather than computing a pure answer from arguments alone.
//
// No live caller yet, exactly as `DoseNotifier.schedule` itself had none
// until this story -- Story 3.5's `Reconciler` is the first.

import '../model/dose.dart';
import '../policy/notification_id_policy.dart';
import '../port/dose_notifier.dart';

/// Schedules a Dose's primary reminder, gated on `Schedule.remindersEnabled`
/// (FR-11).
final class ReminderScheduler {
  /// Creates a scheduler over [_notifier]. A port (AD-1): this class never
  /// sees `flutter_local_notifications`, only what `DoseNotifier` promises.
  ReminderScheduler(this._notifier);

  final DoseNotifier _notifier;

  /// Schedules [dose]'s primary reminder, unless [remindersEnabled] is
  /// `false`.
  ///
  /// No-ops on `false` -- FR-11's own words: "no notification fires, and the
  /// Dose still transitions through Dose States correctly". The second half
  /// is already true without anything here: `resolve()` never reads anything
  /// this method touches, so a Dose with reminders disabled resolves exactly
  /// as one with them enabled.
  ///
  /// The title is [dose]'s Medicine name; the body names the dosage amount
  /// and unit (FR-6: "shows the Medicine name and the dosage amount"). Both
  /// are built here, from `Dose`'s own AD-11 frozen snapshot, rather than
  /// imported from any presentation-layer copy file -- `HomeCopy` lives under
  /// `lib/features/home/presentation/`, which this domain service may not
  /// depend on (AD-1).
  Future<void> schedulePrimary(
    Dose dose, {
    required bool remindersEnabled,
  }) async {
    if (!remindersEnabled) return;

    await _notifier.schedule(
      dose: dose,
      tier: NotificationTier.primary,
      title: dose.medicineName,
      body: '${_amountLabel(dose.dosageAmount)} ${dose.dosageUnit}',
    );
  }

  /// A dose amount without a trailing `.0` on a whole number -- `1`, `2.5`.
  ///
  /// Duplicates `HomeCopy.doseAmountLabel`'s own logic rather than importing
  /// it: that file is presentation-layer copy (`lib/features/home/
  /// presentation/home_copy.dart`), which AD-1 keeps out of `lib/domain/`.
  /// The two are small enough, and separately owned enough (a notification's
  /// body is not a UI label), that duplicating this one line costs less than
  /// inventing a shared home for it.
  static String _amountLabel(double amount) => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();

  /// Schedules [dose]'s first follow-up reminder, unless [remindersEnabled]
  /// is `false` or [dose]'s own frozen `followUpOffsetsMinutes[0]` is at or
  /// past its own frozen `escalationWindowMinutes`.
  ///
  /// The second guard is unreachable through today's UI -- the Escalation
  /// Window's own formula never resolves narrower than a 60-minute floor,
  /// safely past the default offset of 15 -- but is built anyway: it is what
  /// makes "Follow-Up Reminders stop when the Escalation Window closes"
  /// (FR-11) a structural guarantee of this method rather than an accident of
  /// today's one reachable default, since `Schedule.reminderOverride` already
  /// exists as a field a future story could wire a narrower window through.
  ///
  /// The body is EXPERIENCE.md's own UJ-3 walkthrough copy for this exact
  /// moment, verbatim.
  Future<void> scheduleFollowUp(
    Dose dose, {
    required bool remindersEnabled,
  }) async {
    if (!remindersEnabled) return;
    if (dose.followUpOffsetsMinutes[0] >= dose.escalationWindowMinutes) {
      return;
    }

    await _notifier.schedule(
      dose: dose,
      tier: NotificationTier.followUp,
      title: dose.medicineName,
      body: 'Your ${_timeLabel(dose.scheduledLocal)} dose is still waiting.',
    );
  }

  /// Schedules [dose]'s final follow-up reminder, unless [remindersEnabled]
  /// is `false` or [dose]'s own frozen `followUpOffsetsMinutes[1]` is at or
  /// past its own frozen `escalationWindowMinutes`. See [scheduleFollowUp]
  /// for why this guard exists even though nothing reachable today trips it.
  ///
  /// The body is authored for this story -- EXPERIENCE.md names no exact
  /// copy for this moment, only that it exists ("final reminder... still no
  /// response"). FR-11's own words are the binding constraint: differ from
  /// the primary, communicate the Dose is still unresolved, escalate in
  /// specificity without escalating in tone. No fixed number of minutes is
  /// named, since the cadence is nominally per-schedule configurable (AD-16)
  /// even though nothing reachable overrides it yet.
  Future<void> scheduleFinalFollowUp(
    Dose dose, {
    required bool remindersEnabled,
  }) async {
    if (!remindersEnabled) return;
    if (dose.followUpOffsetsMinutes[1] >= dose.escalationWindowMinutes) {
      return;
    }

    await _notifier.schedule(
      dose: dose,
      tier: NotificationTier.finalFollowUp,
      title: dose.medicineName,
      body:
          'Your ${_timeLabel(dose.scheduledLocal)} dose is still unresolved. '
          'Reminders will stop soon.',
    );
  }

  /// `8:00 AM` / `8:15 PM` -- duplicates `HomeCopy.timeLabel`'s exact
  /// algorithm (`lib/features/home/presentation/home_copy.dart:100-105`),
  /// including its own leading-zero behaviour on the hour (it prints
  /// `08:00 AM`, not `8:00 AM`, despite that method's own doc comment's
  /// example) -- matching the code, not the comment, so a notification's
  /// wording reads consistently with what Home already shows for the same
  /// Dose. Duplicated rather than imported for the same AD-1 reason
  /// [_amountLabel] duplicates `HomeCopy.doseAmountLabel`.
  static String _timeLabel(DateTime time) {
    final int hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String meridiem = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $meridiem';
  }
}
