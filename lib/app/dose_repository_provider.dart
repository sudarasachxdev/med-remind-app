// The binding between the Dose aggregate's port and its Drift adapter.
//
// This file is what Story 1.8 exists to add to the composition root. Story
// 1.7a built `DoseRepository` and `DriftDoseRepository` and deliberately
// stopped at the port, and Story 1.7b's `DoseGenerator` used it only from
// `lib/domain/service/` -- `test/story_scope_test.dart` guarded `lib/app/`
// against either name so that a screen could not arrive early, before Home
// existed to need one. Story 1.8 is that caller, so the guard is retired
// there and the binding lands here.
//
// Declared with no implementation, in the same shape as
// `medicineRepositoryProvider` and for the same reason: a default that
// quietly constructed a real database would open a second connection from
// inside a test the moment something read this provider, which is the
// failure AD-3 exists to prevent.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/dose_repository.dart';

/// The [DoseRepository] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read rather than silently returning
/// a repository that stores nothing -- which for this port would mean
/// Home reading an empty plan forever, with nothing on screen saying why.
final Provider<DoseRepository> doseRepositoryProvider =
    Provider<DoseRepository>((ref) {
      throw UnimplementedError(
        'doseRepositoryProvider must be overridden at the composition root. '
        'lib/main.dart binds it to DriftDoseRepository over the one '
        'AppDatabase this process opens (AD-3).',
      );
    });
