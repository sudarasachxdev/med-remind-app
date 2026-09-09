// The binding between the `Clock` port and the device clock.
//
// AD-13, hand-written: one provider per file, named `<subject>Provider`, built
// from `Provider`.
//
// Declared with no implementation, in the same shape as
// `onboardingStateStoreProvider` and `medicineRepositoryProvider` -- but for a
// different reason, worth stating because the obvious reading is wrong. A
// `SystemClock` owns nothing and opens nothing, so a default would cost nothing
// on the AD-3 grounds those two providers cite. What it would cost is the ZONE.
//
// AD-9 (as amended 2026-09-08) lets a Schedule's zone be read from the device,
// and `flutter_timezone` answers asynchronously. A synchronous default would
// therefore have to invent a zone -- and a wrong zone is worse than no zone,
// because AD-6 makes the stored zone the truth that Stories 1.6/1.7 resolve
// Doses against. So the zone is resolved once at startup and bound here, and a
// reader with no override is told so rather than handed a plausible default.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/clock.dart';

/// The [Clock] the app reads "now" and "here" from.
///
/// **Must be overridden** at the composition root. Tests override it with a
/// fixed clock, so that "starting today" is an assertion about a known date
/// rather than about whatever day the suite happens to run on.
final Provider<Clock> clockProvider = Provider<Clock>((ref) {
  throw UnimplementedError(
    'clockProvider must be overridden at the composition root. lib/main.dart '
    'binds it to the SystemClock resolved before the first frame, because the '
    'device zone is read asynchronously and AD-6 forbids guessing it.',
  );
});
