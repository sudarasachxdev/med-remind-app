// The binding that builds `DoseRecorder` from the three ports it composes.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`. Like
// `doseGeneratorProvider`, this carries no "must be overridden" throw:
// `DoseRecorder` is a domain service built once its dependencies are bound,
// not an adapter with a technology choice of its own. A test that wants a
// fake dependency overrides `clockProvider` / `doseRepositoryProvider` /
// `doseNotifierProvider` (or this provider directly with
// `overrideWithValue`), not this file.
//
// STORY 2.1 BUILDS NO CALLER FROM `lib/features/` -- this story is the port
// and its composition, exactly as `dose_repository_provider.dart` preceded
// `DoseGenerator`'s own screen caller in Story 1.7a/1.8. Story 2.2/2.3 read
// this provider from the action sheet and the dose card; nothing here does.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service/dose_recorder.dart';
import 'clock_provider.dart';
import 'dose_notifier_provider.dart';
import 'dose_repository_provider.dart';

/// The [DoseRecorder] the app uses, built over the bound [clockProvider],
/// [doseRepositoryProvider] and [doseNotifierProvider].
final Provider<DoseRecorder> doseRecorderProvider = Provider<DoseRecorder>((
  ref,
) {
  return DoseRecorder(
    ref.watch(clockProvider),
    ref.watch(doseRepositoryProvider),
    ref.watch(doseNotifierProvider),
  );
});
