// Enforcement for two architecture decisions that decay silently otherwise:
//
//   AD-1 — the domain is pure Dart. No file under lib/domain/ may import a
//          package (other than package:meta) or a platform-bound dart:
//          library.
//   AD-5 — time is injected. DateTime.now(), DateTime.timestamp() and
//          TZDateTime.now() appear only in the clock adapter under
//          lib/platform/clock/.
//   TOKENS — the design scales are tokens. A literal colour appears only under
//          lib/shared/design/: a Color constructor in any of its forms
//          (including a Dart 3.10 dot shorthand), a member of Flutter's Colors
//          or CupertinoColors palettes, a MaterialColor or ColorSwatch, or an
//          HSLColor/HSVColor conversion — every route to a colour, not only
//          the ones spelled `Color`. Colors.transparent is exempt: it
//          expresses absence, not a brand decision. The same rule covers the
//          three other scales DESIGN.md declares — a bare number in a
//          `fontSize:`, in a BorderRadius/Radius, or in an EdgeInsets is a
//          type, radius or spacing decision taken by feel. Without this, each
//          screen invents its own literals and the design contract decays into
//          twenty slightly different violets and four kinds of 14px.
//
// It also pins two structural acceptance criteria that are otherwise only ever
// checked by eye: the shape of the directory tree under lib/, and that
// placeholders are .gitkeep rather than .dart. Both were originally scoped to
// the frozen tree Story 1.1 left behind; Story 1.2 re-specifies them to a rule
// that admits growth — see the reason recorded in the last group of main().
//
// This is a test, not an analyzer plugin, and not a grep.
//
// Not an analyzer plugin: on Flutter 3.44.8 / Dart 3.12.2 `flutter analyze`
// silently ignores plugin diagnostics (it exits 0 where `dart analyze` exits
// 3), and `errors:` severity promotion does not apply to plugin diagnostic
// codes. A test is the only mechanism here that actually fails a build.
//
// Not a grep: the literal text `DateTime.now()` inside a comment or a string
// is not a violation, and no text match can tell the difference. Every check
// below runs over a parsed AST.
//
// ---------------------------------------------------------------------------
// Note on the AST. Re-verified empirically against analyzer 13.0.0 on
// 2026-09-04 (first measured on 12.1.0; the shapes are unchanged between the
// two). `parseString` produces an UNRESOLVED AST, so the parser cannot know
// whether `DateTime.now` names a constructor, a static method or a static
// getter. The same call therefore lands in four different node kinds
// depending on how it is written:
//
//   DateTime.now()             MethodInvocation            target=DateTime
//   tz.TZDateTime.now(loc)     MethodInvocation            target=tz.TZDateTime
//   new DateTime.now()         InstanceCreationExpression  prefix=DateTime, type=now
//   new tz.TZDateTime.now(l)   InstanceCreationExpression  prefix=tz, type=TZDateTime, name=now
//   final f = DateTime.now;    PrefixedIdentifier          prefix=DateTime, id=now
//   final f = tz.TZDateTime.now; PropertyAccess            target=tz.TZDateTime, prop=now
//
// All four kinds are handled. A visitor that handles one of them silently
// passes every violation written in any of the other forms — which is the
// failure this file exists to prevent, so do not "simplify" the visitor down
// to a single override. Every shape above is pinned by a test below.
//
// This story's Boundaries -- frozen, so still uncorrected -- say
// `DateTime.now()` parses as an InstanceCreationExpression and that a
// MethodInvocation visitor misses everything. Measured, the reverse holds for
// the bare form: only the explicit `new` form is an InstanceCreationExpression.
// The warning was right in substance and wrong about which node. The spine's
// AD-5 note was corrected on 2026-09-03 and now matches this file. The
// Boundaries also say `parseFile`; this file uses `parseString` so the same
// checks run over synthetic sources in a test, without touching the
// filesystem.
//
// The same ambiguity governs the colour rule. Measured against analyzer 13.0.0
// on 2026-09-06:
//
//   Color(0xFF6C5CE7)          MethodInvocation            target=null, name=Color
//   ui.Color(0xFF6C5CE7)       MethodInvocation            target=ui,   name=Color
//   Color.fromARGB(a,r,g,b)    MethodInvocation            target=Color, name=fromARGB
//   const Color(0xFF6C5CE7)    InstanceCreationExpression  type=Color
//   const Color.fromARGB(...)  InstanceCreationExpression  prefix=Color, type=fromARGB
//   const ui.Color.fromARGB()  InstanceCreationExpression  prefix=ui, type=Color, name=fromARGB
//   Colors.red                 PrefixedIdentifier          prefix=Colors, id=red
//   m.Colors.red               PropertyAccess              target=m.Colors, prop=red
//
// This story's Design Notes say to flag Color(...) as an
// InstanceCreationExpression. Measured, the BARE form is a MethodInvocation and
// only the const/new forms are InstanceCreationExpressions — the same
// correction the AD-5 paragraph above records, for the same reason: an
// unresolved parser cannot tell a constructor from a function call. Both kinds
// are handled and every shape above is pinned by a test below. A visitor
// covering only the node kind the Design Notes name would pass `Color(0x...)`
// written the ordinary way, which is the one form that actually appears.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// The only `package:` prefix a domain file may import (AD-1).
const _domainAllowedPackagePrefix = 'package:meta/';

/// `dart:` libraries that bind the domain to a platform, and so are banned by
/// AD-1. Other `dart:` core libraries (`dart:async`, `dart:math`,
/// `dart:collection`, `dart:convert`, ...) are pure and stay permitted.
const _domainBannedDartLibraries = {
  'dart:io',
  'dart:ui',
  'dart:ffi',
  'dart:isolate',
  'dart:mirrors',
  'dart:js_interop',
  'dart:html',
};

/// Types whose `now`/`timestamp` members read the ambient clock (AD-5).
const _ambientClockTypes = {'DateTime', 'TZDateTime'};

/// Members of those types that read the ambient clock (AD-5).
const _ambientClockMembers = {'now', 'timestamp'};

/// Suffixes of generated sources, which are excluded from the walk.
///
/// From Story 1.4 `drift_dev` writes `lib/data/db/*.g.dart`. A violation in
/// generated output cannot be fixed by editing the file, so scanning it would
/// turn a generator's output into an unfixable red suite. The generator's
/// *input* is hand-written and is still scanned.
const _generatedDartSuffixes = ['.g.dart', '.freezed.dart'];

/// The one directory allowed to name a colour (TOKENS).
///
/// `DESIGN.md`'s frontmatter is transcribed here and nowhere else, so this is
/// the only place a `Color(0x...)` may appear.
const _designTokenDirectory = 'lib/shared/design/';

/// Flutter's colour type. Every constructor of it produces a literal colour.
const _colorClass = 'Color';

/// Types that ARE a source of colour: every member of one of these is a
/// colour, and constructing one produces a colour.
///
/// Naming only `Color` and `Colors` missed every other route into the palette.
/// A reviewer demonstrated the gap with
/// `HSLColor.fromAHSL(1, 260, 0.7, 0.6).toColor()`, which is a violet arrived
/// at the long way round and was not flagged. `CupertinoColors` matters here in
/// particular: `cupertino_icons` is already a dependency and DESIGN.md is an
/// explicitly iOS design, so it is the palette most likely to be reached for.
const _paletteClasses = {
  'Colors',
  'CupertinoColors',
  'MaterialColor',
  'ColorSwatch',
  'HSLColor',
  'HSVColor',
};

/// The named constructors of [_colorClass].
///
/// The unnamed `Color(0x...)` is matched separately, by the class name alone.
/// `Color.lerp` is deliberately absent: it composes two colours that must
/// themselves already be tokens, so it names no colour of its own.
const _colorConstructors = {'fromARGB', 'fromRGBO', 'from'};

/// Dot-shorthand member names that can only be a colour factory.
///
/// Dart 3.10 shorthands (`Color c = .fromARGB(255, 108, 92, 231);`) are enabled
/// by this package's `sdk: ^3.12.2`. An unresolved AST cannot see the context
/// type, so the member name is all there is to go on: these four exist on no
/// other common type. `from` is deliberately NOT here even though
/// `Color.from` is a constructor — `.from(...)` is equally `List.from`,
/// `Set.from` or `Map.from`, and flagging it would fail honest code.
const _colorShorthandConstructors = {
  'fromARGB',
  'fromRGBO',
  'fromAHSL',
  'fromAHSV',
};

/// Members of a palette class that carry no brand decision.
///
/// `Colors.transparent` expresses absence — there is no token for "no colour"
/// and inventing one would say less than the Flutter constant does.
const _paletteExemptMembers = {'transparent'};

/// Types whose numeric arguments are radius or spacing decisions.
///
/// DESIGN.md is as much the source of truth for `rounded:` and `spacing:` as it
/// is for `colors:`, and `MTRadius`/`MTSpacing` exist so that 14 and 16 are
/// never chosen by feel — a guarantee nothing enforced while the rule was
/// colour-only.
const _metricClasses = {
  'BorderRadius',
  'BorderRadiusDirectional',
  'Radius',
  'EdgeInsets',
  'EdgeInsetsDirectional',
};

/// Named arguments whose numeric literal is a type-scale decision.
const _metricNamedArguments = {'fontSize'};

/// The one numeric literal that carries no design decision.
///
/// Zero is the metric equivalent of `Colors.transparent`: `EdgeInsets.only(top:
/// 0)` expresses absence, and there is no token for "no space".
const _exemptMetricLiteral = 0;

/// The directories of the spine's Structural Seed, relative to `lib/`.
///
/// Every one of these must exist. They are the floor, not the ceiling: see
/// [_libraryRoots], [_closedLayerSubdirectories] and [_openLayers] for what may
/// be added alongside them.
const _spineDirectories = <String>[
  'app',
  'data',
  'data/db',
  'data/repository',
  'domain',
  'domain/model',
  'domain/policy',
  'domain/port',
  'domain/service',
  'features',
  'platform',
  'platform/clock',
  'platform/notifications',
  'platform/permissions',
  'platform/timezone',
  'shared',
];

/// The only directories that may sit directly under `lib/`.
///
/// An invented top-level layer — `lib/services/`, `lib/utils/`, `lib/core/` —
/// is the failure this pins. The hexagonal layout has six roots and gains no
/// seventh without an architecture decision.
const _libraryRoots = <String>{
  'app',
  'data',
  'domain',
  'features',
  'platform',
  'shared',
};

/// The layers whose subdirectory set is closed, mapped to that exact set.
///
/// `domain/`, `data/` and `platform/` are the spine's shape: a new subdirectory
/// under one of them is a new architectural concept, not a new file, and should
/// not arrive as a side effect of a story.
const _closedLayerSubdirectories = <String, Set<String>>{
  'data': {'db', 'repository'},
  'domain': {'model', 'policy', 'port', 'service'},
  'platform': {'clock', 'notifications', 'permissions', 'timezone'},
};

/// The layers that may grow freely. This is where stories add code.
///
/// `features/` gains a directory per screen and `shared/` a directory per
/// cross-cutting concern — `shared/design/` is this story's.
const _openLayers = <String>{'features', 'shared'};

/// Applies both architecture rules to one file's source text.
///
/// Split out from the tree walk so that every row of the spec's I/O matrix —
/// including the failure rows — is covered by a permanent test over synthetic
/// sources, rather than by planting violations in the real tree and deleting
/// them afterwards. A check verified only by planting is a check nothing stops
/// from regressing.
List<String> architectureViolationsForSource({
  required String relativePath,
  required String source,
}) {
  final violations = <String>[];

  final result = parseString(
    content: source,
    path: relativePath,
    featureSet: FeatureSet.latestLanguageVersion(),
    // Parse errors are reported as violations naming the file rather than
    // thrown, because the thrown ArgumentError does not name the file and it
    // aborts the walk before the remaining files are checked.
    throwIfDiagnostics: false,
  );

  if (result.errors.isNotEmpty) {
    for (final diagnostic in result.errors) {
      final location = result.lineInfo.getLocation(diagnostic.offset);
      violations.add(
        '$relativePath:${location.lineNumber}:${location.columnNumber} '
        'did not parse: ${diagnostic.message}',
      );
    }
    // An unparseable file has no trustworthy AST; do not also report whatever
    // the partial tree happens to contain.
    return violations;
  }

  final unit = result.unit;

  if (_isUnder(relativePath, 'lib/domain/')) {
    violations.addAll(_domainPurityViolations(unit, relativePath));
  }

  if (!_isUnder(relativePath, 'lib/platform/clock/')) {
    unit.accept(
      _AmbientClockVisitor(
        relativePath: relativePath,
        lineInfo: result.lineInfo,
        violations: violations,
      ),
    );
  }

  if (!_isUnder(relativePath, _designTokenDirectory)) {
    unit.accept(
      _LiteralColourVisitor(
        relativePath: relativePath,
        lineInfo: result.lineInfo,
        violations: violations,
      ),
    );
    unit.accept(
      _LiteralMetricVisitor(
        relativePath: relativePath,
        lineInfo: result.lineInfo,
        violations: violations,
      ),
    );
  }

  return violations;
}

/// Walks every hand-written Dart file under [root] and applies both rules.
///
/// [root] is a parameter rather than a hardcoded `lib/` so that the walk
/// itself — file discovery, generated-file exclusion, path normalisation and
/// the two path gates — is exercised by tests over a synthetic tree. With the
/// real `lib/` holding a single file, a walk hardcoded to it passes
/// vacuously and proves nothing.
///
/// [filesScanned] is returned so a caller can refuse to treat "scanned
/// nothing" as success.
({List<String> violations, int filesScanned}) scanDartTree(Directory root) {
  final violations = <String>[];
  var filesScanned = 0;

  for (final file in _dartFilesUnder(root)) {
    final relativePath = packageRelativePath(file.path);

    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // An unreadable or non-UTF-8 file is a violation naming the path, not an
      // exception that aborts the walk and hides every later file.
      violations.add('$relativePath could not be read as UTF-8 text: $error');
      filesScanned++;
      continue;
    }

    filesScanned++;
    violations.addAll(
      architectureViolationsForSource(
        relativePath: relativePath,
        source: source,
      ),
    );
  }

  return (violations: violations, filesScanned: filesScanned);
}

void main() {
  group('the real lib/ tree', () {
    test('satisfies AD-1 (pure domain) and AD-5 (injected clock)', () {
      final libDirectory = Directory('lib');
      expect(
        libDirectory.existsSync(),
        isTrue,
        reason:
            'Expected to run from the package root, with lib/ present. '
            'Working directory is ${Directory.current.path}.',
      );

      final scan = scanDartTree(libDirectory);

      // Without this the suite would go green on an empty or misresolved
      // tree, which is the one failure mode a passing architecture test
      // cannot otherwise be distinguished from.
      expect(
        scan.filesScanned,
        greaterThan(0),
        reason:
            'The walk scanned no Dart files under lib/. A green run here '
            'would mean nothing. Check lib/ and the generated-file filter.',
      );

      expect(
        scan.violations,
        isEmpty,
        reason:
            'Architecture violations (${scan.violations.length}):\n'
            '${scan.violations.join('\n')}',
      );
    });
  });

  // Each test below pins one row of the spec's I/O & Edge-Case Matrix.
  group('AD-1 — the domain is pure Dart', () {
    List<String> check(String source) => architectureViolationsForSource(
      relativePath: 'lib/domain/x.dart',
      source: source,
    );

    test('a clean domain file yields nothing', () {
      expect(check('class Dose {}'), isEmpty);
    });

    test('a banned package import is a violation', () {
      final violations = check("import 'package:flutter/material.dart';");
      expect(violations, hasLength(1));
      expect(violations.single, contains('lib/domain/x.dart'));
      expect(violations.single, contains('package:flutter/material.dart'));
      expect(violations.single, contains('AD-1'));
    });

    test('every platform-bound dart: library is a violation', () {
      for (final library in _domainBannedDartLibraries) {
        final violations = check("import '$library';");
        expect(
          violations,
          hasLength(1),
          reason: '$library should be banned in lib/domain/',
        );
        expect(violations.single, contains(library));
        expect(violations.single, contains('AD-1'));
      }
    });

    test('a plugin import is a violation without being named in this test', () {
      expect(
        check("import 'package:drift/drift.dart';").single,
        contains('package:drift/drift.dart'),
      );
    });

    test('an export is checked like an import, since it republishes', () {
      expect(
        check("export 'package:drift/drift.dart';").single,
        contains('exports'),
      );
    });

    test('adjacent string literals are joined before the check', () {
      expect(
        check("import 'package:' 'flutter/material.dart';").single,
        contains('package:flutter/material.dart'),
      );
    });

    test('a non-literal URI is reported, and carries the AD-1 marker', () {
      final violations = check(r"import 'package:${x}/y.dart';");
      expect(violations, hasLength(1));
      expect(violations.single, contains('lib/domain/x.dart'));
      expect(violations.single, contains('non-literal URI'));
      expect(violations.single, contains('AD-1'));
    });

    test('package:meta, relative imports and pure dart: libraries are fine', () {
      expect(check("import 'package:meta/meta.dart';"), isEmpty);
      expect(check("import 'y.dart';"), isEmpty);
      expect(check("import '../model/dose.dart';"), isEmpty);
      expect(check("import 'dart:async';"), isEmpty);
      expect(check("import 'dart:math';"), isEmpty);
      expect(check("import 'dart:collection';"), isEmpty);
      expect(check("import 'dart:convert';"), isEmpty);
    });

    test('every violation in one file is reported, not just the first', () {
      expect(
        check(
          "import 'package:flutter/material.dart';\n"
          "import 'dart:io';\n"
          "import 'dart:ffi';\n"
          "export 'package:drift/drift.dart';",
        ),
        hasLength(4),
      );
    });

    test('the rule applies only inside lib/domain/', () {
      expect(
        architectureViolationsForSource(
          relativePath: 'lib/data/db/database.dart',
          source: "import 'package:drift/drift.dart';",
        ),
        isEmpty,
      );
    });
  });

  group('AD-5 — the ambient clock is confined to the clock adapter', () {
    List<String> check(
      String body, {
      String path = 'lib/domain/policy/p.dart',
    }) => architectureViolationsForSource(
      relativePath: path,
      source: 'void f() {\n$body\n}',
    );

    test('the bare call form is caught (MethodInvocation)', () {
      final violations = check('DateTime.now();');
      expect(violations, hasLength(1));
      expect(violations.single, contains('DateTime.now'));
      expect(violations.single, contains('AD-5'));
    });

    test('DateTime.timestamp() is caught', () {
      expect(
        check('DateTime.timestamp();').single,
        contains('DateTime.timestamp'),
      );
    });

    test('the explicit new form is caught (InstanceCreationExpression)', () {
      expect(check('new DateTime.now();').single, contains('DateTime.now'));
      expect(
        check('new tz.TZDateTime.now(loc);').single,
        contains('TZDateTime.now'),
      );
    });

    test('a prefixed TZDateTime.now() is caught', () {
      expect(
        check('tz.TZDateTime.now(loc);'),
        allOf(hasLength(1), contains(contains('TZDateTime.now'))),
      );
    });

    // A tear-off reads the clock just as surely as a call does, and is the
    // form a reviewer found slipping through: `DateTime.now` with no argument
    // list is neither a MethodInvocation nor an InstanceCreationExpression.
    test('an unprefixed tear-off is caught (PrefixedIdentifier)', () {
      final violations = check('final f = DateTime.now;');
      expect(violations, hasLength(1));
      expect(violations.single, contains('DateTime.now'));
      expect(violations.single, contains('AD-5'));

      expect(
        check('final f = DateTime.timestamp;'),
        allOf(hasLength(1), contains(contains('DateTime.timestamp'))),
      );
      expect(
        check('final f = TZDateTime.now;'),
        allOf(hasLength(1), contains(contains('TZDateTime.now'))),
      );
    });

    test('a prefixed tear-off is caught (PropertyAccess)', () {
      final violations = check('final f = tz.TZDateTime.now;');
      expect(violations, hasLength(1));
      expect(violations.single, contains('TZDateTime.now'));
    });

    test('a tear-off passed as an argument is caught exactly once', () {
      final violations = check('map(DateTime.now);');
      expect(violations, hasLength(1));
      expect(violations.single, contains('DateTime.now'));
    });

    test('a call is reported once, not once per matching node kind', () {
      expect(check('tz.TZDateTime.now(loc);'), hasLength(1));
      expect(check('(DateTime.now)();'), hasLength(1));
    });

    test('the clock adapter itself is exempt', () {
      expect(
        check(
          'DateTime.now();\n'
          'DateTime.timestamp();\n'
          'final f = DateTime.now;\n'
          'final g = tz.TZDateTime.now;',
          path: 'lib/platform/clock/system_clock.dart',
        ),
        isEmpty,
      );
    });

    test('a banned name in a comment or a string is not a violation', () {
      expect(check('// DateTime.now()'), isEmpty);
      expect(check(r"final s = 'DateTime.now()';"), isEmpty);
      expect(check(r'final s = """DateTime.now()""";'), isEmpty);
      expect(check(r"final s = 'DateTime.now';"), isEmpty);
    });

    test('an injected clock and unrelated DateTime members are not violations', () {
      expect(check('clock.now();'), isEmpty);
      expect(check('final g = clock.now;'), isEmpty);
      expect(check('final g = settings.timestamp;'), isEmpty);
      expect(check("DateTime.parse('2026-01-05');"), isEmpty);
      expect(check('final f = DateTime.parse;'), isEmpty);
      expect(check('DateTime(2026, 1, 5);'), isEmpty);
    });

    test('the rule applies outside the domain too', () {
      expect(
        check(
          'DateTime.now();',
          path: 'lib/features/home/home_page.dart',
        ).single,
        contains('AD-5'),
      );
    });
  });

  group('TOKENS — colour is a token, declared once in the design layer', () {
    List<String> check(
      String body, {
      String path = 'lib/features/home/home_page.dart',
    }) => architectureViolationsForSource(
      relativePath: path,
      source: 'Widget f() {\n$body\n}',
    );

    test('a literal colour outside the token layer names file and line', () {
      final violations = check('final c = Color(0xFF6C5CE7);');
      expect(violations, hasLength(1));
      expect(violations.single, contains('lib/features/home/home_page.dart:2'));
      expect(violations.single, contains('Color(...)'));
      expect(violations.single, contains('TOKENS'));
    });

    test('every colour constructor form is caught', () {
      // The bare form is a MethodInvocation, the const and new forms are
      // InstanceCreationExpressions, and a prefixed import moves the name one
      // segment along. A visitor handling only one shape passes the rest.
      for (final expression in [
        'Color(0xFF6C5CE7)',
        'const Color(0xFF6C5CE7)',
        'new Color(0xFF6C5CE7)',
        'ui.Color(0xFF6C5CE7)',
        'const ui.Color(0xFF6C5CE7)',
        'Color.fromARGB(255, 108, 92, 231)',
        'const Color.fromARGB(255, 108, 92, 231)',
        'new Color.fromARGB(255, 108, 92, 231)',
        'const ui.Color.fromARGB(255, 108, 92, 231)',
        'Color.fromRGBO(108, 92, 231, 1)',
        'const Color.from(alpha: 1, red: 0.4, green: 0.3, blue: 0.9)',
      ]) {
        expect(
          check('final c = $expression;'),
          hasLength(1),
          reason: '$expression should be one violation',
        );
      }

      // Dart 3.10 dot shorthands, enabled by this package's sdk constraint.
      // Written as a typed declaration, which is what gives the shorthand a
      // context type to resolve against.
      for (final declaration in [
        'Color c = .fromARGB(255, 108, 92, 231);',
        'Color c = .fromRGBO(108, 92, 231, 1);',
      ]) {
        expect(
          check(declaration),
          hasLength(1),
          reason: '$declaration should be one violation',
        );
      }
    });

    test('every route to a colour is caught, not only the ones spelled Color', () {
      // The demonstrated gap: a violet arrived at through HSL is still a
      // violet, and named neither Color nor Colors.
      for (final expression in [
        'HSLColor.fromAHSL(1, 260, 0.7, 0.6).toColor()',
        'HSVColor.fromAHSV(1, 260, 0.7, 0.6).toColor()',
        'CupertinoColors.systemRed',
        'CupertinoColors.systemIndigo.withValues(alpha: 0.5)',
        'MaterialColor(0xFF6C5CE7, const {})',
        'const ColorSwatch(0xFF6C5CE7, {})',
        'const MaterialColor(0xFF6C5CE7, {})',
      ]) {
        expect(
          check('final c = $expression;'),
          hasLength(1),
          reason: '$expression should be one violation',
        );
      }

      // The shorthand forms of the same, which carry no class name at all.
      expect(check('HSLColor c = .fromAHSL(1, 260, 0.7, 0.6);'), hasLength(1));
      expect(check('HSVColor c = .fromAHSV(1, 260, 0.7, 0.6);'), hasLength(1));
    });

    test('an ambiguous dot shorthand is left alone', () {
      // `.from` is Color.from, and equally List.from, Set.from and Map.from.
      // An unresolved AST cannot tell them apart, and a rule that reddens
      // `Set<int> s = .from(xs)` would be worse than the gap it closes.
      expect(check('Set<int> s = .from([1, 2]);'), isEmpty);
      expect(check('List<int> s = .from([1, 2]);'), isEmpty);
    });

    test("Flutter's palette is a violation — the palette is the token layer's job", () {
      expect(check('final c = Colors.red;').single, contains('Colors.red'));
      expect(check('final c = Colors.amber;').single, contains('Colors.amber'));
      expect(
        check('final c = material.Colors.red;').single,
        contains('Colors.red'),
      );
      expect(
        check('final c = CupertinoColors.label;').single,
        contains('CupertinoColors.label'),
      );
    });

    test('a palette shade is reported once, not once per node kind', () {
      final violations = check('final c = Colors.red.shade400;');
      expect(violations, hasLength(1));
      expect(violations.single, contains('Colors.red'));
    });

    test('a Color constructor tear-off is caught', () {
      expect(
        check('final f = Color.fromARGB;').single,
        contains('Color.fromARGB'),
      );
    });

    test('Colors.transparent carries no brand decision and is allowed', () {
      expect(check('final c = Colors.transparent;'), isEmpty);
      expect(check('final c = Colors.transparent.withValues(alpha: 0);'), isEmpty);
    });

    test('a named token constant is the point of the rule and is allowed', () {
      expect(check('final c = MTColors.accent;'), isEmpty);
      expect(check('final c = MTColors.stateLateTile;'), isEmpty);
      // Nothing about a non-colour API is caught by the prefix check.
      expect(check('final c = theme.colorScheme;'), isEmpty);
      expect(check('final c = Color.lerp(MTColors.accent, b, t);'), isEmpty);
      expect(check('final c = MTColors.accent.withValues(alpha: 0.5);'), isEmpty);
    });

    test('a colour in a comment or a string is not a violation', () {
      expect(check('// Color(0xFF6C5CE7)'), isEmpty);
      expect(check(r"final s = 'Color(0xFF6C5CE7)';"), isEmpty);
      expect(check(r"final s = 'Colors.red';"), isEmpty);
      expect(check('final n = 0xFF6C5CE7;'), isEmpty);
    });

    test('every occurrence is reported, not just the first', () {
      expect(
        check(
          'final a = Color(0xFF6C5CE7);\n'
          'final b = const Color(0xFFFFFFFF);\n'
          'final c = Colors.red;',
        ),
        hasLength(3),
      );
    });

    test('the token layer itself may name colours', () {
      const source = 'const a = Color(0xFF6C5CE7);\n'
          'const b = Color.fromARGB(255, 255, 255, 255);\n'
          'const c = Colors.red;';

      expect(
        architectureViolationsForSource(
          relativePath: 'lib/shared/design/colors.dart',
          source: source,
        ),
        isEmpty,
      );

      // Non-vacuous: the same source outside the directory is three violations,
      // so the exemption is doing the work and not the parser.
      expect(
        architectureViolationsForSource(
          relativePath: 'lib/features/x.dart',
          source: source,
        ),
        hasLength(3),
      );
    });

    test('the real colours.dart is exempt and does hold literals', () {
      _expectPackageRoot();
      final file = File('lib/shared/design/colors.dart');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      expect(
        architectureViolationsForSource(
          relativePath: 'lib/shared/design/colors.dart',
          source: source,
        ),
        isEmpty,
      );
      // If this ever came back empty the exemption would be untested, because
      // a file with no literals passes the rule anywhere. The count is
      // deliberately NOT pinned: the fact under test is that the exemption is
      // doing work, and pinning 30 here would redden an architecture test for
      // a legitimate token addition — a failure about no architecture rule at
      // all, fixable only by editing a second file. The token count is pinned
      // once, in design_tokens_test.dart, where it means something.
      expect(
        architectureViolationsForSource(
          relativePath: 'lib/features/x.dart',
          source: source,
        ),
        isNotEmpty,
        reason: 'colors.dart holds the literals every other file may not.',
      );
    });

    test('a literal radius, spacing or type size is a violation', () {
      for (final expression in [
        'BorderRadius.circular(14)',
        'const BorderRadius.all(Radius.circular(18))',
        'Radius.circular(18)',
        'EdgeInsets.all(16)',
        'const EdgeInsets.fromLTRB(16, 8, 16, 8)',
        'TextStyle(fontSize: 17)',
        'const TextStyle(fontSize: 12.5)',
      ]) {
        expect(
          check('final x = $expression;'),
          isNotEmpty,
          reason: '$expression takes a scale value by feel',
        );
      }

      // One violation per literal, so a four-sided inset names all four.
      expect(check('final x = const EdgeInsets.fromLTRB(4, 8, 12, 16);'), hasLength(4));
    });

    test('a scale value taken from the token layer is allowed', () {
      for (final expression in [
        'BorderRadius.circular(MTRadius.md)',
        'const BorderRadius.all(Radius.circular(MTRadius.lg))',
        'EdgeInsets.all(MTSpacing.s4)',
        'EdgeInsets.symmetric(horizontal: MTSpacing.s4)',
        'TextStyle(fontSize: MTTypography.title.fontSize)',
        'MTTypography.title',
        'EdgeInsets.only(top: MTSpacing.s2 * 2)',
      ]) {
        expect(
          check('final x = $expression;'),
          isEmpty,
          reason: '$expression reads the scale rather than inventing one',
        );
      }
    });

    test('zero carries no design decision and is allowed', () {
      // The metric equivalent of Colors.transparent.
      expect(check('final x = const EdgeInsets.only(top: 0);'), isEmpty);
      expect(check('final x = EdgeInsets.all(0);'), isEmpty);
      expect(
        check('final x = const EdgeInsets.symmetric(horizontal: 16, vertical: 0);'),
        hasLength(1),
      );
    });

    test('the rule does not try to ban every number', () {
      // Deliberately narrow: these are not design-scale decisions, and a rule
      // that reddened them would be turned off within a week.
      for (final expression in [
        'Text(x, maxLines: 2)',
        'ListView.builder(itemCount: 7)',
        'Expanded(flex: 3)',
        'Duration(milliseconds: 2600)',
        'list.take(4)',
        'const SizedBox(height: 16)',
      ]) {
        expect(
          check('final x = $expression;'),
          isEmpty,
          reason: '$expression is not a DESIGN.md scale',
        );
      }
    });

    test('the token layer may hold the scales it declares', () {
      const source =
          'const a = TextStyle(fontSize: 26);\n'
          'const b = 14.0;';

      expect(
        architectureViolationsForSource(
          relativePath: 'lib/shared/design/typography.dart',
          source: source,
        ),
        isEmpty,
      );
      expect(
        architectureViolationsForSource(
          relativePath: 'lib/features/x.dart',
          source: source,
        ),
        hasLength(1),
      );
    });

    test('the real typography.dart would be a violation anywhere else', () {
      _expectPackageRoot();
      final source = File('lib/shared/design/typography.dart').readAsStringSync();

      expect(
        architectureViolationsForSource(
          relativePath: 'lib/shared/design/typography.dart',
          source: source,
        ),
        isEmpty,
      );
      expect(
        architectureViolationsForSource(
          relativePath: 'lib/features/x.dart',
          source: source,
        ),
        isNotEmpty,
        reason: 'typography.dart holds the fontSize literals nothing else may.',
      );
    });

    test('the rule applies to every layer, not just features/', () {
      for (final path in [
        'lib/main.dart',
        'lib/app/router.dart',
        'lib/domain/model/dose.dart',
        'lib/data/repository/medicine_repository.dart',
        'lib/platform/clock/system_clock.dart',
        'lib/shared/widgets/dose_card.dart',
      ]) {
        expect(
          check('final c = Color(0xFF6C5CE7);', path: path),
          hasLength(1),
          reason: '$path is outside the token layer',
        );
      }
    });
  });

  group('unparseable source', () {
    test('is reported against its path and does not throw', () {
      final violations = architectureViolationsForSource(
        relativePath: 'lib/data/repository/broken.dart',
        source: 'class Broken {',
      );
      expect(violations, isNotEmpty);
      expect(violations.first, contains('lib/data/repository/broken.dart'));
      expect(violations.first, contains('did not parse'));
    });
  });

  group('packageRelativePath', () {
    test('normalises an absolute path to package-root-relative', () {
      expect(
        packageRelativePath('/Users/dev/med_remind_app/lib/main.dart'),
        'lib/main.dart',
      );
      expect(
        packageRelativePath(
          '/Users/dev/med_remind_app/lib/domain/model/dose.dart',
        ),
        'lib/domain/model/dose.dart',
      );
    });

    // The reproducer: a checkout path that itself contains a `/lib/` segment.
    // Anchoring on the FIRST match resolves against the wrong one, both path
    // gates then fail, and AD-1 stops applying to the domain while the suite
    // stays green.
    test('anchors on the last /lib/ segment, not the first', () {
      expect(
        packageRelativePath('/Users/dev/lib/med_remind_app/lib/main.dart'),
        'lib/main.dart',
      );
      expect(
        packageRelativePath(
          '/srv/lib/checkouts/lib/pkg/lib/domain/policy/resolve.dart',
        ),
        'lib/domain/policy/resolve.dart',
      );
    });

    test('leaves an already-relative path alone', () {
      expect(packageRelativePath('lib/main.dart'), 'lib/main.dart');
      expect(
        packageRelativePath('lib/domain/model/dose.dart'),
        'lib/domain/model/dose.dart',
      );
    });

    test('normalises backslashes', () {
      expect(
        packageRelativePath(r'C:\dev\med_remind_app\lib\domain\model\dose.dart'),
        'lib/domain/model/dose.dart',
      );
    });
  });

  group('the tree walk', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('architecture_test_');
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    File write(String relativePath, String contents) {
      final file = File('${sandbox.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
      return file;
    }

    test('applies each rule to the layer it governs', () {
      write(
        'lib/domain/model/dose.dart',
        "import 'package:drift/drift.dart';",
      );
      write(
        'lib/platform/clock/system_clock.dart',
        'class SystemClock {\n  DateTime now() => DateTime.now();\n}',
      );

      final scan = scanDartTree(Directory('${sandbox.path}/lib'));

      expect(scan.filesScanned, 2);
      expect(scan.violations, hasLength(1));
      expect(scan.violations.single, contains('lib/domain/model/dose.dart'));
      expect(scan.violations.single, contains('AD-1'));
    });

    test('resolves paths correctly under a root containing /lib/', () {
      write(
        'lib/pkg/lib/domain/model/dose.dart',
        "import 'package:flutter/material.dart';",
      );

      final scan = scanDartTree(Directory('${sandbox.path}/lib/pkg/lib'));

      expect(scan.filesScanned, 1);
      expect(scan.violations, hasLength(1));
      expect(scan.violations.single, contains('lib/domain/model/dose.dart'));
    });

    test('skips generated sources', () {
      write('lib/data/db/database.g.dart', "import 'dart:io';");
      write(
        'lib/domain/model/dose.freezed.dart',
        "import 'package:flutter/material.dart';\n"
        'void f() { DateTime.now(); }',
      );
      write('lib/domain/model/dose.dart', 'class Dose {}');

      final scan = scanDartTree(Directory('${sandbox.path}/lib'));

      expect(scan.filesScanned, 1);
      expect(scan.violations, isEmpty);
    });

    test('scans non-generated files whose names merely resemble them', () {
      write('lib/domain/model/log.dart', "import 'dart:io';");

      final scan = scanDartTree(Directory('${sandbox.path}/lib'));

      expect(scan.filesScanned, 1);
      expect(scan.violations, hasLength(1));
    });

    test('ignores non-Dart files', () {
      write('lib/domain/.gitkeep', '');
      write('lib/domain/notes.md', "import 'dart:io';");

      final scan = scanDartTree(Directory('${sandbox.path}/lib'));

      expect(scan.filesScanned, 0);
      expect(scan.violations, isEmpty);
    });

    test('reports an unreadable file and keeps walking', () {
      // Invalid UTF-8: readAsStringSync throws rather than returning text.
      final broken = File('${sandbox.path}/lib/domain/model/binary.dart');
      broken.parent.createSync(recursive: true);
      broken.writeAsBytesSync([0xff, 0xfe, 0x00, 0x80]);

      write('lib/domain/model/dose.dart', "import 'dart:io';");

      final scan = scanDartTree(Directory('${sandbox.path}/lib'));

      expect(scan.filesScanned, 2);
      expect(scan.violations, hasLength(2));
      expect(
        scan.violations,
        contains(
          allOf(
            contains('lib/domain/model/binary.dart'),
            contains('could not be read'),
          ),
        ),
      );
      // The walk did not abort: the file after it was still checked.
      expect(
        scan.violations,
        contains(
          allOf(contains('lib/domain/model/dose.dart'), contains('dart:io')),
        ),
      );
    });
  });

  // RE-SPECIFIED IN STORY 1.2 — read this before changing anything below.
  //
  // Story 1.1 pinned two facts about the tree it left behind: that lib/ held
  // exactly the 16 spine directories and no others, and that lib/main.dart was
  // the only Dart file under lib/. Both were true then and both are wrong now:
  // Story 1.2 adds lib/shared/design/ and four Dart files in it, and every
  // story after it adds more. A rule that makes the next legitimate commit red
  // is not enforcement, it is a tripwire in the wrong place.
  //
  // The response is to re-specify the rule deliberately, not to delete the
  // tests or loosen them until they pass. Growth must be legal WITHOUT the
  // check becoming vacuous, so the replacement still fails on the two things
  // the originals really existed to catch — an invented top-level layer, and a
  // spine directory that has gone missing — while allowing code in the places
  // stories are meant to put it:
  //
  //   1. all 16 spine directories still exist;
  //   2. lib/ has no top-level directory beyond the six roots;
  //   3. domain/, data/ and platform/ hold exactly their spine subdirectories;
  //   4. features/ and shared/ may grow freely;
  //   5. a spine directory is tracked by a .gitkeep or by real sources, and an
  //      empty one keeps its .gitkeep.
  //
  // Whoever next finds one of these red: the rule above is the contract. Change
  // it only by re-specifying it again, in the open, with the reason written
  // down here.
  group('the project structure matches the spine Structural Seed', () {
    test('all 16 spine directories still exist', () {
      _expectPackageRoot();
      expect(_spineDirectories, hasLength(16));

      final missing = _spineDirectories
          .where((directory) => !Directory('lib/$directory').existsSync())
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            'Missing spine directories: ${missing.join(', ')}. The Structural '
            'Seed is the floor: a layer may gain code, never disappear.',
      );
    });

    test('lib/ has no top-level directory beyond the six roots', () {
      _expectPackageRoot();
      final roots = _directoriesUnderLib()
          .where((path) => !path.contains('/'))
          .toSet();

      expect(
        roots,
        equals(_libraryRoots),
        reason:
            'lib/ holds exactly six roots. An invented layer — services/, '
            'utils/, core/ — is an architecture decision, not a story detail.',
      );
    });

    test('main.dart is the only Dart file directly under lib/', () {
      // The test above inspects DIRECTORIES, so it says nothing about a
      // top-level `lib/utils.dart` — a layer invented as a file rather than a
      // folder, which the original "main.dart is the only Dart file" rule did
      // catch and which its re-specification would otherwise have dropped.
      // Everything else belongs to one of the six roots.
      final topLevel = _dartFilesUnder(Directory('lib'))
          .map((file) => packageRelativePath(file.path))
          .where((path) => !path.substring('lib/'.length).contains('/'))
          .toList();

      expect(
        topLevel,
        equals(['lib/main.dart']),
        reason:
            'Only lib/main.dart sits directly under lib/. A top-level library '
            'belongs to a layer: put it in one. Found: ${topLevel.join(', ')}',
      );
    });

    test('domain/, data/ and platform/ hold exactly their spine subdirectories', () {
      // The closure runs ALL THE WAY DOWN: lib/domain/model/ may hold files,
      // but not further directories. Reported as full paths rather than as a
      // set difference, so a nested lib/domain/model/value/ is named as itself
      // and not as a phantom subdirectory called `model/value`.
      _expectPackageRoot();
      final directories = _directoriesUnderLib();

      for (final layer in _closedLayerSubdirectories.entries) {
        final descendants = directories
            .where((path) => path.startsWith('${layer.key}/'))
            .map((path) => path.substring(layer.key.length + 1));

        final unexpected = descendants
            .where(
              (path) => path.contains('/') || !layer.value.contains(path),
            )
            .map((path) => 'lib/${layer.key}/$path')
            .toList();

        expect(
          unexpected,
          isEmpty,
          reason:
              'lib/${layer.key}/ is a closed set, and closed at every depth: '
              'it holds exactly ${layer.value.join(', ')} and no directory '
              'inside those. A new one is a new architectural concept and '
              'needs a decision, not a commit. Found: ${unexpected.join(', ')}',
        );

        final missing = layer.value
            .where((name) => !directories.contains('${layer.key}/$name'))
            .toList();
        expect(missing, isEmpty, reason: 'missing: ${missing.join(', ')}');
      }
    });

    test('features/ and shared/ may grow freely', () {
      // The other half of the rule, pinned so it cannot be quietly reversed by
      // adding an open layer to the closed map.
      expect(
        _closedLayerSubdirectories.keys.toSet().intersection(_openLayers),
        isEmpty,
        reason: 'A layer is either closed or open to growth, never both.',
      );

      // app/ is constrained by neither: the composition root and router arrive
      // in Story 1.3 and may need a shape this story cannot predict. Recorded
      // here so the gap is deliberate rather than an oversight.
      expect(
        _libraryRoots
            .difference(_closedLayerSubdirectories.keys.toSet())
            .difference(_openLayers),
        equals({'app'}),
      );

      // This story's own growth is the worked example: shared/design/ is not a
      // spine directory, and the checks above must accept it.
      _expectPackageRoot();
      expect(Directory('lib/shared/design').existsSync(), isTrue);
    });

    test('directories are kept by .gitkeep, never by placeholder Dart files', () {
      // An empty Dart library trips `flutter analyze`, and a stub with content
      // invites someone to build on it — so an empty spine directory is held
      // open by an empty .gitkeep, and a populated one by its own sources.
      _expectPackageRoot();

      for (final directory in _spineDirectories) {
        final layer = Directory('lib/$directory');
        // A missing spine directory is reported, by name, by the first test in
        // this group. Listing it here would replace that with a
        // PathNotFoundException and a stack trace naming nothing useful.
        if (!layer.existsSync()) continue;

        final keep = File('lib/$directory/.gitkeep');
        // ANY file, not only hand-written Dart. From Story 1.4 lib/data/db/
        // holds drift's generated *.g.dart and nothing else; counting only
        // hand-written sources would call that directory untracked the day its
        // .gitkeep is removed as redundant.
        final contents = layer
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => !file.path.endsWith('/.gitkeep'));

        expect(
          keep.existsSync() || contents.isNotEmpty,
          isTrue,
          reason:
              'lib/$directory holds neither a .gitkeep nor any file, so '
              'nothing tracks it and a clone would not have it.',
        );

        if (keep.existsSync()) {
          expect(
            keep.lengthSync(),
            0,
            reason: 'lib/$directory/.gitkeep should be empty',
          );
        }
      }

      // The original form of this check asserted lib/main.dart was the only
      // Dart file under lib/, which was Story 1.1's scope and nothing more.
      // What it was really guarding is re-specified here: a Dart file under
      // lib/ must declare or export something. A placeholder declares nothing,
      // and is exactly the .dart-instead-of-.gitkeep this test rejects.
      final placeholders = <String>[];
      final unparseable = <String>[];
      for (final file in _dartFilesUnder(Directory('lib'))) {
        final relativePath = packageRelativePath(file.path);
        final result = parseString(
          content: file.readAsStringSync(),
          path: relativePath,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );
        // A file that did not parse recovers an empty unit, which is
        // indistinguishable from a placeholder by declaration count alone.
        // Reporting a broken file as a placeholder would send whoever reads
        // this to delete it and add a .gitkeep, which is the wrong repair.
        if (result.errors.isNotEmpty) {
          unparseable.add('$relativePath (${result.errors.first.message})');
          continue;
        }
        if (result.unit.declarations.isEmpty &&
            result.unit.directives.isEmpty) {
          placeholders.add(relativePath);
        }
      }

      expect(
        unparseable,
        isEmpty,
        reason:
            'Dart files under lib/ that did not parse: '
            '${unparseable.join(', ')}. Fix the syntax; this is not a '
            'placeholder.',
      );
      expect(
        placeholders,
        isEmpty,
        reason:
            'Placeholder Dart libraries under lib/: ${placeholders.join(', ')}. '
            'Use an empty .gitkeep to hold a directory open.',
      );
    });
  });
}

/// AD-1: collects every banned import or export in a domain file.
///
/// Exports are checked alongside imports because an export re-publishes the
/// same dependency to every library that imports this one.
List<String> _domainPurityViolations(
  CompilationUnit unit,
  String relativePath,
) {
  final violations = <String>[];

  for (final directive in unit.directives) {
    final String keyword;
    final StringLiteral uriLiteral;
    if (directive is ImportDirective) {
      keyword = 'imports';
      uriLiteral = directive.uri;
    } else if (directive is ExportDirective) {
      keyword = 'exports';
      uriLiteral = directive.uri;
    } else {
      continue;
    }

    final uri = uriLiteral.stringValue;
    if (uri == null) {
      // An interpolated URI is syntactically parseable but its target cannot
      // be known here, so it cannot be cleared either.
      violations.add(
        '$relativePath $keyword a non-literal URI: $uriLiteral '
        '— AD-1: a domain import must be a plain string literal so that it '
        'can be checked',
      );
      continue;
    }

    if (!_isBannedInDomain(uri)) continue;

    violations.add(
      '$relativePath $keyword $uri '
      '— AD-1: lib/domain/ is pure Dart (only relative imports, '
      'pure dart: libraries and package:meta are permitted)',
    );
  }

  return violations;
}

/// AD-1's rule, expressed as a prefix allowlist rather than a list of banned
/// plugins, so that a package added by a later story is caught without this
/// test being edited.
bool _isBannedInDomain(String uri) {
  if (uri.startsWith('package:')) {
    return !uri.startsWith(_domainAllowedPackagePrefix);
  }
  if (uri.startsWith('dart:')) {
    return _domainBannedDartLibraries.contains(uri);
  }
  // Relative imports stay inside the package and are always fine.
  return false;
}

/// AD-5: flags every ambient clock read outside `lib/platform/clock/`.
///
/// See the note at the top of this file: the same call appears as four
/// different node kinds in an unresolved AST, so there are four overrides.
class _AmbientClockVisitor extends RecursiveAstVisitor<void> {
  _AmbientClockVisitor({
    required this.relativePath,
    required this.lineInfo,
    required this.violations,
  });

  final String relativePath;
  final LineInfo lineInfo;
  final List<String> violations;

  /// Offsets already reported. Nested node kinds can describe one piece of
  /// source text twice — `(DateTime.now)()` is both a parenthesised tear-off
  /// and an invocation — and one call should produce one violation.
  final Set<int> _reported = <int>{};

  /// `DateTime.now()` and `tz.TZDateTime.now(loc)`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final typeName = _targetTypeName(node.target);
    if (typeName != null) {
      _reportIfAmbient(node.offset, typeName, node.methodName.name, '()');
    }
    super.visitMethodInvocation(node);
  }

  /// `new DateTime.now()` and `new tz.TZDateTime.now(loc)`. The parser reads
  /// `DateTime` as an import prefix and `now` as the type name in the first
  /// form, so the dotted name has to be reassembled before it can be matched.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName;
    final parts = <String>[];
    final importPrefix = constructorName.type.importPrefix;
    if (importPrefix != null) parts.add(importPrefix.name.lexeme);
    parts.add(constructorName.type.name.lexeme);
    final namedConstructor = constructorName.name;
    if (namedConstructor != null) parts.add(namedConstructor.name);

    if (parts.length >= 2) {
      _reportIfAmbient(
        node.offset,
        parts[parts.length - 2],
        parts[parts.length - 1],
        '()',
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  /// The unprefixed tear-off, `final f = DateTime.now;`.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _reportIfAmbient(node.offset, node.prefix.name, node.identifier.name, '');
    super.visitPrefixedIdentifier(node);
  }

  /// The prefixed tear-off, `final f = tz.TZDateTime.now;`.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final typeName = _targetTypeName(node.target);
    if (typeName != null) {
      _reportIfAmbient(node.offset, typeName, node.propertyName.name, '');
    }
    super.visitPropertyAccess(node);
  }

  void _reportIfAmbient(
    int offset,
    String typeName,
    String member,
    String suffix,
  ) {
    if (!_ambientClockTypes.contains(typeName)) return;
    if (!_ambientClockMembers.contains(member)) return;
    if (!_reported.add(offset)) return;

    final location = lineInfo.getLocation(offset);
    violations.add(
      '$relativePath:${location.lineNumber}:${location.columnNumber} '
      'reads $typeName.$member$suffix '
      '— AD-5: the ambient clock is read only in lib/platform/clock/; '
      'everything else takes a Clock port',
    );
  }
}

/// TOKENS: flags every literal colour outside `lib/shared/design/`.
///
/// See the note at the top of this file: `Color(0x...)` is a MethodInvocation
/// in an unresolved AST while `const Color(0x...)` is an
/// InstanceCreationExpression, and the palette is reached through two more node
/// kinds again. All four are handled; do not collapse the visitor to one
/// override.
class _LiteralColourVisitor extends RecursiveAstVisitor<void> {
  _LiteralColourVisitor({
    required this.relativePath,
    required this.lineInfo,
    required this.violations,
  });

  final String relativePath;
  final LineInfo lineInfo;
  final List<String> violations;

  /// Offsets already reported. `Colors.red.shade400` is described by both a
  /// PropertyAccess and the PrefixedIdentifier inside it, starting at the same
  /// offset; one colour should produce one violation.
  final Set<int> _reported = <int>{};

  /// `Color(0xFF6C5CE7)`, `ui.Color(...)`, `Color.fromARGB(...)`,
  /// `MaterialColor(...)` and `HSLColor.fromAHSL(...)`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final member = node.methodName.name;
    final targetType = _targetTypeName(node.target);

    if (member == _colorClass || _paletteClasses.contains(member)) {
      // A constructor call. Both the unprefixed `Color(...)` (target null) and
      // the prefixed `ui.Color(...)` (target `ui`) land here with the class as
      // the method name, because the parser cannot tell a constructor from a
      // function.
      _report(node.offset, '$member(...)');
    } else if (targetType == _colorClass &&
        _colorConstructors.contains(member)) {
      _report(node.offset, '$_colorClass.$member(...)');
    } else if (targetType != null &&
        _paletteClasses.contains(targetType) &&
        !_paletteExemptMembers.contains(member)) {
      // Every member of a palette class is a colour, so unlike `Color` there is
      // no member list to keep: `HSLColor.fromAHSL` and any sibling are caught
      // without this test being edited.
      _report(node.offset, '$targetType.$member(...)');
    }
    super.visitMethodInvocation(node);
  }

  /// The Dart 3.10 dot shorthand, `Color c = .fromARGB(255, 108, 92, 231);`.
  ///
  /// There is no context type in an unresolved AST, so only member names that
  /// exist on no other common type are matched — see
  /// [_colorShorthandConstructors]. A `.new(...)` shorthand for `Color` is
  /// therefore NOT caught; nothing distinguishes it from any other `.new`.
  @override
  void visitDotShorthandInvocation(DotShorthandInvocation node) {
    final member = node.memberName.name;
    if (_colorShorthandConstructors.contains(member)) {
      _report(node.offset, '.$member(...)');
    }
    super.visitDotShorthandInvocation(node);
  }

  /// `const Color(0x...)`, `new Color(0x...)` and their named and prefixed
  /// forms. As with `new DateTime.now()`, the parser reads the first dotted
  /// segment as an import prefix, so the name is reassembled before matching.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName;
    final parts = <String>[];
    final importPrefix = constructorName.type.importPrefix;
    if (importPrefix != null) parts.add(importPrefix.name.lexeme);
    parts.add(constructorName.type.name.lexeme);
    final namedConstructor = constructorName.name;
    if (namedConstructor != null) parts.add(namedConstructor.name);

    if (parts.last == _colorClass || _paletteClasses.contains(parts.last)) {
      _report(node.offset, '${parts.last}(...)');
    } else if (parts.length >= 2) {
      final owner = parts[parts.length - 2];
      final member = parts.last;
      if (owner == _colorClass && _colorConstructors.contains(member)) {
        _report(node.offset, '$_colorClass.$member(...)');
      } else if (_paletteClasses.contains(owner) &&
          !_paletteExemptMembers.contains(member)) {
        _report(node.offset, '$owner.$member(...)');
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  /// `Colors.red`, `CupertinoColors.systemRed`, and the unprefixed
  /// `Color.fromARGB` tear-off.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _reportIfLiteral(node.offset, node.prefix.name, node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  /// `material.Colors.red`, and the prefixed `ui.Color.fromARGB` tear-off.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final typeName = _targetTypeName(node.target);
    if (typeName != null) {
      _reportIfLiteral(node.offset, typeName, node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }

  void _reportIfLiteral(int offset, String typeName, String member) {
    if (_paletteClasses.contains(typeName)) {
      if (_paletteExemptMembers.contains(member)) return;
      _report(offset, '$typeName.$member');
      return;
    }
    if (typeName == _colorClass && _colorConstructors.contains(member)) {
      _report(offset, '$_colorClass.$member');
    }
  }

  void _report(int offset, String expression) {
    if (!_reported.add(offset)) return;

    final location = lineInfo.getLocation(offset);
    violations.add(
      '$relativePath:${location.lineNumber}:${location.columnNumber} '
      'names the colour $expression '
      '— TOKENS: every colour is a named constant under $_designTokenDirectory '
      '(MTColors.accent, not a literal); only that directory may transcribe a '
      'value from DESIGN.md',
    );
  }
}

/// TOKENS: flags every literal radius, spacing or type size outside
/// `lib/shared/design/`.
///
/// Deliberately narrow. It does not try to ban every number — a `maxLines: 2`,
/// an `itemCount`, a `flex: 3` are not design decisions. It flags a bare number
/// in exactly the three places DESIGN.md has a scale for it: a `fontSize:`, a
/// [_metricClasses] radius, and a [_metricClasses] inset. Zero is exempt, for
/// the same reason `Colors.transparent` is.
class _LiteralMetricVisitor extends RecursiveAstVisitor<void> {
  _LiteralMetricVisitor({
    required this.relativePath,
    required this.lineInfo,
    required this.violations,
  });

  final String relativePath;
  final LineInfo lineInfo;
  final List<String> violations;

  final Set<int> _reported = <int>{};

  /// `BorderRadius.circular(14)`, `EdgeInsets.all(16)`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final owner = _targetTypeName(node.target) ?? node.methodName.name;
    if (_metricClasses.contains(owner)) {
      _reportLiteralArguments(node.argumentList, owner);
    }
    super.visitMethodInvocation(node);
  }

  /// `const EdgeInsets.symmetric(horizontal: 16)`, `const Radius.circular(18)`.
  /// As everywhere else in this file, the const and new forms parse as a
  /// different node kind from the bare call.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName;
    final parts = <String>[];
    final importPrefix = constructorName.type.importPrefix;
    if (importPrefix != null) parts.add(importPrefix.name.lexeme);
    parts.add(constructorName.type.name.lexeme);
    final namedConstructor = constructorName.name;
    if (namedConstructor != null) parts.add(namedConstructor.name);

    final owner = parts.length >= 2 ? parts[parts.length - 2] : parts.last;
    if (_metricClasses.contains(owner)) {
      _reportLiteralArguments(node.argumentList, owner);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// `TextStyle(fontSize: 17)`, wherever it is written.
  @override
  void visitNamedArgument(NamedArgument node) {
    final name = node.name.lexeme;
    if (_metricNamedArguments.contains(name)) {
      _reportIfNumeric(node.argumentExpression, '$name:', 'MTTypography');
    }
    super.visitNamedArgument(node);
  }

  void _reportLiteralArguments(ArgumentList arguments, String owner) {
    final scale = owner.startsWith('EdgeInsets') ? 'MTSpacing' : 'MTRadius';
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument) {
        _reportIfNumeric(argument.argumentExpression, owner, scale);
      } else if (argument is Expression) {
        _reportIfNumeric(argument, owner, scale);
      }
    }
  }

  void _reportIfNumeric(Expression expression, String where, String scale) {
    // `-4` is a PrefixExpression wrapping the literal, not a literal itself.
    var inner = expression;
    if (inner is PrefixExpression) inner = inner.operand;

    final num? value;
    if (inner is IntegerLiteral) {
      value = inner.value;
    } else if (inner is DoubleLiteral) {
      value = inner.value;
    } else {
      // A named constant, an arithmetic expression over one, anything else —
      // not a literal, and not this rule's business.
      return;
    }

    if (value == null || value == _exemptMetricLiteral) return;
    if (!_reported.add(expression.offset)) return;

    final location = lineInfo.getLocation(expression.offset);
    violations.add(
      '$relativePath:${location.lineNumber}:${location.columnNumber} '
      'passes the literal $value to $where '
      '— TOKENS: DESIGN.md declares the type, radius and spacing scales as '
      'surely as it declares the colours; take this from $scale under '
      '$_designTokenDirectory rather than choosing a number by feel',
    );
  }
}

/// The rightmost identifier of a dotted target: `DateTime` in `DateTime`, and
/// `TZDateTime` in `tz.TZDateTime`.
String? _targetTypeName(Expression? target) {
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) return target.identifier.name;
  return null;
}

/// Fails with a message naming the working directory, rather than with an
/// obscure missing-file error, when the suite is run from anywhere but the
/// package root.
///
/// Every check that touches the filesystem needs this: a wrong CWD otherwise
/// surfaces as "lib/shared/design/colors.dart should exist", which sends the
/// reader looking for a deleted file that is not deleted.
void _expectPackageRoot() {
  expect(
    Directory('lib').existsSync(),
    isTrue,
    reason:
        'Expected to run from the package root, with lib/ present. '
        'Working directory is ${Directory.current.path}.',
  );
}

/// Every directory under `lib/`, as `lib/`-relative forward-slashed paths.
List<String> _directoriesUnderLib() =>
    Directory('lib')
        .listSync(recursive: true, followLinks: false)
        .whereType<Directory>()
        .map((directory) => packageRelativePath(directory.path))
        .map((path) => path.substring('lib/'.length))
        .toList()
      ..sort();

/// Every hand-written Dart file under [directory], generated output excluded.
Iterable<File> _dartFilesUnder(Directory directory) {
  final files = directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !isGeneratedDartFile(file.path))
      .toList();
  // Deterministic order, so a failure message reads the same on every run.
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Whether [path] names generated output rather than a hand-written library.
bool isGeneratedDartFile(String path) =>
    _generatedDartSuffixes.any(path.endsWith);

/// Normalises a path to be package-root-relative with forward slashes, so the
/// prefix checks and the failure messages do not depend on the machine.
///
/// Anchored on the LAST `/lib/` segment: a checkout path may itself contain an
/// earlier one (`/srv/lib/checkouts/pkg/lib/...`), and anchoring on the first
/// would misresolve every path, silently disabling both path gates while the
/// suite stayed green.
String packageRelativePath(String path) {
  final normalised = path.replaceAll(r'\', '/');
  final index = normalised.lastIndexOf('/lib/');
  if (index >= 0) return normalised.substring(index + 1);
  return normalised.startsWith('lib/') ? normalised : 'lib/$normalised';
}

bool _isUnder(String relativePath, String directory) =>
    relativePath.startsWith(directory);
