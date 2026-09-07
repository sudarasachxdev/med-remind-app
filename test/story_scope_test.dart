// What this story deliberately did NOT build.
//
// Two of the acceptance criteria are absences: no notification or permission
// code, and no medicine, schedule or dose table. An absence is the one kind of
// claim a normal test cannot make -- every other test here would still pass the
// day someone wires a permission request into panel 3. So this one reads the
// source tree.
//
// It is a scope guard, not a style rule. Each entry below is a thing Story 1.3
// promised not to do, and each will be DELETED by the story that is allowed to
// do it: the notification and permission entries by Story 3.1, the table entry
// by Story 1.4. A failure here is either a scope leak or a stale guard, and the
// message says which of the two to check.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages no file under `lib/` may import yet.
///
/// `flutter_local_notifications` IS a declared dependency -- Story 1.1 added it
/// so that Epic 3 has it, and AD-17 makes it the sole authority for permission
/// state. Declaring it is not using it, and this story uses none of it.
const Map<String, String> _forbiddenImports = <String, String>{
  'flutter_local_notifications':
      'Story 3.1 owns notifications and the permission request. Panel 3 '
      'explains why they are wanted; it does not ask.',
  'permission_handler':
      'AD-17: permission_handler is not a dependency of this project at all. '
      'flutter_local_notifications is the single authority.',
  'flutter_timezone':
      'AD-6/AD-9: only the Reconciler reads the device zone, in Epic 3.',
};

/// Identifiers that would mean a permission is being requested, whatever the
/// import looks like.
const Map<String, String> _forbiddenIdentifiers = <String, String>{
  'requestPermission':
      'Triggering a real permission request anywhere in this story is out of '
      'scope -- it needs the user\'s word, and Story 3.1 has it.',
  'requestNotificationsPermission': 'As above.',
  'requestExactAlarmsPermission': 'As above.',
  'openAppNotificationSettings':
      'The route into OS settings belongs with the permission-denied banner '
      '(Story 3.1), not with the explainer.',
  'PermissionGateway':
      'The port exists from Story 3.1. Nothing here needs it: this story '
      'shows the explainer and both of its actions go to Home.',
};

/// Table names Story 1.3 must not create. Stories 1.4 and 1.7 own them.
const List<String> _forbiddenTables = <String>[
  'Medicines',
  'Schedules',
  'Doses',
];

void main() {
  late List<({String path, String source})> sources;

  setUpAll(() {
    sources = _handWrittenSources();
  });

  test('there is source to scan', () {
    // A guard over an empty set passes for the wrong reason.
    expect(sources.length, greaterThan(10));
    expect(
      sources.map((({String path, String source}) f) => f.path),
      contains('lib/features/onboarding/presentation/onboarding_screen.dart'),
    );
  });

  test('no notification or permission package is imported', () {
    for (final ({String path, String source}) file in sources) {
      for (final MapEntry<String, String> entry in _forbiddenImports.entries) {
        expect(
          file.source,
          isNot(contains("package:${entry.key}/")),
          reason: '${file.path} imports ${entry.key}. ${entry.value}',
        );
      }
    }
  });

  test('nothing asks the OS for a permission', () {
    for (final ({String path, String source}) file in sources) {
      for (final MapEntry<String, String> entry
          in _forbiddenIdentifiers.entries) {
        // The identifiers appear in prose in this project's own comments, so
        // only real code is checked: comment lines are stripped first.
        expect(
          _withoutComments(file.source),
          isNot(contains(entry.key)),
          reason: '${file.path} names ${entry.key}. ${entry.value}',
        );
      }
    }
  });

  test('the platform adapters this story does not own are still empty', () {
    for (final String layer in <String>[
      // Epic 3 -- flutter_local_notifications.
      'lib/platform/notifications',
      // Story 3.1 -- the PermissionGateway (AD-17).
      'lib/platform/permissions',
      // Epic 3 -- flutter_timezone, read only by the Reconciler (AD-6, AD-9).
      // Listed because it is the third plugin adapter and the one an
      // "innocent" helper is most likely to reach into: a screen that wants
      // the local zone for a formatted time is one import away from it.
      'lib/platform/timezone',
    ]) {
      final Directory directory = Directory(layer);
      // existsSync first. A bare listSync on a missing directory throws a
      // PathNotFoundException with a stack trace naming nothing useful, and
      // replaces the message written below -- which is the whole value of the
      // test -- with a crash. A missing spine directory is a real failure and
      // is reported here as one.
      expect(
        directory.existsSync(),
        isTrue,
        reason:
            '$layer is a Structural Seed directory. It may gain code, never '
            'disappear -- see architecture_test.dart, which owns the shape of '
            'the tree.',
      );

      final List<String> dartFiles = directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((File f) => f.path)
          .where((String p) => p.endsWith('.dart'))
          .toList();

      expect(
        dartFiles,
        isEmpty,
        reason:
            '$layer should hold nothing but its .gitkeep until Epic 3. '
            'Found: ${dartFiles.join(', ')}',
      );
    }
  });

  test('no medicine, schedule or dose table is declared', () {
    // The database test asserts the schema SQLite actually creates. This
    // asserts the Dart, so a table declared but not yet wired into
    // @DriftDatabase is caught too.
    for (final ({String path, String source}) file in sources) {
      final String code = _withoutComments(file.source);
      for (final String table in _forbiddenTables) {
        expect(
          code,
          isNot(contains('class $table extends Table')),
          reason:
              '${file.path} declares $table. Story 1.4 owns Medicine and '
              'Schedule; Story 1.7 owns Dose.',
        );
      }
    }
  });

  test('the domain port imports nothing at all', () {
    const String path = 'lib/domain/port/onboarding_state_store.dart';
    expect(
      File(path).existsSync(),
      isTrue,
      reason:
          '$path is this story\'s one port; without it there is no AD-1 '
          'boundary to check',
    );

    // AD-1 is enforced in general by architecture_test.dart, which allows
    // package:meta and any relative import. This story's one port needs
    // neither, and a port that imports nothing cannot leak storage into the
    // domain by accident.
    final String source = File(path).readAsStringSync();

    expect(
      _withoutComments(source),
      isNot(contains('import ')),
      reason:
          'The domain must not know the flag is a SQLite column. It does not '
          'need an import to say so.',
    );
  });
}

/// Every hand-written Dart file under `lib/`, with its package-relative path.
///
/// Generated output is excluded: `lib/data/db/app_database.g.dart` is written
/// by drift and cannot be edited to satisfy a rule.
List<({String path, String source})> _handWrittenSources() {
  final Directory lib = Directory('lib');
  expect(lib.existsSync(), isTrue, reason: 'run this from the package root');

  return lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((File file) => file.path.replaceAll(r'\', '/'))
      .where((String path) => path.endsWith('.dart'))
      .where((String path) => !path.endsWith('.g.dart'))
      .map((String path) {
        final int index = path.lastIndexOf('lib/');
        final String relative = index >= 0 ? path.substring(index) : path;
        return (path: relative, source: File(path).readAsStringSync());
      })
      .toList()
    ..sort(
      (({String path, String source}) a, ({String path, String source}) b) =>
          a.path.compareTo(b.path),
    );
}

/// [source] with `//` line comments and `///` doc comments removed.
///
/// This file's own subject matter appears throughout the codebase's comments --
/// the whole point of several of them is to record that a permission request
/// belongs to Story 3.1 -- so a raw substring search would flag the very notes
/// that document the boundary.
String _withoutComments(String source) => source
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n');
