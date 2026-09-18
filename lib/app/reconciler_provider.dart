// The binding that builds `Reconciler` from the seven ports/services it
// composes.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`. Like
// `doseGeneratorProvider`/`doseRecorderProvider`/`reminderSchedulerProvider`,
// this carries no "must be overridden" throw: `Reconciler` is a domain
// service built once its dependencies are bound, not an adapter with a
// technology choice of its own. A test that wants a fake dependency overrides
// one of the six providers this composes (or this provider directly with
// `overrideWithValue`), not this file.
//
// STORY 3.5 IS THE FIRST CALLER. `HomePlanController.build()` is this
// provider's one production read (AD-9: "nothing else in the codebase
// re-registers notifications") -- see that file's own comment for why every
// trigger funnels through invalidating `homePlanControllerProvider` rather
// than reading this provider a second time.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service/reconciler.dart';
import 'clock_provider.dart';
import 'dose_generator_provider.dart';
import 'dose_notifier_provider.dart';
import 'dose_repository_provider.dart';
import 'medicine_repository_provider.dart';
import 'reconciliation_state_store_provider.dart';
import 'reminder_scheduler_provider.dart';

/// The [Reconciler] the app uses, built over the bound [clockProvider],
/// [medicineRepositoryProvider], [doseRepositoryProvider],
/// [doseGeneratorProvider], [reminderSchedulerProvider],
/// [doseNotifierProvider] and [reconciliationStateStoreProvider].
final Provider<Reconciler> reconcilerProvider = Provider<Reconciler>((ref) {
  return Reconciler(
    ref.watch(clockProvider),
    ref.watch(medicineRepositoryProvider),
    ref.watch(doseRepositoryProvider),
    ref.watch(doseGeneratorProvider),
    ref.watch(reminderSchedulerProvider),
    ref.watch(doseNotifierProvider),
    ref.watch(reconciliationStateStoreProvider),
  );
});
