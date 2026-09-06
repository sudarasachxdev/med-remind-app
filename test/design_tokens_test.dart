// The design token layer, checked against DESIGN.md.
//
// `_bmad-output/planning-artifacts/ux-designs/ux-medi_tracker-2026-08-24/DESIGN.md`
// is the source of truth for both the names and the values of every token. It
// lives in the planning repository beside this one, so the expected names and
// values below are its frontmatter transcribed a second time, independently of
// `lib/shared/design/`. Two transcriptions that agree are evidence; one is a
// hope.
//
// Two transcriptions in the same repository still drift together, though: edit
// both maps and nothing notices that DESIGN.md now says something else. So the
// frontmatter is also PARSED, from its real path, and checked against the
// expected maps. That test is skipped — loudly, naming what went unverified —
// when the planning repository is not checked out beside this one, because a
// clone of only `med_remind_app` must still be able to run its own suite.
//
// The checks fall into five kinds:
//
//   1. PARITY — every declared token exists, with that exact value, reachable
//      through the barrel. A missing token is caught, and so is an invented
//      one: the set of constants actually declared in each file is read back
//      out of its AST and compared with the expected set, so a token nobody
//      asked for cannot slip in unnoticed.
//   2. DISTINCTNESS — values differ wherever the design distinguishes them.
//      This is what catches a copy-paste duplicate: two tokens with the same
//      value compile, analyse and render, and are wrong.
//   3. UX-DR21 — the only reds in the product are the three state-danger
//      tokens. Checked by hue rather than by name, so a red smuggled in under
//      a neutral name is still caught.
//   4. UX-DR22 — light palette only. No dark variant, no ThemeMode, no
//      brightness branching, and (NFR-5) nothing that overrides the platform
//      text scale.
//   5. SOURCE PARITY — the parsed DESIGN.md frontmatter agrees with the
//      expected maps, so a value changed upstream cannot pass unnoticed.
//
// Every guard runs over `_designFiles()`, which is READ FROM THE FILESYSTEM.
// Do not turn it back into a list: see its doc comment for what that cost.

import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
// One import reaches all four namespaces: if the barrel stops exporting any of
// them this file stops compiling, which is the reachability check.
import 'package:med_remind_app/shared/design/design.dart';

/// The directory `architecture_test.dart` exempts from the colour and metric
/// rules. Everything inside it is granted that exemption.
const _designDirectory = 'lib/shared/design';

const _colorsPath = '$_designDirectory/colors.dart';
const _typographyPath = '$_designDirectory/typography.dart';
const _spacingPath = '$_designDirectory/spacing.dart';
const _barrelPath = '$_designDirectory/design.dart';

/// The files the guards below police: every Dart file under
/// [_designDirectory], read from the filesystem.
///
/// This was a hardcoded four-path list until 2026-09-06, when a reviewer
/// planted `lib/shared/design/theme_probe.dart` holding a `ThemeData`, a
/// `Brightness.dark`, a `Colors.blue`, a `Color(0x...)` literal and a
/// `fontFamily: 'Comic Sans'`. The whole suite passed and `flutter analyze` was
/// clean. The file was INSIDE the exempted directory, so the architecture rule
/// ignored it, and OUTSIDE the hardcoded list, so these guards never looked at
/// it — a hole exactly the shape of a new file.
///
/// The exemption is keyed on a path prefix, so the guards are too. Adding a
/// file to the token layer now automatically subjects it to every check here.
List<String> _designFiles() {
  _expectPackageRoot();

  final directory = Directory(_designDirectory);
  expect(
    directory.existsSync(),
    isTrue,
    reason: '$_designDirectory should exist',
  );

  final files =
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((file) => file.path.replaceAll(r'\', '/'))
          .map((path) {
            final index = path.lastIndexOf('$_designDirectory/');
            return index >= 0 ? path.substring(index) : path;
          })
          .where((path) => path.endsWith('.dart'))
          .toList()
        ..sort();

  // A guard that policed an empty set would pass silently, which is the same
  // failure the hardcoded list had.
  expect(
    files,
    isNotEmpty,
    reason: 'No Dart files found under $_designDirectory',
  );
  return files;
}

/// The path to `DESIGN.md`, which lives in the planning repository beside this
/// one. Absent in a clone of only `med_remind_app`; see the test that reads it.
const _designMarkdownPath =
    '../bmad-medremind/_bmad-output/planning-artifacts/ux-designs/'
    'ux-medi_tracker-2026-08-24/DESIGN.md';

/// `DESIGN.md`'s `colors:` frontmatter, keyed by the lower-camelled name the
/// token layer must use. Transcribe changes here and in `colors.dart`, and let
/// this test tell you if the two disagree.
const Map<String, Color> _expectedColors = {
  // surface-*
  'surfaceApp': Color(0xFFF7F7FB),
  'surfaceRaised': Color(0xFFFFFFFF),
  'surfaceSunken': Color(0xFFFAFAFD),
  'surfaceMuted': Color(0xFFF4F3FA),
  'surfaceInset': Color(0xFFF1F0F7),
  // ink-*
  'inkPrimary': Color(0xFF16161D),
  'inkSecondary': Color(0xFF4A4A5E),
  'inkTertiary': Color(0xFF5D5D75),
  'inkMuted': Color(0xFF8A8AA0),
  'inkFaint': Color(0xFF9A9AAE),
  'inkDisabled': Color(0xFFC2C2D0),
  // accent-*
  'accent': Color(0xFF6C5CE7),
  'accentPressed': Color(0xFF5A48DE),
  'accentWash': Color(0xFFEEEBFE),
  'accentBorder': Color(0xFFC9BFF7),
  // border-*
  'borderHairline': Color(0xFFEDECF5),
  'borderStrong': Color(0xFFE4E3EF),
  // state-*
  'stateTakenTile': Color(0xFFD7F2E1),
  'stateTakenMark': Color(0xFF128047),
  'stateTakenGlyph': Color(0xFF16A34A),
  'stateLateTile': Color(0xFFFBEBD5),
  'stateLateMark': Color(0xFFB0741C),
  'stateLateInk': Color(0xFF8A5A11),
  'stateLateGlyph': Color(0xFFC97C1B),
  'stateInfoTile': Color(0xFFDCEBFB),
  'stateInfoGlyph': Color(0xFF2C7BD4),
  'stateNeutralTile': Color(0xFFEFEFF5),
  // state-danger-* — the only reds in the product (UX-DR21).
  'stateDangerSurface': Color(0xFFFDF0F0),
  'stateDangerSurfacePressed': Color(0xFFFBE4E4),
  'stateDangerInk': Color(0xFFC0392B),
};

/// The three tokens UX-DR21 reserves for FR-3's *Delete medicine* control.
const _dangerColorNames = {
  'stateDangerSurface',
  'stateDangerSurfacePressed',
  'stateDangerInk',
};

/// `DESIGN.md`'s `rounded:` frontmatter.
const Map<String, double> _expectedRadii = {
  'xs': 6,
  'sm': 9,
  'md': 14,
  'lg': 18,
  'xl': 20,
  'pill': 999,
};

/// `DESIGN.md`'s `spacing:` frontmatter, whose keys `1`–`7` become `s1`–`s7`.
const Map<String, double> _expectedSpacing = {
  's1': 4,
  's2': 8,
  's3': 12,
  's4': 16,
  's5': 20,
  's6': 26,
  's7': 34,
};

/// `DESIGN.md`'s `typography:` frontmatter.
///
/// `display` declares only a note — "Platform native — iOS Large Title" — so it
/// pins nothing. `meta` declares the range `13-13.5px`; a constant cannot carry
/// a range, so it takes the lower bound.
///
/// The heading role was a single `26-30px/600` token until 2026-09-06. Measured
/// against the delivered screens, every heading is weight **700** and the role
/// spans 25-34px, so it is now six discrete steps. A single token forced Story
/// 1.2 to the range's lower bound and would have forced Story 1.3 to invent
/// sizes for the onboarding titles on its first day.
const Map<String, TextStyle> _expectedTypography = {
  'display': TextStyle(),
  'figure': TextStyle(fontSize: 38, fontWeight: FontWeight.w700),
  'control': TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
  'headingXl': TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
  'headingLg': TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
  'headingMd': TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
  'headingSm': TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
  'title': TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
  'body': TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
  'meta': TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
  'label': TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
  'chip': TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
};

/// The tokens as the rest of the app reaches them, so parity is checked against
/// the real constants and not against a second copy of the values.
const Map<String, Color> _actualColors = {
  'surfaceApp': MTColors.surfaceApp,
  'surfaceRaised': MTColors.surfaceRaised,
  'surfaceSunken': MTColors.surfaceSunken,
  'surfaceMuted': MTColors.surfaceMuted,
  'surfaceInset': MTColors.surfaceInset,
  'inkPrimary': MTColors.inkPrimary,
  'inkSecondary': MTColors.inkSecondary,
  'inkTertiary': MTColors.inkTertiary,
  'inkMuted': MTColors.inkMuted,
  'inkFaint': MTColors.inkFaint,
  'inkDisabled': MTColors.inkDisabled,
  'accent': MTColors.accent,
  'accentPressed': MTColors.accentPressed,
  'accentWash': MTColors.accentWash,
  'accentBorder': MTColors.accentBorder,
  'borderHairline': MTColors.borderHairline,
  'borderStrong': MTColors.borderStrong,
  'stateTakenTile': MTColors.stateTakenTile,
  'stateTakenMark': MTColors.stateTakenMark,
  'stateTakenGlyph': MTColors.stateTakenGlyph,
  'stateLateTile': MTColors.stateLateTile,
  'stateLateMark': MTColors.stateLateMark,
  'stateLateInk': MTColors.stateLateInk,
  'stateLateGlyph': MTColors.stateLateGlyph,
  'stateInfoTile': MTColors.stateInfoTile,
  'stateInfoGlyph': MTColors.stateInfoGlyph,
  'stateNeutralTile': MTColors.stateNeutralTile,
  'stateDangerSurface': MTColors.stateDangerSurface,
  'stateDangerSurfacePressed': MTColors.stateDangerSurfacePressed,
  'stateDangerInk': MTColors.stateDangerInk,
};

const Map<String, TextStyle> _actualTypography = {
  'display': MTTypography.display,
  'figure': MTTypography.figure,
  'control': MTTypography.control,
  'headingXl': MTTypography.headingXl,
  'headingLg': MTTypography.headingLg,
  'headingMd': MTTypography.headingMd,
  'headingSm': MTTypography.headingSm,
  'title': MTTypography.title,
  'body': MTTypography.body,
  'meta': MTTypography.meta,
  'label': MTTypography.label,
  'chip': MTTypography.chip,
};

const Map<String, double> _actualRadii = {
  'xs': MTRadius.xs,
  'sm': MTRadius.sm,
  'md': MTRadius.md,
  'lg': MTRadius.lg,
  'xl': MTRadius.xl,
  'pill': MTRadius.pill,
};

const Map<String, double> _actualSpacing = {
  's1': MTSpacing.s1,
  's2': MTSpacing.s2,
  's3': MTSpacing.s3,
  's4': MTSpacing.s4,
  's5': MTSpacing.s5,
  's6': MTSpacing.s6,
  's7': MTSpacing.s7,
};

void main() {
  group('colours match the DESIGN.md frontmatter', () {
    test('all 30 declared colours exist with the declared value', () {
      // A count is a deliberate pause, not brittleness — see the typography
      // group for the full reasoning. Bump it when you mean to.
      expect(_expectedColors, hasLength(30));

      for (final entry in _expectedColors.entries) {
        expect(
          _actualColors[entry.key],
          isNotNull,
          reason: 'MTColors.${entry.key} is declared by DESIGN.md',
        );
        expect(
          _actualColors[entry.key],
          equals(entry.value),
          reason:
              'MTColors.${entry.key} does not match the DESIGN.md frontmatter',
        );
      }
    });

    test('nothing undeclared was invented', () {
      // Read back the constants colors.dart actually declares. A token added
      // to the class but not to DESIGN.md fails here, which the map above
      // cannot catch on its own.
      expect(
        _staticMemberNames(_colorsPath, 'MTColors'),
        equals(_expectedColors.keys.toSet()),
        reason:
            'MTColors must declare exactly the 30 colours of the DESIGN.md '
            'frontmatter — no more, no fewer.',
      );
      expect(_actualColors.keys.toSet(), equals(_expectedColors.keys.toSet()));
    });

    test('every colour is distinct — a duplicate is a copy-paste slip', () {
      final byValue = <Color, List<String>>{};
      _actualColors.forEach(
        (name, color) => byValue.putIfAbsent(color, () => []).add(name),
      );

      final duplicates = byValue.entries
          .where((entry) => entry.value.length > 1)
          .map((entry) => entry.value.join(' == '))
          .toList();

      expect(
        duplicates,
        isEmpty,
        reason:
            'DESIGN.md gives all 30 colours different values, so any two that '
            'are equal here are a transcription error: ${duplicates.join('; ')}',
      );
    });
  });

  group('the guarded set is the exempted set', () {
    test('the design files are read from disk, not from a list', () {
      final files = _designFiles();

      expect(
        files,
        containsAll([_colorsPath, _typographyPath, _spacingPath, _barrelPath]),
        reason: 'the four known token files must be among those policed',
      );
      for (final path in files) {
        expect(path, startsWith('$_designDirectory/'));
      }
    });

    test('a file added to the token layer is policed immediately', () {
      // The demonstrated regression: a hardcoded list let
      // lib/shared/design/theme_probe.dart hold a ThemeData, a Brightness.dark,
      // a Colors.blue, a Color(0x...) and a fontFamily while every test passed.
      // The file was inside the exempted directory and outside the list.
      //
      // This plants the same shape, asserts the guards' own predicates see it,
      // and removes it — so the hole cannot reopen by someone rewriting
      // _designFiles() as a constant.
      final probe = File('$_designDirectory/zz_guard_probe.dart');
      addTearDown(() {
        if (probe.existsSync()) probe.deleteSync();
      });

      probe.writeAsStringSync(
        "import 'package:flutter/material.dart';\n"
        '\n'
        'final ThemeData probeTheme = ThemeData(\n'
        '  brightness: Brightness.dark,\n'
        '  primaryColor: Colors.blue,\n'
        ');\n',
      );

      final path = '$_designDirectory/zz_guard_probe.dart';
      expect(
        _designFiles(),
        contains(path),
        reason: 'a new file under the exempted directory must be picked up',
      );
      expect(_namesIn(path), containsAll(['ThemeData', 'Brightness']));
      expect(
        _directiveUris(path),
        contains('package:flutter/material.dart'),
      );

      probe.deleteSync();
      expect(_designFiles(), isNot(contains(path)));
    });
  });

  group('SOURCE PARITY — the expected maps match DESIGN.md itself', () {
    test('the parsed frontmatter agrees with every expected map', () {
      // Both the expected maps and lib/shared/design/ live in THIS repository,
      // so they drift together: edit the two and nothing notices that DESIGN.md
      // now says something else. This is the only check that reads the source
      // of truth.
      final file = File(_designMarkdownPath);
      if (!file.existsSync()) {
        markTestSkipped(
          'DESIGN.md was not found at $_designMarkdownPath, so the expected '
          'maps in this file were NOT verified against the source of truth. '
          'Unverified: 30 colours, 6 radii, 7 spacing steps and 12 type '
          'styles — all still checked against lib/shared/design/, none checked '
          'against DESIGN.md. Check out the planning repository beside this '
          'one to close the gap.',
        );
        return;
      }

      final frontmatter = _frontmatterLines(file);

      final colors = _flatBlock(frontmatter, 'colors').map(
        (key, value) => MapEntry(_lowerCamel(key), _parseHexColor(value)),
      );
      expect(
        colors,
        equals(_expectedColors),
        reason: 'DESIGN.md colors: and _expectedColors disagree',
      );

      final radii = _flatBlock(frontmatter, 'rounded').map(
        (key, value) => MapEntry(_lowerCamel(key), _parsePixels(value)),
      );
      expect(
        radii,
        equals(_expectedRadii),
        reason: 'DESIGN.md rounded: and _expectedRadii disagree',
      );

      // The frontmatter names the spacing steps 1-7; a Dart identifier cannot
      // be a bare digit, so the token layer prefixes each with `s`.
      final spacing = _flatBlock(frontmatter, 'spacing').map(
        (key, value) => MapEntry('s$key', _parsePixels(value)),
      );
      expect(
        spacing,
        equals(_expectedSpacing),
        reason: 'DESIGN.md spacing: and _expectedSpacing disagree',
      );

      final typography = _nestedBlock(frontmatter, 'typography').map(
        (key, value) => MapEntry(_lowerCamel(key), _parseTextStyle(value)),
      );
      expect(
        typography,
        equals(_expectedTypography),
        reason: 'DESIGN.md typography: and _expectedTypography disagree',
      );
    });

    test('the frontmatter parser is not silently returning nothing', () {
      // A parser that found no entries would make every check above pass by
      // comparing two empty maps.
      final file = File(_designMarkdownPath);
      if (!file.existsSync()) {
        markTestSkipped('DESIGN.md not present; parser self-check skipped.');
        return;
      }

      final frontmatter = _frontmatterLines(file);
      expect(_flatBlock(frontmatter, 'colors'), hasLength(30));
      expect(_flatBlock(frontmatter, 'rounded'), hasLength(6));
      expect(_flatBlock(frontmatter, 'spacing'), hasLength(7));
      expect(_nestedBlock(frontmatter, 'typography'), hasLength(12));

      // And the conversions themselves.
      expect(_parseHexColor('#6C5CE7'), const Color(0xFF6C5CE7));
      expect(_parsePixels('14px'), 14);
      expect(_parsePixels('12.5px'), 12.5);
      // A declared range takes its lower bound, as the token layer does.
      expect(_parsePixels('13-13.5px'), 13);
      expect(_lowerCamel('state-danger-surface-pressed'),
          'stateDangerSurfacePressed');
      expect(_lowerCamel('heading-xl'), 'headingXl');
    });
  });

  group('UX-DR21 — red is reserved for deletion', () {
    test('the three danger tokens are the only reds', () {
      final reds = _actualColors.entries
          .where((entry) => _isRed(entry.value))
          .map((entry) => entry.key)
          .toSet();

      expect(
        reds,
        equals(_dangerColorNames),
        reason:
            'Red belongs to FR-3 Delete medicine and nowhere else. An overdue '
            'dose is amber (stateLate*); a skipped dose is neutral '
            '(stateNeutralTile).',
      );
    });

    test('the overdue palette is amber, not red', () {
      for (final name in [
        'stateLateTile',
        'stateLateMark',
        'stateLateInk',
        'stateLateGlyph',
      ]) {
        final hue = _hueDegrees(_actualColors[name]!);
        expect(
          hue,
          inInclusiveRange(25, 55),
          reason: '$name should sit in the amber band, not the red one',
        );
      }
    });

    test('the chroma floor sits between the reds and the off-whites', () {
      // The floor exists to stop a near-grey being judged by its meaningless
      // hue. Pinned rather than asserted in a comment, because the margin is
      // what makes the guard work.
      final leastChromaticRed = _dangerColorNames
          .map((name) => _chroma(_actualColors[name]!))
          .reduce(math.min);

      expect(
        leastChromaticRed,
        greaterThan(_chromaFloor),
        reason:
            'the least chromatic declared red must still clear the floor, or '
            'the UX-DR21 check silently stops seeing it',
      );
      expect(_chroma(MTColors.surfaceRaised), lessThan(_chromaFloor));

      // The false positive the old HSL-saturation floor would have produced:
      // a warm off-white scores saturation 1.0 and hue 0, and would have been
      // reported as a second red.
      expect(_isRed(const Color(0xFFFFF5F5)), isFalse);
      expect(_isRed(const Color(0xFFC0392B)), isTrue);
    });

    test('the danger tokens are named for danger and nothing else is', () {
      final namedDanger = _actualColors.keys
          .where((name) => name.toLowerCase().contains('danger'))
          .toSet();
      expect(namedDanger, equals(_dangerColorNames));
    });
  });

  group('UX-DR22 — a light palette only', () {
    test('no token names a dark or light variant', () {
      // Whole word, not substring. A substring rule reads `borderHighlight` and
      // `inkDarkened` as dark-mode variants and fails a legitimate future
      // token, which is how a guard gets deleted instead of fixed. Token names
      // are lowerCamel, so the words are recoverable exactly.
      final variants =
          [
            ..._actualColors.keys,
            ..._actualTypography.keys,
            ..._actualRadii.keys,
            ..._actualSpacing.keys,
          ].where((name) {
            final words = _camelWords(name);
            return words.contains('dark') || words.contains('light');
          }).toList();

      expect(
        variants,
        isEmpty,
        reason:
            'Dark mode is out of scope for V1. A half-built dark theme is '
            'worse than none: ${variants.join(', ')}',
      );
    });

    test('the variant rule reads words, not substrings', () {
      // Pins the distinction above, so the rule cannot be quietly narrowed to
      // a substring match again — or widened until it fails honest names.
      expect(_camelWords('surfaceAppDark'), contains('dark'));
      expect(_camelWords('darkSurface'), contains('dark'));
      expect(_camelWords('lightModeOnly'), contains('light'));
      expect(_camelWords('borderHighlight'), isNot(contains('light')));
      expect(_camelWords('inkDarkened'), isNot(contains('dark')));
      expect(_camelWords('accentWash'), isNot(contains('dark')));
    });

    test('the design layer never mentions a theme, a brightness or a scaler', () {
      // AST-based, so the words may appear in the prose above a token without
      // failing — only a real reference to one of these APIs does. Type
      // annotations, constructor names and named-argument labels all count:
      // `Brightness b;`, `const ThemeData()` and `fontFamily:` each name
      // something through a Token rather than an identifier.
      const banned = {
        'Brightness',
        'ThemeMode',
        'ThemeData',
        'ColorScheme',
        'CupertinoThemeData',
        'MediaQuery',
        'TextScaler',
        'textScaler',
        'textScaleFactor',
        'MaterialApp',
        'Widget',
        'StatelessWidget',
        'StatefulWidget',
        'BuildContext',
        'fontFamily',
        'fontFamilyFallback',
        // Flutter's ready-made palettes. `Color` itself is how this layer is
        // written, but the token layer transcribes DESIGN.md's hex values and
        // has no more business reaching into Flutter's palette than a widget
        // does — and inside this directory the architecture rule's colour
        // exemption means nothing else would say so.
        'Colors',
        'CupertinoColors',
        'MaterialColor',
        'ColorSwatch',
        'HSLColor',
        'HSVColor',
      };

      for (final path in _designFiles()) {
        final found = _namesIn(path).intersection(banned);
        expect(
          found,
          isEmpty,
          reason:
              '$path references ${found.join(', ')}. This story ships values: '
              'no theme, no brightness branching, no widget, and nothing that '
              'overrides the platform text scale (NFR-5). The composition root '
              'is Story 1.3\'s.',
        );
      }
    });

    test('the design layer imports painting only, never material', () {
      for (final path in _designFiles()) {
        for (final uri in _directiveUris(path)) {
          expect(
            uri,
            isNot('<non-literal>'),
            reason: '$path has a directive whose URI is not a plain literal',
          );

          if (uri.startsWith('package:') || uri.startsWith('dart:')) {
            expect(
              uri,
              equals('package:flutter/painting.dart'),
              reason:
                  '$path pulls in $uri. Painting carries Color and TextStyle; '
                  'material would carry ThemeData and the Colors palette too.',
            );
            continue;
          }

          // A relative import or part must stay inside the token layer.
          // Otherwise a `part '../../features/theme.dart'` puts arbitrary code
          // inside an exempted library while living outside the guarded
          // directory.
          expect(
            _resolveRelative(path, uri),
            startsWith('$_designDirectory/'),
            reason:
                '$path reaches outside the token layer through "$uri". Every '
                'file the exemption covers must be inside the directory the '
                'exemption names.',
          );
        }
      }
    });

    test('the relative-URI resolver actually resolves', () {
      // The check above is only as good as this.
      expect(
        _resolveRelative('$_designDirectory/design.dart', 'colors.dart'),
        '$_designDirectory/colors.dart',
      );
      expect(
        _resolveRelative('$_designDirectory/design.dart', './colors.dart'),
        '$_designDirectory/colors.dart',
      );
      expect(
        _resolveRelative('$_designDirectory/design.dart', '../../features/x.dart'),
        'lib/features/x.dart',
      );
    });

    test('the surfaces are light and the primary ink is dark', () {
      // Non-vacuous evidence that the one palette shipped is the light one,
      // measured as WCAG relative luminance rather than a channel average.
      const surfaces = [
        'surfaceApp',
        'surfaceRaised',
        'surfaceSunken',
        'surfaceMuted',
        'surfaceInset',
      ];
      const inks = [
        'inkPrimary',
        'inkSecondary',
        'inkTertiary',
        'inkMuted',
        'inkFaint',
        'inkDisabled',
      ];

      for (final name in surfaces) {
        expect(
          _relativeLuminance(_actualColors[name]!),
          greaterThan(0.8),
          reason: '$name is a light-palette surface',
        );
      }
      expect(_relativeLuminance(MTColors.inkPrimary), lessThan(0.05));

      // The structural claim, independent of any threshold: in a light palette
      // every ink is darker than every surface. Inverting the palette for dark
      // mode would break this before it broke anything else.
      final darkestSurface = surfaces
          .map((name) => _relativeLuminance(_actualColors[name]!))
          .reduce(math.min);
      final lightestInk = inks
          .map((name) => _relativeLuminance(_actualColors[name]!))
          .reduce(math.max);
      expect(
        lightestInk,
        lessThan(darkestSurface),
        reason: 'ink must sit on surfaces, not the other way round',
      );
    });
  });

  group('typography', () {
    test('every declared type style exists with the declared value', () {
      // The count is a deliberate tripwire, not brittleness. The expected map
      // lives in this file, so key-set equality alone passes when someone edits
      // both maps together; only the literal count forces a conscious pause.
      // It earned that on 2026-09-06, when it failed and made the heading-scale
      // change an explicit decision rather than a silent one. Bump it only when
      // you mean to.
      expect(_expectedTypography, hasLength(12));

      expect(
        _actualTypography.keys.toSet(),
        equals(_expectedTypography.keys.toSet()),
        reason: 'the expected and actual typography maps have drifted apart',
      );

      for (final entry in _expectedTypography.entries) {
        expect(
          _actualTypography[entry.key],
          equals(entry.value),
          reason:
              'MTTypography.${entry.key} does not match the DESIGN.md '
              'frontmatter',
        );
      }
      expect(
        _staticMemberNames(_typographyPath, 'MTTypography'),
        equals(_expectedTypography.keys.toSet()),
      );
    });

    test('every style is distinct', () {
      expect(
        _actualTypography.values.toSet(),
        hasLength(_actualTypography.length),
      );
    });

    test('no style pins a face, a colour or a line height', () {
      // Platform-native faces (SF Pro / Roboto) and Dynamic Type both depend on
      // this layer NOT setting these: a fontFamily replaces the platform face,
      // and a fixed height stops a scaled line from growing.
      _actualTypography.forEach((name, style) {
        expect(style.fontFamily, isNull, reason: '$name pins a font family');
        expect(style.height, isNull, reason: '$name pins a line height');
        expect(style.color, isNull, reason: '$name pins a colour');
        expect(
          style.fontFamilyFallback,
          isNull,
          reason: '$name pins a fallback face',
        );
      });
    });

    test('display declares nothing, because DESIGN.md declares nothing', () {
      expect(MTTypography.display.fontSize, isNull);
      expect(MTTypography.display.fontWeight, isNull);
    });

    test('the sized styles carry a positive base size', () {
      // A base size, not a fixed one: Flutter multiplies it by the ambient
      // TextScaler, which follows the OS text size setting (NFR-5).
      for (final entry in _actualTypography.entries) {
        if (entry.key == 'display') continue;
        expect(entry.value.fontSize, isNotNull, reason: entry.key);
        expect(entry.value.fontSize, greaterThan(0), reason: entry.key);
      }
    });

    test('no font is bundled and no font package is depended on', () {
      _expectPackageRoot();

      // Comments stripped first, so a commented-out `# fonts:` — pubspec.yaml
      // ships with several — is not read as a declaration, and a real
      // `fonts:   # bundled faces` is not missed because of its trailing
      // comment. Safe here because this file's only `#` are comment markers.
      final declarations = File('pubspec.yaml')
          .readAsLinesSync()
          .map((line) => line.split('#').first.trimRight())
          .toList();

      final bundled = declarations
          .where((line) => RegExp(r'^\s+fonts\s*:').hasMatch(line))
          .toList();
      expect(
        bundled,
        isEmpty,
        reason:
            'DESIGN.md is platform-native throughout: no custom faces. '
            'Found: ${bundled.join(' | ')}',
      );

      // A bundled face is not the only way to replace the platform stack.
      final fontPackages = declarations
          .where(
            (line) => RegExp(
              r'^\s+(google_fonts|flutter_native_fonts|auto_size_text)\s*:',
            ).hasMatch(line),
          )
          .toList();
      expect(
        fontPackages,
        isEmpty,
        reason:
            'A font package overrides the platform face just as surely as a '
            'bundled one. Found: ${fontPackages.join(' | ')}',
      );
    });
  });

  group('radius and spacing scales', () {
    test('all 6 radii exist with the declared value', () {
      // A count is a deliberate pause, not brittleness: the expected map lives
      // in this file, so key-set equality alone passes when someone edits both
      // maps together. Only the literal count forces the change to be a
      // decision. Bump it when you mean to.
      expect(_expectedRadii, hasLength(6));
      expect(_actualRadii.keys.toSet(), equals(_expectedRadii.keys.toSet()));

      for (final entry in _expectedRadii.entries) {
        expect(
          _actualRadii[entry.key],
          equals(entry.value),
          reason: 'MTRadius.${entry.key}',
        );
      }
      expect(
        _staticMemberNames(_spacingPath, 'MTRadius'),
        equals(_expectedRadii.keys.toSet()),
      );
    });

    test('all 7 spacing steps exist with the declared value', () {
      // As above: a count is a deliberate pause, not brittleness.
      expect(_expectedSpacing, hasLength(7));
      expect(_actualSpacing.keys.toSet(), equals(_expectedSpacing.keys.toSet()));

      for (final entry in _expectedSpacing.entries) {
        expect(
          _actualSpacing[entry.key],
          equals(entry.value),
          reason: 'MTSpacing.${entry.key}',
        );
      }
      expect(
        _staticMemberNames(_spacingPath, 'MTSpacing'),
        equals(_expectedSpacing.keys.toSet()),
      );
    });

    test('both scales are distinct and strictly increasing', () {
      // A scale with a duplicate step is a scale with a hole in it: 14 and 16
      // stop being different decisions.
      for (final scale in [_actualRadii, _actualSpacing]) {
        final values = scale.values.toList();
        expect(values.toSet(), hasLength(values.length));
        for (var i = 1; i < values.length; i++) {
          expect(
            values[i],
            greaterThan(values[i - 1]),
            reason: 'the scale is declared in ascending order',
          );
        }
      }
    });

    test('nothing is square-cornered', () {
      for (final entry in _actualRadii.entries) {
        expect(entry.value, greaterThan(0), reason: 'MTRadius.${entry.key}');
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// The names of the static MEMBERS declared by [className] in [path] — fields
/// and getters alike.
///
/// Read from the AST rather than from a hand-kept list, so a constant added to
/// the class shows up here whether or not anyone remembered this test.
///
/// Getters are included because `static Color get brandRed => const Color(...)`
/// is a token by every measure that matters — it is reachable as
/// `MTColors.brandRed`, it renders, and it is undeclared — while being a
/// MethodDeclaration rather than a FieldDeclaration. Reading fields only left
/// exactly that shape unpoliced.
Set<String> _staticMemberNames(String path, String className) {
  final names = <String>{};

  for (final declaration in _unitOf(path).declarations) {
    if (declaration is! ClassDeclaration) continue;
    // analyzer 13 moved the class name behind `namePart` and the members
    // behind `body`, to make room for primary constructors.
    if (declaration.namePart.typeName.lexeme != className) continue;

    for (final member in declaration.body.members) {
      if (member is FieldDeclaration && member.isStatic) {
        for (final variable in member.fields.variables) {
          names.add(variable.name.lexeme);
        }
      } else if (member is MethodDeclaration &&
          member.isStatic &&
          member.isGetter) {
        names.add(member.name.lexeme);
      }
    }
  }

  expect(
    names,
    isNotEmpty,
    reason: 'No static members found for $className in $path',
  );
  return names;
}

/// Every name referenced by [path], comments and strings excluded.
///
/// Covers type annotations and constructor names as well as plain identifiers:
/// `Brightness b;` and `const ThemeData()` name a type through a NamedType,
/// whose name is a Token rather than a SimpleIdentifier, so an
/// identifier-only walk saw neither.
Set<String> _namesIn(String path) {
  final collector = _NameCollector();
  _unitOf(path).accept(collector);
  return collector.names;
}

/// The URIs of every import, export and part directive in [path], including the
/// alternatives of a configured import.
///
/// A conditional import (`import 'a.dart' if (dart.library.io) 'b.dart';`) can
/// smuggle in a library the plain URI never names, and `part` pulls in a whole
/// second file that the guards would otherwise never see.
List<String> _directiveUris(String path) {
  final uris = <String>[];

  void add(StringLiteral literal) =>
      uris.add(literal.stringValue ?? '<non-literal>');

  for (final directive in _unitOf(path).directives) {
    if (directive is NamespaceDirective) {
      add(directive.uri);
      for (final configuration in directive.configurations) {
        add(configuration.uri);
      }
    } else if (directive is PartDirective) {
      add(directive.uri);
    }
  }
  return uris;
}

/// Resolves a relative [uri] written inside [fromPath] to a package-relative
/// path, so it can be checked against the design directory.
String _resolveRelative(String fromPath, String uri) {
  final segments = <String>[
    ...fromPath.split('/')..removeLast(),
    ...uri.split('/'),
  ];

  final resolved = <String>[];
  for (final segment in segments) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
      continue;
    }
    resolved.add(segment);
  }
  return resolved.join('/');
}

CompilationUnit _unitOf(String path) {
  _expectPackageRoot();

  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path should exist');

  final result = parseString(
    content: file.readAsStringSync(),
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  expect(result.errors, isEmpty, reason: '$path did not parse');
  return result.unit;
}

// ---------------------------------------------------------------------------
// DESIGN.md frontmatter.
//
// A deliberately small, strict reader for the subset of YAML the frontmatter
// uses — two indent levels, scalar values, no lists, no anchors, no multi-line
// strings. It is not a YAML parser and must not become one: adding a package
// dependency to a test is an "Ask First" decision, and every shape it does not
// understand is rejected loudly rather than skipped, so a frontmatter that
// grows past this subset fails the test instead of silently under-checking.
// ---------------------------------------------------------------------------

/// The lines between the opening and closing `---` fences of [file].
List<String> _frontmatterLines(File file) {
  final lines = file.readAsLinesSync();
  expect(
    lines.isNotEmpty && lines.first.trim() == '---',
    isTrue,
    reason: '${file.path} does not open with a --- frontmatter fence',
  );

  final end = lines.indexOf('---', 1);
  expect(
    end,
    greaterThan(0),
    reason: '${file.path} has an unterminated frontmatter block',
  );
  return lines.sublist(1, end);
}

/// The `key: value` entries two spaces under [blockName].
Map<String, String> _flatBlock(List<String> frontmatter, String blockName) {
  final entries = <String, String>{};

  for (final line in _blockBody(frontmatter, blockName)) {
    final match = RegExp(r'^  ([^:]+):[ \t]*(.+)$').firstMatch(line);
    expect(
      match,
      isNotNull,
      reason: '$blockName: holds a line this reader does not understand: $line',
    );
    entries[_unquote(match!.group(1)!)] = _unquote(match.group(2)!.trim());
  }

  return entries;
}

/// The nested `key:` / `  child: value` entries under [blockName].
Map<String, Map<String, String>> _nestedBlock(
  List<String> frontmatter,
  String blockName,
) {
  final entries = <String, Map<String, String>>{};
  String? current;

  for (final line in _blockBody(frontmatter, blockName)) {
    final key = RegExp(r'^  ([^:]+):[ \t]*$').firstMatch(line);
    if (key != null) {
      current = _unquote(key.group(1)!);
      entries[current] = <String, String>{};
      continue;
    }

    final child = RegExp(r'^    ([^:]+):[ \t]*(.+)$').firstMatch(line);
    expect(
      child != null && current != null,
      isTrue,
      reason: '$blockName: holds a line this reader does not understand: $line',
    );
    entries[current!]![_unquote(child!.group(1)!)] = _unquote(
      child.group(2)!.trim(),
    );
  }

  return entries;
}

/// The indented lines belonging to the top-level key [blockName].
List<String> _blockBody(List<String> frontmatter, String blockName) {
  final body = <String>[];
  var inside = false;

  for (final line in frontmatter) {
    if (line == '$blockName:') {
      inside = true;
      continue;
    }
    if (!inside) continue;
    // The next top-level key ends the block.
    if (line.isNotEmpty && !line.startsWith(' ')) break;
    if (line.trim().isEmpty) continue;
    body.add(line);
  }

  expect(body, isNotEmpty, reason: 'no $blockName: block in the frontmatter');
  return body;
}

String _unquote(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 &&
      (trimmed.startsWith("'") && trimmed.endsWith("'") ||
          trimmed.startsWith('"') && trimmed.endsWith('"'))) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

/// `#RRGGBB` as an opaque [Color], which is the mechanical mapping the token
/// layer performs.
Color _parseHexColor(String value) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(value);
  expect(match, isNotNull, reason: 'not a #RRGGBB colour: $value');
  return Color(int.parse('FF${match!.group(1)!}', radix: 16));
}

/// `14px`, `12.5px`, or a declared range like `13-13.5px`, whose LOWER BOUND is
/// taken — a constant cannot carry a range, and inventing a second token for
/// the upper bound would invent a name DESIGN.md does not declare.
double _parsePixels(String value) {
  final match = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)(?:-[0-9]+(?:\.[0-9]+)?)?px$',
  ).firstMatch(value);
  expect(match, isNotNull, reason: 'not a px measurement: $value');
  return double.parse(match!.group(1)!);
}

/// One `typography:` entry as a [TextStyle].
///
/// A `note` is documentation and carries no value. An entry with neither a size
/// nor a weight — `display` — becomes an empty style, which is exactly what the
/// token layer declares for it.
TextStyle _parseTextStyle(Map<String, String> entry) {
  const known = {'size', 'weight', 'note'};
  final unknown = entry.keys.toSet().difference(known);
  expect(
    unknown,
    isEmpty,
    reason: 'unhandled typography attribute(s): ${unknown.join(', ')}',
  );

  final size = entry['size'];
  final weight = entry['weight'];
  return TextStyle(
    fontSize: size == null ? null : _parsePixels(size),
    fontWeight: weight == null ? null : _parseFontWeight(weight),
  );
}

FontWeight _parseFontWeight(String value) {
  final weight = int.tryParse(value);
  expect(weight, isNotNull, reason: 'not a font weight: $value');
  expect(
    weight! % 100 == 0 && weight >= 100 && weight <= 900,
    isTrue,
    reason: 'not one of the nine Flutter font weights: $value',
  );
  return FontWeight.values[weight ~/ 100 - 1];
}

/// `surface-app` -> `surfaceApp`, the mechanical mapping the token layer uses.
String _lowerCamel(String key) {
  final parts = key.split('-');
  return parts.first +
      parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? part
                : part[0].toUpperCase() + part.substring(1),
          )
          .join();
}

/// The words of a lowerCamel identifier: `surfaceAppDark` -> surface, app,
/// dark.
Set<String> _camelWords(String name) => name
    .replaceAllMapped(RegExp('([A-Z])'), (match) => ' ${match.group(1)}')
    .toLowerCase()
    .split(' ')
    .where((word) => word.isNotEmpty)
    .toSet();

/// Fails with a message naming the working directory, rather than with an
/// obscure missing-file error, when the suite is run from anywhere but the
/// package root.
void _expectPackageRoot() {
  expect(
    Directory('lib').existsSync(),
    isTrue,
    reason:
        'Expected to run from the package root, with lib/ present. '
        'Working directory is ${Directory.current.path}.',
  );
}

class _NameCollector extends RecursiveAstVisitor<void> {
  final Set<String> names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    names.add(node.name.lexeme);
    final prefix = node.importPrefix;
    if (prefix != null) names.add(prefix.name.lexeme);
    super.visitNamedType(node);
  }

  /// The label of a named argument — `fontFamily` in
  /// `TextStyle(fontFamily: 'Comic Sans')` — which is a Token like a NamedType
  /// name and was missed for the same reason. A banned-argument name is how a
  /// face gets pinned, so it has to be visible here.
  @override
  void visitNamedArgument(NamedArgument node) {
    names.add(node.name.lexeme);
    super.visitNamedArgument(node);
  }
}

/// The least chroma a colour may have and still be judged by its hue.
///
/// Chroma, not HSL saturation. Saturation divides by lightness, so a near-white
/// like `#FDF0F0` scores 0.76 — meaning a floor expressed in saturation never
/// excluded anything, and would have flagged any warm off-white a later story
/// added as "red". Chroma is the plain span between the channels, so an
/// off-white reads as barely chromatic, which is what the floor is trying to
/// say.
///
/// `#FDF0F0`, `state-danger-surface`, is the least chromatic red the design
/// declares, at 0.051. The floor sits below it with margin and well above the
/// achromatic surfaces. A test pins that relationship rather than leaving it to
/// this comment.
const _chromaFloor = 0.04;

/// Whether [color] reads as red: in the red hue band and chromatic enough for
/// the hue to mean anything.
bool _isRed(Color color) {
  if (_chroma(color) < _chromaFloor) return false;
  final hue = _hueDegrees(color);
  return hue < 25 || hue >= 345;
}

/// The span between the strongest and weakest channel: 0 for any grey, 1 for a
/// fully saturated primary.
double _chroma(Color color) {
  final maximum = math.max(color.r, math.max(color.g, color.b));
  final minimum = math.min(color.r, math.min(color.g, color.b));
  return maximum - minimum;
}

double _hueDegrees(Color color) {
  final r = color.r;
  final g = color.g;
  final b = color.b;
  final maximum = math.max(r, math.max(g, b));
  final minimum = math.min(r, math.min(g, b));
  final delta = maximum - minimum;
  if (delta == 0) return 0;

  final double hue;
  if (maximum == r) {
    hue = 60 * (((g - b) / delta) % 6);
  } else if (maximum == g) {
    hue = 60 * (((b - r) / delta) + 2);
  } else {
    hue = 60 * (((r - g) / delta) + 4);
  }
  return hue < 0 ? hue + 360 : hue;
}

/// WCAG relative luminance: sRGB channels linearised, then weighted for how
/// much each contributes to perceived brightness.
///
/// A plain channel average is not luminance — it treats a blue and a green of
/// the same numeric value as equally bright, when green is roughly ten times
/// the contributor blue is. Since this is the only evidence the shipped palette
/// is the LIGHT one, it should be the real quantity.
double _relativeLuminance(Color color) =>
    0.2126 * _linearise(color.r) +
    0.7152 * _linearise(color.g) +
    0.0722 * _linearise(color.b);

double _linearise(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
