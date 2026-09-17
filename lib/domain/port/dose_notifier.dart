// AD-4's second half: the port every recorded Dose action cancels through,
// and -- as of Story 3.2 -- the port Story 3.3 schedules a real reminder
// through.
//
// AD-1: pure Dart, `package:meta/` and `package:timezone/` only, transitively
// through `Dose`. This file's own imports are `Dose` and `NotificationTier`,
// both domain types -- a port that schedules and cancels notifications by id
// needs no platform package to say so, exactly like `clock.dart` needed none
// to name `now()`.
//
// WHY `NoOpDoseNotifier` REMAINS, EVEN THOUGH ITS OWN PROVIDER NO LONGER
// DEFAULTS TO IT. Story 3.2 is the first story to build a real adapter
// (`lib/platform/notifications/flutter_local_notifications_dose_notifier.dart`),
// so `lib/app/dose_notifier_provider.dart` flips to the no-safe-default
// (throws) pattern the same way `permissionGatewayProvider` and
// `doseRepositoryProvider` already do -- an unbound provider silently
// scheduling and cancelling nothing is no longer "genuinely nothing to
// schedule" once a real adapter exists to bind instead; it is a missing
// binding wearing a working-looking default. `NoOpDoseNotifier` itself is not
// deleted: `test/support/fake_dose_notifier.dart` and any test that wants an
// inert notifier still have it, the same way this class never implied there
// was nothing left to build.
//
// AD-7 (notification ids): [DoseNotifier.schedule] and
// [DoseNotifier.cancelPending] both take the identifiers a caller already
// has -- `Dose.id` and a [NotificationTier] -- and leave deriving the actual
// OS notification id to whichever adapter implements this
// (`notification_id_policy.dart`'s `notificationId`). Nothing on this port
// allocates or stores an id itself.
//
// THE REAL ADAPTER IS STORY 3.2'S, under `lib/platform/notifications/` -- the
// directory `test/story_scope_test.dart` kept empty until now. Nothing here
// touches `flutter_local_notifications`; this port and its no-op both stay
// pure Dart.

import '../model/dose.dart';
import '../policy/notification_id_policy.dart';

/// Schedules and cancels a Dose's reminder notifications (AD-4, AD-6, AD-7).
///
/// `DoseRecorder` is [cancelPending]'s one caller (AD-4): every recorded
/// action -- take, skip or snooze -- cancels through here as the last step of
/// one logical unit of work, after the write to `DoseRepository` succeeds. A
/// failure here fails the whole action; there is no partial success (PRD §9).
/// [schedule] has no caller yet as of this port's own story (3.2) -- Story
/// 3.3 is its first, matching the position this port itself was in from
/// Story 2.1 until `DoseRecorder` called [cancelPending].
abstract interface class DoseNotifier {
  /// Schedules a reminder notification for [dose]'s [tier], with [title] and
  /// [body] as its content.
  ///
  /// The fire time is computed from [dose] and [tier]: `primary` fires at
  /// `dose.scheduledAt`; `followUp`/`finalFollowUp` fire at
  /// `dose.scheduledAt` plus `dose.followUpOffsetsMinutes[0]`/`[1]`
  /// respectively; `snooze` fires at `dose.snoozedUntil`, which must already
  /// be set -- a caller only schedules this tier once a snooze exists.
  Future<void> schedule({
    required Dose dose,
    required NotificationTier tier,
    required String title,
    required String body,
  });

  /// Cancels whatever is still pending for the Dose with [doseId] -- every
  /// [NotificationTier] alike, recomputed by id rather than looked up
  /// (AD-7).
  ///
  /// Idempotent: calling this for a Dose with nothing pending (already
  /// cancelled, or never scheduled) succeeds without effect, matching
  /// `DoseRepository.deleteDose`'s own idempotence.
  Future<void> cancelPending(String doseId);

  /// Emits a tapped notification's `doseId`, once per tap (Story 3.3, the
  /// route into the app).
  ///
  /// A tap is this port's third lifecycle event, alongside [schedule] and
  /// [cancelPending] -- not an unrelated concern needing its own port. A
  /// dismissal is never emitted here: the app must do nothing when the user
  /// dismisses a notification without opening it, and this stream is
  /// tap-only by construction, not by a filter a caller has to apply.
  ///
  /// `notification_tap_provider.dart`'s `notificationTapProvider` is this
  /// stream's one intended listener.
  Stream<String> get notificationTaps;
}

/// A [DoseNotifier] that schedules and cancels nothing, successfully.
///
/// No longer this port's default (see this file's own comment on
/// `dose_notifier_provider.dart`'s flip), but still available to any test
/// that wants an inert notifier -- `test/support/fake_dose_notifier.dart`
/// covers the case where a test wants to observe calls instead.
final class NoOpDoseNotifier implements DoseNotifier {
  /// Creates the no-op. `const`, since it holds no state.
  const NoOpDoseNotifier();

  @override
  Future<void> schedule({
    required Dose dose,
    required NotificationTier tier,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelPending(String doseId) async {}

  @override
  Stream<String> get notificationTaps => const Stream<String>.empty();
}
