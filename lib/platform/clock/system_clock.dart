// The one place in the product that reads the ambient clock (AD-5), and the one
// place that reads the device's timezone (AD-9, as amended 2026-09-08).
//
// Named for the technology, as the spine's naming rule asks: the port is
// `Clock`, the adapter is `SystemClock`. `test/architecture_test.dart` exempts
// exactly this directory from the AD-5 rule and fails the build on a
// `DateTime.now()` anywhere else, and `test/story_scope_test.dart` fails the
// build on a `flutter_timezone` import anywhere else. Between them this file is
// the whole of the product's contact with "now" and "here".
//
// ---------------------------------------------------------------------------
// WHY THE ZONE IS READ HERE AND NOT IN EPIC 3.
//
// AD-9 originally reserved every read of the device zone to Epic 3's
// Reconciler. That contradicted AD-6, which requires every Schedule to persist
// a real IANA zone -- and Story 1.5 is the first story that creates a Schedule,
// so it had no legal way to obtain one. The two workarounds were both worse
// than amending the rule: storing a placeholder like `Etc/UTC` writes a zone
// that is WRONG rather than unknown (for a user in `Asia/Colombo`, "08:00 PM
// Etc/UTC" is a different instant, and Stories 1.6/1.7 resolve Doses against
// the stored value as if it were true), and leaving the Medicine unscheduled is
// forbidden by FR-1.
//
// AD-9 now separates the two things it had conflated: READING the zone, which
// happens once when the user saves a Schedule and is not a catch-up path, from
// REACTING to a zone having changed, which is still the Reconciler's alone and
// is the divergence AD-9 exists to prevent.
// ---------------------------------------------------------------------------

import 'package:flutter_timezone/flutter_timezone.dart';

import '../../domain/port/clock.dart';

/// The device clock and its zone.
///
/// [ianaTimezone] is resolved once, by [resolve], rather than read on every
/// access: `FlutterTimezone` is asynchronous and `Clock.ianaTimezone` is not,
/// because a Schedule's zone is part of what the user said at the moment they
/// said it. Re-reading it per access would let one save straddle a zone change
/// and stamp a Schedule with a zone the user was never in.
final class SystemClock implements Clock {
  /// Creates a clock over an already-resolved zone.
  ///
  /// Prefer [resolve]. This constructor exists for the composition root, which
  /// resolves once at startup, and for tests, which pass a known zone.
  const SystemClock({required this.ianaTimezone});

  /// Reads the device's current IANA zone and returns a clock over it.
  ///
  /// Throws [ClockZoneUnavailable] when the platform answers with something
  /// `Schedule.isValidIanaTimezone` would reject. That is deliberately not
  /// swallowed: a caller that received a clock would go on to stamp Schedules
  /// with a bad zone, and AD-6 makes that the one failure this product cannot
  /// absorb quietly. The composition root decides what the user sees.
  static Future<SystemClock> resolve() async {
    // `getLocalTimezone` answers a `TimezoneInfo`, whose `identifier` is the
    // IANA name. Its `localizedName` -- "Central European Standard Time" -- is
    // deliberately ignored: it is display text, it is absent on some platforms,
    // and it is not what AD-6 stores.
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    final String zone = info.identifier;
    if (!zone.contains('/')) {
      // Every IANA identifier is `Region/Location`, and the abbreviations Dart
      // and some platforms answer instead -- `IST`, `+0530` -- are exactly what
      // AD-6 rejects, because three different zones answer `IST`.
      throw ClockZoneUnavailable(zone);
    }
    return SystemClock(ianaTimezone: zone);
  }

  @override
  final String ianaTimezone;

  @override
  DateTime now() => DateTime.now();
}

/// Thrown when the platform cannot name the device's zone in IANA form.
final class ClockZoneUnavailable implements Exception {
  /// Creates the failure, naming what the platform answered instead.
  const ClockZoneUnavailable(this.reported);

  /// What the platform returned. Kept for the log: an abbreviation here tells a
  /// very different story from an empty string.
  final String reported;

  @override
  String toString() =>
      'ClockZoneUnavailable: the platform reported "$reported", which is not '
      'an IANA zone identifier. AD-6 requires a real zone on every Schedule.';
}

/// A clock that knows the time but not the zone.
///
/// Bound when [SystemClock.resolve] fails at startup. Every read of [now]
/// succeeds, so Home renders and History reads; every read of [ianaTimezone]
/// throws, so the one operation that would persist a wrong zone -- saving a
/// Schedule -- fails loudly instead.
///
/// This asymmetry is the point. Refusing to launch over a zone the user may
/// never need is worse than launching, and storing `Etc/UTC` so that the save
/// button works is worse than both: it is silently wrong, and it stays wrong
/// after the platform starts answering.
final class UnresolvedZoneClock implements Clock {
  /// Creates the fallback, carrying [cause] so the failure at the save site
  /// still names what the platform originally reported.
  const UnresolvedZoneClock(this.cause);

  /// Why the zone could not be resolved at startup.
  final ClockZoneUnavailable cause;

  @override
  DateTime now() => DateTime.now();

  @override
  String get ianaTimezone => throw cause;
}
