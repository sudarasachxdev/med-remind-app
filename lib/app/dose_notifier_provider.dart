// The binding between `DoseNotifier` and its
// `flutter_local_notifications` adapter.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`.
//
// UNTIL STORY 3.2, THIS PROVIDER'S DEFAULT WAS `NoOpDoseNotifier`, NOT A
// THROW. `dose_notifier.dart`'s own file comment explains why that was
// correct then: no `flutter_local_notifications` schedule existed anywhere
// in the codebase, so a no-op was not standing in for a missing binding --
// it was genuinely nothing to schedule or cancel yet.
//
// Story 3.2 is the story that builds the real adapter
// (`FlutterLocalNotificationsDoseNotifier`), which is why this provider flips
// here, to the same no-safe-default (throws) pattern
// `permissionGatewayProvider` and `doseRepositoryProvider` already use. Once
// a real adapter exists, an unbound provider silently scheduling and
// cancelling nothing is no longer "genuinely nothing to do" -- it is a
// missing binding wearing a working-looking default, the exact silent-success
// failure AD-14 exists to prevent. `NoOpDoseNotifier` is not deleted: a test
// that wants an inert notifier still has it, and one that wants to watch
// scheduling or cancellation overrides this provider with
// `test/support/fake_dose_notifier.dart`'s recording fake instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/dose_notifier.dart';

/// The [DoseNotifier] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read -- never a plausible default
/// that quietly schedules and cancels nothing when a real adapter exists to
/// bind instead.
final Provider<DoseNotifier> doseNotifierProvider = Provider<DoseNotifier>((
  ref,
) {
  throw UnimplementedError(
    'doseNotifierProvider must be overridden at the composition root. '
    'lib/main.dart binds it to FlutterLocalNotificationsDoseNotifier '
    '(AD-6, AD-7).',
  );
});
