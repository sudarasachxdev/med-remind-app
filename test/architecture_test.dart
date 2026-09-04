// Enforcement for two architecture decisions that decay silently otherwise:
//
//   AD-1 — the domain is pure Dart. No file under lib/domain/ may import a
//          package (other than package:meta) or a platform-bound dart:
//          library.
//   AD-5 — time is injected. DateTime.now(), DateTime.timestamp() and
//          TZDateTime.now() appear only in the clock adapter under
//          lib/platform/clock/.
//
// It also pins two structural acceptance criteria of Story 1.1 that are
// otherwise only ever checked by eye: the exact set of directories under lib/,
// and that placeholders are .gitkeep rather than .dart.
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

/// The directories of the spine's Structural Seed, relative to `lib/`.
///
/// Story 1.1's acceptance criteria require exactly these and no others:
/// `features/home/`, `shared/design/` and their siblings belong to the stories
/// that need them.
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

  group('the project structure matches the spine Structural Seed', () {
    test('lib/ holds exactly the 16 spine directories and no others', () {
      final found =
          Directory('lib')
              .listSync(recursive: true, followLinks: false)
              .whereType<Directory>()
              .map((directory) => packageRelativePath(directory.path))
              .map((path) => path.substring('lib/'.length))
              .toList()
            ..sort();

      expect(
        found,
        equals([..._spineDirectories]..sort()),
        reason:
            'lib/ must hold exactly the spine directories. features/home/, '
            'shared/design/ and their siblings belong to the stories that '
            'need them, not to Story 1.1.',
      );
    });

    test('directories are kept by .gitkeep, never by placeholder Dart files', () {
      // An empty Dart library trips `flutter analyze`, and a stub with content
      // invites someone to build on it.
      for (final directory in _spineDirectories) {
        final keep = File('lib/$directory/.gitkeep');
        expect(
          keep.existsSync(),
          isTrue,
          reason: 'lib/$directory/.gitkeep should exist to keep the directory',
        );
        expect(
          keep.lengthSync(),
          0,
          reason: 'lib/$directory/.gitkeep should be empty',
        );
      }

      final strayLibraries = Directory('lib')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((file) => packageRelativePath(file.path))
          .where((path) => path.endsWith('.dart'))
          .where((path) => path != 'lib/main.dart')
          .toList();

      expect(
        strayLibraries,
        isEmpty,
        reason:
            'Story 1.1 creates structure and enforcement only. lib/main.dart '
            'is the only Dart file it may add.',
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
    final typeName = _typeNameOf(node.target);
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
    final typeName = _typeNameOf(node.target);
    if (typeName != null) {
      _reportIfAmbient(node.offset, typeName, node.propertyName.name, '');
    }
    super.visitPropertyAccess(node);
  }

  /// The rightmost identifier of a dotted target: `DateTime` in `DateTime`,
  /// and `TZDateTime` in `tz.TZDateTime`.
  static String? _typeNameOf(Expression? target) {
    if (target is SimpleIdentifier) return target.name;
    if (target is PrefixedIdentifier) return target.identifier.name;
    return null;
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
