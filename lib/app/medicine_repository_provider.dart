// The binding between the Medicine aggregate's port and its Drift adapter.
//
// This file is what Story 1.5 exists to add to the composition root. Story 1.4
// built `MedicineRepository` and `DriftMedicineRepository` and deliberately
// stopped at the port -- `test/story_scope_test.dart` guarded `lib/app/`
// against exactly this name so that a screen could not arrive early, without
// the design review the add flow needed. Story 1.5 is the first caller, so the
// guard is retired there and the binding lands here.
//
// Declared with no implementation, in the same shape as
// `onboardingStateStoreProvider` and for the same reason: a default that
// quietly constructed a real database would open a second connection from
// inside a test the moment something read this provider, which is the failure
// AD-3 exists to prevent.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/medicine_repository.dart';

/// The [MedicineRepository] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read rather than silently returning a
/// repository that stores nothing -- which for this port would mean a medicine
/// the user was told was saved and was not (PRD §9's worst bug).
final Provider<MedicineRepository> medicineRepositoryProvider =
    Provider<MedicineRepository>((ref) {
      throw UnimplementedError(
        'medicineRepositoryProvider must be overridden at the composition '
        'root. lib/main.dart binds it to DriftMedicineRepository over the one '
        'AppDatabase this process opens (AD-3).',
      );
    });
