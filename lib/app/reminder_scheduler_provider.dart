// The binding that builds `ReminderScheduler` from the one port it composes.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`. Like
// `doseGeneratorProvider`/`doseRecorderProvider`, this carries no "must be
// overridden" throw: `ReminderScheduler` is a domain service built once its
// dependency is bound, not an adapter with a technology choice of its own. A
// test that wants a fake dependency overrides `doseNotifierProvider` (or this
// provider directly with `overrideWithValue`), not this file.
//
// `ReminderScheduler` never had a provider of its own before this story --
// Story 3.3 built it with no live caller (that file's own header comment).
// This story's `Reconciler` is the first, so this is where the binding lands.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service/reminder_scheduler.dart';
import 'dose_notifier_provider.dart';

/// The [ReminderScheduler] the app uses, built over the bound
/// [doseNotifierProvider].
final Provider<ReminderScheduler> reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) {
      return ReminderScheduler(ref.watch(doseNotifierProvider));
    });
