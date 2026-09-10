// The binding that builds `DoseGenerator` from the two repository ports it
// composes.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`. Unlike
// `doseRepositoryProvider`, this one carries no "must be overridden" throw --
// `DoseGenerator` is not an adapter with a technology choice behind it, it is
// a domain service built once its two dependencies are bound, exactly the way
// `routerProvider` composes `onboardingCompletedAtStartupProvider` rather than
// being bound directly in `startupOverrides`. A test that wants a fake
// generator overrides `medicineRepositoryProvider`/`doseRepositoryProvider`
// (or this provider directly with `overrideWithValue`), not this file.
//
// STORY 1.8 IS THE FIRST CALLER FROM `lib/app/`. `DoseGenerator` itself has
// existed since Story 1.7b, called only from `lib/domain/service/`'s own
// tests -- nothing under `lib/app/` or `lib/features/` named it, because no
// Reconciler existed yet to wire it into the composition root (AD-9, Epic 3).
// AD-9's amendment of 2026-09-10 is what permits this binding to exist before
// that: Home's provider layer may call `DoseGenerator.generate(now)` directly,
// and only that one step -- see `home_plan_controller.dart`, which names the
// call site unmistakably provisional.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/service/dose_generator.dart';
import 'dose_repository_provider.dart';
import 'medicine_repository_provider.dart';

/// The [DoseGenerator] the app uses, built over the bound
/// [medicineRepositoryProvider] and [doseRepositoryProvider].
final Provider<DoseGenerator> doseGeneratorProvider = Provider<DoseGenerator>((
  ref,
) {
  return DoseGenerator(
    ref.watch(medicineRepositoryProvider),
    ref.watch(doseRepositoryProvider),
  );
});
