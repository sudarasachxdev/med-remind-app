// The ambient clock, as a port (AD-5).
//
// AD-1: pure Dart. This file imports nothing at all -- a port that reads the
// time needs no model and no package to say so.
//
// AD-5 confines `DateTime.now()`, `DateTime.timestamp()` and `TZDateTime.now()`
// to the adapter under `lib/platform/clock/`, and
// `test/architecture_test.dart` fails the build on any of them written
// anywhere else. Everything that needs the time therefore takes this.
//
// WHY IT ARRIVES IN STORY 1.5. `Medicine.startDate` records FR-1's "a start
// date of today", and neither `Medicine` nor `MedicineRepository` reads a
// clock: the port's own doc says "today" is decided by the feature that has a
// clock injected. Story 1.5 is the first feature with one, so it is the first
// story with a consumer -- and a port with no consumer is a placeholder, which
// is why Story 1.4 deliberately left it unbuilt.
//
// DELIBERATELY NARROW. Story 1.6 owns dose resolution and needs a
// `TZDateTime` in the dose's own zone; nothing of that shape is here, because
// the only question this story asks is "what calendar day is it, and in which
// zone". Widening this is Story 1.6's to do, with its own reason.

/// Reads the current time, and the zone it is read in.
abstract interface class Clock {
  /// The current instant, in the local zone.
  ///
  /// Callers that want a calendar day pass this to `Medicine.dateOnly`, which
  /// truncates it in whatever zone it arrives in -- so "today" is the user's
  /// today rather than UTC's.
  DateTime now();

  /// The IANA zone identifier [now] is read in -- for example `Asia/Colombo`.
  ///
  /// AD-6: a Schedule stores a wall-clock time **plus** the zone it was
  /// written in, and never a UTC instant. The zone is part of what the user
  /// said, so it travels with the time rather than being re-read from the
  /// device on every later pass.
  ///
  /// Shaped as `Schedule.isValidIanaTimezone` requires; a Schedule constructed
  /// with anything else throws.
  String get ianaTimezone;
}
