// AD-4's second half: the port every recorded Dose action cancels through,
// and the permanent, correct default that stands until Epic 3 builds a real
// one.
//
// AD-1: pure Dart. This file imports nothing at all -- a port that cancels a
// notification by id needs no model and no package to say so, exactly like
// `clock.dart`.
//
// WHY THE DEFAULT IS NOT A THROW, UNLIKE EVERY OTHER PORT'S PROVIDER.
// `medicineRepositoryProvider`, `doseRepositoryProvider` and `clockProvider`
// all throw when unoverridden, because a silent default there would hide a
// real failure -- a medicine reported saved that was not, a clock reading the
// wrong zone. Doing nothing when there is nothing to cancel is not that kind
// of failure: no `flutter_local_notifications` schedule exists anywhere in
// this codebase before Epic 3 builds the adapter that creates one
// (`lib/platform/notifications/` stays empty -- `test/story_scope_test.dart`),
// so `NoOpDoseNotifier` is not standing in for a missing binding. It is
// correct, permanent behaviour for the whole of Epics 1-2.
// `lib/app/dose_notifier_provider.dart` reflects this: it returns one
// directly rather than throwing.
//
// AD-7 (notification ids) shapes this port without this story building AD-7's
// real implementation: [DoseNotifier.cancelPending] takes the one identifier
// a caller already has -- `Dose.id` -- and leaves how many actual OS
// notifications that cancels (the primary reminder, plus however many
// follow-ups from `Dose.followUpOffsetsMinutes` are still pending) entirely to
// whichever adapter implements this later.
//
// STORY 2.1 ENDS HERE, exactly as Story 1.7a ended at `DoseRepository`. The
// real, `flutter_local_notifications`-backed implementation is Epic 3's;
// nothing here touches that package, and nothing here belongs under
// `lib/platform/notifications/` -- this port and its no-op both touch no
// platform API, so `test/story_scope_test.dart`'s empty-directory guard is
// untouched by this story.

/// Cancels a Dose's pending reminder notifications (AD-4, AD-7).
///
/// `DoseRecorder` is this port's one caller (AD-4): every recorded action --
/// take, skip or snooze -- cancels through here as the last step of one
/// logical unit of work, after the write to `DoseRepository` succeeds. A
/// failure here fails the whole action; there is no partial success (PRD §9).
abstract interface class DoseNotifier {
  /// Cancels whatever is still pending for the Dose with [doseId] -- the
  /// primary reminder and any follow-up escalation notification alike.
  ///
  /// Idempotent: calling this for a Dose with nothing pending (already
  /// cancelled, or never scheduled -- true of every Dose before Epic 3 exists
  /// to schedule one) succeeds without effect, matching
  /// `DoseRepository.deleteDose`'s own idempotence.
  Future<void> cancelPending(String doseId);
}

/// A [DoseNotifier] that cancels nothing, successfully.
///
/// The correct default for the whole of Epics 1-2, not a placeholder: no
/// notification is ever scheduled before Epic 3 builds the adapter that
/// schedules one, so there is genuinely nothing to cancel, and doing nothing
/// is the honest answer rather than a throw standing in for a missing binding
/// (contrast `medicineRepositoryProvider`).
final class NoOpDoseNotifier implements DoseNotifier {
  /// Creates the no-op. `const`, since it holds no state.
  const NoOpDoseNotifier();

  @override
  Future<void> cancelPending(String doseId) async {}
}
