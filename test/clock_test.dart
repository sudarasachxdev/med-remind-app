// The clock seam: the one place that reads "now" and "here".
//
// AD-5 confines every `DateTime.now()` to `lib/platform/clock/`, and AD-9 (as
// amended 2026-09-08) lets the device's IANA zone be read there too. That
// amendment is the reason this file exists: AD-6 makes the zone stored beside a
// Schedule the value Dose resolution later reads back as truth, so the
// difference between "we know the zone" and "we guessed one" has to be a tested
// difference rather than a documented intention.
//
// The platform side is exercised through `flutter_timezone`'s method channel
// rather than behind another port. One more port would let the adapter's own
// unwrapping -- `TimezoneInfo.identifier`, and the abbreviation check -- go
// untested, which is precisely the part that can be wrong.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/app/startup.dart';
import 'package:med_remind_app/domain/port/clock.dart';
import 'package:med_remind_app/platform/clock/system_clock.dart';

const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');

/// Makes the platform answer [reply] to `getLocalTimezone`, or throw when
/// [reply] is null.
void _stubZone(Object? reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_timezoneChannel, (MethodCall call) async {
        expect(call.method, 'getLocalTimezone');
        if (reply == null) {
          throw PlatformException(code: 'UNAVAILABLE');
        }
        return reply;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timezoneChannel, null);
  });

  group('SystemClock', () {
    test('resolves the platform zone and reports it unchanged', () async {
      _stubZone('Asia/Colombo');

      final SystemClock clock = await SystemClock.resolve();

      expect(
        clock.ianaTimezone,
        'Asia/Colombo',
        reason:
            'AD-6 stores this string. Normalising or re-deriving it here would '
            'change what the user said.',
      );
    });

    test('unwraps the identifier, not the localized name', () async {
      // `getLocalTimezone` answers a map on platforms that supply a localized
      // name. Taking the wrong key stores "India Standard Time", which
      // Schedule.isValidIanaTimezone rejects -- and would reject it at save
      // time, in front of the user, rather than here.
      _stubZone(<String, Object?>{
        'identifier': 'Asia/Kolkata',
        'localizedName': 'India Standard Time',
        'locale': 'en_US',
      });

      final SystemClock clock = await SystemClock.resolve();

      expect(clock.ianaTimezone, 'Asia/Kolkata');
    });

    test('rejects an abbreviation rather than storing it', () async {
      // The failure this check exists for: three different zones answer `IST`,
      // so an abbreviation is not a zone. Dart's own `timeZoneName` returns
      // these, which is why it is not used as a fallback anywhere.
      for (final String abbreviation in <String>['IST', '+0530', 'UTC', '']) {
        _stubZone(abbreviation);

        await expectLater(
          SystemClock.resolve(),
          throwsA(isA<ClockZoneUnavailable>()),
          reason: '$abbreviation is not an IANA identifier',
        );
      }
    });

    test('the failure names what the platform actually said', () async {
      _stubZone('IST');

      final ClockZoneUnavailable failure = await SystemClock.resolve().then(
        (_) => throw StateError('should have thrown'),
        onError: (Object e) => e as ClockZoneUnavailable,
      );

      expect(failure.reported, 'IST');
      expect(
        failure.toString(),
        allOf(contains('IST'), contains('AD-6')),
        reason:
            'An abbreviation here tells a very different story from an empty '
            'string, so the log has to carry which one it was.',
      );
    });

    test('now() reads the ambient clock', () async {
      _stubZone('Asia/Colombo');
      final SystemClock clock = await SystemClock.resolve();

      final DateTime before = DateTime.now();
      final DateTime read = clock.now();
      final DateTime after = DateTime.now();

      expect(read.isBefore(before), isFalse);
      expect(read.isAfter(after), isFalse);
    });
  });

  group('UnresolvedZoneClock', () {
    test('answers now() but throws on the zone', () {
      const Clock clock = UnresolvedZoneClock(ClockZoneUnavailable('IST'));

      expect(clock.now(), isA<DateTime>());
      expect(
        () => clock.ianaTimezone,
        throwsA(isA<ClockZoneUnavailable>()),
        reason:
            'The asymmetry is the design: the app launches and Home renders, '
            'and only the one operation that would persist a wrong zone fails.',
      );
    });

    test('carries the original cause to the save site', () {
      const Clock clock = UnresolvedZoneClock(ClockZoneUnavailable('+0530'));

      expect(
        () => clock.ianaTimezone,
        throwsA(
          isA<ClockZoneUnavailable>().having(
            (ClockZoneUnavailable e) => e.reported,
            'reported',
            '+0530',
          ),
        ),
      );
    });
  });

  group('resolveClockAtStartup', () {
    test('returns a resolved clock when the platform answers', () async {
      _stubZone('Europe/Berlin');

      final Clock clock = await resolveClockAtStartup();

      expect(clock, isA<SystemClock>());
      expect(clock.ianaTimezone, 'Europe/Berlin');
    });

    test('falls back without throwing, and surfaces the failure', () async {
      _stubZone(null);

      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final Clock clock = await resolveClockAtStartup();

      expect(
        clock,
        isA<UnresolvedZoneClock>(),
        reason:
            'Refusing to launch over a zone the user may not need today is '
            'worse than launching without it.',
      );
      expect(
        reported,
        isNotEmpty,
        reason:
            'A silent fallback is the dangerous one: the save button would '
            'fail later with nothing upstream explaining why.',
      );
      expect(clock.now(), isA<DateTime>());
      expect(() => clock.ianaTimezone, throwsA(isA<ClockZoneUnavailable>()));
    });

    test('never returns a placeholder zone', () async {
      // The rejected option, asserted so it cannot come back. An earlier draft
      // of this seam defaulted to `Etc/UTC`, which for a user in Asia/Colombo
      // names a different instant -- and Stories 1.6/1.7 would read it as
      // truth. A fallback that ANSWERS the zone is the bug; one that throws is
      // the fix.
      _stubZone(null);

      final Clock clock = await resolveClockAtStartup();

      expect(() => clock.ianaTimezone, throwsA(isA<ClockZoneUnavailable>()));
    });

    test('a stalled platform trips the deadline rather than hanging', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_timezoneChannel, (MethodCall call) async {
            await Future<void>.delayed(const Duration(seconds: 30));
            return 'Asia/Colombo';
          });

      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previous);

      final Clock clock = await resolveClockAtStartup(
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        clock,
        isA<UnresolvedZoneClock>(),
        reason: 'the splash must not wait on a channel that never answers',
      );
    });
  });
}
