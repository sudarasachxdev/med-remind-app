// The binding for `DoseNotifier` -- the one port whose default is not a
// throw.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`.
//
// Unlike `medicineRepositoryProvider`, `doseRepositoryProvider` and
// `clockProvider`, this provider returns a real, working default rather than
// throwing when unoverridden. `dose_notifier.dart`'s own file comment states
// why: `NoOpDoseNotifier` is correct, permanent behaviour for the whole of
// Epics 1-2, not a missing binding standing in for a real one. Epic 3
// overrides this at the composition root with the
// `flutter_local_notifications`-backed adapter; nothing before it needs to,
// and a test that wants to watch cancellation overrides this provider with a
// recording fake instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/dose_notifier.dart';

/// The [DoseNotifier] the app uses. Defaults to [NoOpDoseNotifier].
final Provider<DoseNotifier> doseNotifierProvider = Provider<DoseNotifier>((
  ref,
) {
  return const NoOpDoseNotifier();
});
