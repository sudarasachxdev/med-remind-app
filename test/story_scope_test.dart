// What this story deliberately did NOT build.
//
// Two of the acceptance criteria are absences: no notification or permission
// code, and no medicine, schedule or dose table. An absence is the one kind of
// claim a normal test cannot make -- every other test here would still pass the
// day someone wires a permission request into panel 3. So this one reads the
// source tree.
//
// It is a scope guard, not a style rule. Each entry below is a thing the
// current story promised not to do, and each is DELETED by the story that is
// allowed to do it -- the notification and permission entries by Story 3.1.
// Story 1.4 removed `Medicines` and `Schedules` from the forbidden-table list
// because Story 1.4 is the story that builds them; `Doses` stayed until Story
// 1.7a, which removed it in turn -- the list is empty again, kept rather than
// deleted so a future story that leaves something not-yet-built has the same
// mechanism to hand. A failure here is either a scope leak or a stale guard,
// and the message says which of the two to check.
//
// Story 1.4's own absences are here too: no widget, no provider and no
// `doses` table -- both stories ended at a port. Story 1.7a's absence is a
// new one: no `lib/app/` binding for `DoseRepository` either, added to
// `_providerHomes` below exactly as Story 1.5 once had one there for
// `MedicineRepository`. Story 1.7b's `DoseGenerator` -- `DoseRepository`'s
// first real caller, but from `lib/domain/service/`, not `lib/app/` -- joins
// the same entry rather than opening a new one: it is the identical absence
// (no Reconciler to wire it into the composition root yet, AD-9) on a second
// type.

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
  // `flutter_timezone` was here until 2026-09-08, forbidden as
  // "AD-6/AD-9: only the Reconciler reads the device zone, in Epic 3."
  //
  // AD-9 was amended, and this entry is retired rather than merely deleted so
  // the reason survives. The old rule contradicted AD-6: AD-6 requires every
  // Schedule to persist a real IANA zone, and Story 1.5 is the first story
  // that creates a Schedule. That left two illegal-or-wrong options and no
  // right one -- store `Etc/UTC`, which for a user in `Asia/Colombo` names a
  // different instant and would be consumed by Stories 1.6/1.7 as if it were
  // true, or leave the Medicine unscheduled, which FR-1 forbids.
  //
  // AD-9 now distinguishes READING the zone (permitted at Schedule creation,
  // through the `Clock` port) from REACTING to a zone change (still the
  // Reconciler's alone). Deleting the entry outright would have widened the
  // package to the whole tree, which is more than the amendment granted, so it
  // moves to [_directoryScopedImports] instead of disappearing.
};

/// Packages exactly one directory under `lib/` may import.
///
/// The middle ground `_forbiddenImports` cannot express. That map is
/// all-or-nothing: a package is banned everywhere or allowed everywhere, and
/// every entry so far has been retired by simply deleting it. `flutter_timezone`
/// is the first package whose permission is real but narrow -- AD-9 as amended
/// lets the device zone be READ, and AD-5 confines every clock read to one
/// adapter, so the two together allow it in exactly one place.
///
/// Deleting an entry here does not widen a package to the tree; it removes the
/// only thing keeping the read in the one file the architecture test exempts
/// from the AD-5 rule. If a second directory genuinely needs one of these, that
/// is an architecture decision, not a test edit.
const Map<String, String> _directoryScopedImports = <String, String>{
  'flutter_timezone': 'lib/platform/clock',
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

/// Directories this story must not add code to, mapped to the story that may.
///
/// Story 1.4 ends at the port: the repository is reachable from the domain, and
/// nothing renders it. A widget or a provider added here would be Story 1.5's
/// work landing early, without Story 1.5's design review.
const Map<String, String> _directoriesThisStoryDoesNotOwn = <String, String>{
  'lib/features/medicines':
      'Story 1.5 owns the add-medicine flow. This story ends at the port.',
};

/// Directories that must not name a pending port's type, mapped to the reason.
///
/// The no-provider half of this story's scope was guarded by looking in
/// `lib/features/medicines` -- but every provider in this project lives in
/// `lib/app/`, so a `medicineRepositoryProvider` added there passed a test
/// whose name said no provider was added.
///
/// Its one entry forbade `lib/app/` from naming `MedicineRepository`, from
/// Story 1.4 (which ended at the port) until Story 1.5 (that port's first
/// caller) retired it -- the house rule for this file: each guard is deleted
/// by the story that is allowed to do the thing. It stayed empty until Story
/// 1.7a, which is in the same position Story 1.4 was: `DoseRepository` had no
/// caller yet either.
///
/// Story 1.7b is that caller -- but only inside `lib/domain/service/`, not
/// `lib/app/`: `DoseGenerator` depends on `DoseRepository` the port, which is
/// exactly what a domain service consuming a port is for (see
/// `AddMedicineController` over `MedicineRepository`), and is not the
/// composition root binding either type to a Drift adapter. No Reconciler
/// exists yet to be the thing `lib/app/` would wire `DoseGenerator` into
/// (AD-9, Epic 3), so the `DoseRepository`/`DriftDoseRepository` entry is NOT
/// retired by this story -- it gains `DoseGenerator` as a third forbidden
/// name on the same entry instead, the same "no caller yet" absence, one
/// type wider.
const Map<String, String> _providerHomes = <String, String>{
  'lib/app':
      'Story 1.7b\'s DoseGenerator is DoseRepository\'s first caller, but '
      'only from lib/domain/service/. No Reconciler exists yet to wire '
      'DoseGenerator itself into the composition root (AD-9, Epic 3).',
};

/// Identifiers that must not appear in a domain model file, by file.
///
/// AD-6 is the product's keystone: a Schedule stores a wall-clock time and an
/// IANA zone, and **never** a UTC instant. "Every day at 8:00" keeps its plain
/// meaning across a DST transition only while 8:00 is what was stored; an
/// instant computed once at creation drifts by an hour twice a year, which is
/// the failure class the PRD found in competitor app-store reviews.
///
/// This rule exists because the test that named the invariant did not check
/// it. `domain_model_test`'s "exposes no instant, offset or UTC value at all"
/// asserted on `Schedule.toString()`, which is hand-written over four fields --
/// so adding `DateTime get scheduledUtc => DateTime.utc(...)` to the class
/// passed all 324 tests. A claim about a type's surface has to observe the
/// surface, not a rendering of four of its fields.
final Map<String, List<({RegExp pattern, String reason})>>
_forbiddenInDomainModel = <String, List<({RegExp pattern, String reason})>>{
  'lib/domain/model/schedule.dart': <({RegExp pattern, String reason})>[
    // `DateTime` is banned as a type and as an instant, but NOT as the
    // weekday constants. `DateTime.monday` through `DateTime.sunday` are
    // plain integers 1..7 -- the idiomatic Dart names for days of the week
    // -- and a Schedule's day set is exactly that. Banning the bare token
    // would have failed the real file for the one use that is not an
    // instant, which is how a rule gets deleted instead of narrowed.
    (
      pattern: RegExp(
        r'DateTime(?!\.(monday|tuesday|wednesday|thursday|friday'
        r'|saturday|sunday)\b)',
      ),
      reason:
          'AD-6: a Schedule holds a wall clock and a zone. A DateTime '
          'here is an instant, however it is spelled. Only the weekday '
          'constants are permitted.',
    ),
    (
      pattern: RegExp('utc', caseSensitive: false),
      reason: 'AD-6: no UTC value on the type, precomputed or derived.',
    ),
    (
      pattern: RegExp('epoch', caseSensitive: false),
      reason: 'AD-6: no epoch value.',
    ),
    (
      pattern: RegExp('instant', caseSensitive: false),
      reason: 'AD-6: no instant.',
    ),
    (
      pattern: RegExp('offset', caseSensitive: false),
      reason: 'AD-6: an offset is a zone flattened into a number.',
    ),
  ],
};

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

  test('a directory-scoped package is imported only in its one directory', () {
    // The guard AD-9's amendment needs. Reading the device zone is now legal,
    // in one adapter -- so this asserts the narrowness, not the ban.
    for (final MapEntry<String, String> entry
        in _directoryScopedImports.entries) {
      final List<String> offenders = sources
          .where(
            (({String path, String source}) f) =>
                f.source.contains('package:${entry.key}/') &&
                !f.path.startsWith('${entry.value}/'),
          )
          .map((({String path, String source}) f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason:
            '${offenders.join(', ')} imports ${entry.key}, which only '
            '${entry.value}/ may. AD-5 confines every clock read to one '
            'adapter and AD-9 permits the zone to be read there; a second '
            'reader is an architecture decision, not a test edit.',
      );
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

  test('the domain model exposes no instant, offset or UTC value (AD-6)', () {
    for (final MapEntry<String, List<({RegExp pattern, String reason})>> file
        in _forbiddenInDomainModel.entries) {
      final File source = File(file.key);
      expect(
        source.existsSync(),
        isTrue,
        reason:
            '${file.key} does not exist, so this rule guards nothing. A guard '
            'that cannot find its target passes for the wrong reason.',
      );
      final String code = _withoutComments(source.readAsStringSync());
      for (final ({RegExp pattern, String reason}) banned in file.value) {
        final RegExpMatch? hit = banned.pattern.firstMatch(code);
        expect(
          hit,
          isNull,
          reason: '${file.key} contains "${hit?.group(0)}". ${banned.reason}',
        );
      }
    }
  });

  test('a port with no caller yet is kept out of the composition root', () {
    // Named for the mechanism, not for one story's absence. It was called "the
    // repository is not wired into the composition root yet" until 2026-09-08,
    // when Story 1.5 wired MedicineRepository -- at which point the old name
    // was a false claim sitting on top of a loop over an empty map, which
    // passes for the worst possible reason.
    //
    // So the guard states two things. First, that the entry Story 1.5 retired
    // stayed retired: `medicine_repository_provider.dart` exists, which is
    // only true once the binding landed, so a `_providerHomes` entry re-added
    // for `MedicineRepository` would be a guard that regressed rather than one
    // that still protects something. Second -- the loop below -- that whatever
    // `_providerHomes` currently forbids (Story 1.7a's `DoseRepository` entry,
    // joined by Story 1.7b's `DoseGenerator`) is really absent from the
    // directory it names.
    expect(
      File('lib/app/medicine_repository_provider.dart').existsSync(),
      isTrue,
      reason:
          'The repository entry was retired from _providerHomes, which only '
          'Story 1.5 may do, and only because it wires the repository. If the '
          'binding is gone, the guard was relaxed rather than satisfied.',
    );

    for (final MapEntry<String, String> home in _providerHomes.entries) {
      final Directory directory = Directory(home.key);
      expect(
        directory.existsSync(),
        isTrue,
        reason:
            '${home.key} does not exist, so this guard is vacuous. Every '
            'provider in this project lives there.',
      );
      for (final File file
          in directory
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart'))) {
        final String code = _withoutComments(file.readAsStringSync());
        for (final String named in <String>[
          'DoseRepository',
          'DriftDoseRepository',
          'DoseGenerator',
        ]) {
          expect(
            code,
            isNot(contains(named)),
            reason: '${file.path} names $named. ${home.value}',
          );
        }
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

  test('this story added no widget and no provider', () {
    // Two of Story 1.4's acceptance criteria are absences, and the storage
    // layer is exactly where a "just to see it work" screen appears. The port
    // and its adapter are testable without one.
    for (final MapEntry<String, String> entry
        in _directoriesThisStoryDoesNotOwn.entries) {
      final Directory directory = Directory(entry.key);
      if (!directory.existsSync()) continue;

      final List<String> dartFiles = directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((File f) => f.path)
          .where((String p) => p.endsWith('.dart'))
          .toList();

      expect(
        dartFiles,
        isEmpty,
        reason: '${entry.key}: ${entry.value} Found: ${dartFiles.join(', ')}',
      );
    }

    // And nothing under data/ or domain/ reaches for Riverpod or Flutter --
    // the two imports a provider or a widget would need.
    for (final ({String path, String source}) file in sources) {
      if (!file.path.startsWith('lib/data/') &&
          !file.path.startsWith('lib/domain/')) {
        continue;
      }
      final String code = _withoutComments(file.source);
      for (final String banned in const <String>[
        'package:flutter_riverpod/',
        'package:flutter/',
      ]) {
        expect(
          code,
          isNot(contains(banned)),
          reason:
              '${file.path} imports $banned. Providers carry state and never '
              'rules (AD-13), and a repository is not something a widget '
              'touches.',
        );
      }
    }
  });

  test('no DAO or second write path to schedules is exposed', () {
    // AD-12: `MedicineRepository` is the only path that creates, edits or
    // deletes a Schedule. A `DatabaseAccessor`/`@DriftAccessor` would be a
    // second one, with its own copy of the duplicate-schedule rule and the
    // delete cascade -- and one of the two copies would be the one that is
    // wrong.
    for (final ({String path, String source}) file in sources) {
      final String code = _withoutComments(file.source);
      for (final String banned in const <String>[
        'DriftAccessor',
        'DatabaseAccessor',
      ]) {
        expect(
          code,
          isNot(contains(banned)),
          reason:
              '${file.path} declares $banned. AD-12: Medicine is the '
              'aggregate root and its repository is the only write path.',
        );
      }
    }
  });

  test('the medicine port is pure Dart, like the onboarding one', () {
    const String path = 'lib/domain/port/medicine_repository.dart';
    expect(File(path).existsSync(), isTrue);

    final String code = _withoutComments(File(path).readAsStringSync());

    // AD-1 in general is enforced by architecture_test.dart, which allows
    // package:meta and any relative import. This port needs neither Drift nor
    // meta: its only imports are the sibling models it names.
    expect(
      code,
      isNot(contains('package:')),
      reason:
          'The domain must not know a Medicine is a row. Every import in this '
          'file is a relative one to a sibling model.',
    );
    expect(
      code,
      contains('abstract interface class MedicineRepository'),
      reason: 'the port is an interface, not a class with an implementation',
    );
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
