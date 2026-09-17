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
}
