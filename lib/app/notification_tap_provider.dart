// The route into the app: a tapped notification's `doseId`, as a stream
// (Story 3.3).
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`. This
// is this app's first `StreamProvider` -- `DoseNotifier.notificationTaps` is
// itself a plain `Stream<String>` (AD-1), so there is nothing to wrap beyond
// watching `doseNotifierProvider` and exposing its stream.
//
// `home_screen.dart` is this provider's one intended watcher (see
// `dose_notifier.dart`'s own doc comment on why the real adapter's
// underlying stream is single-subscription, not broadcast): a cold-launch
// tap is buffered until Home first mounts and this provider first builds,
// and a live tap while Home is already showing arrives through the same
// stream, whichever ordering happens to occur.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dose_notifier_provider.dart';

/// Emits a tapped notification's `doseId`, once per tap.
final StreamProvider<String> notificationTapProvider = StreamProvider<String>(
  (ref) => ref.watch(doseNotifierProvider).notificationTaps,
);
