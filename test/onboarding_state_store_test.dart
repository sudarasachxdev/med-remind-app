// The Drift adapter behind the onboarding-state port, against a real SQLite.
//
// In-memory rather than mocked, per AD-19: a repository test that stubs the
// database proves the Dart compiles and nothing about the SQL. The upsert, the
// default, and the "no row means not completed" reading are all statements
// about SQLite's behaviour, so SQLite has to be the thing answering.

// `show` rather than a bare import: drift also exports an `isNotNull`, which
// collides with matcher's.
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_remind_app/data/db/app_database.dart';
import 'package:med_remind_app/data/repository/drift_onboarding_state_store.dart';
import 'package:med_remind_app/domain/port/onboarding_state_store.dart';

import 'support/recording_interceptor.dart';

void main() {
  late AppDatabase database;
  late OnboardingStateStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftOnboardingStateStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DriftOnboardingStateStore', () {
    test('the completion write touches only the onboarding column', () async {
      // `insertOnConflictUpdate` was the obvious call and is the wrong one: it
      // updates EVERY column from a fully-populated companion. `AppSettings`'
      // own doc promises the escalation window, the snooze length and the
      // reminder offsets are coming to this same row, and the port documents
      // this call as safe to repeat from a future Settings surface -- so the
      // day one of those lands, an "idempotent" call would quietly reset all
      // three to their constructor defaults.
      //
      // Both forms produce the same visible result today, because the table has
      // one useful column. So the statement itself is what gets asserted.
      final interceptor = RecordingInterceptor();
      final scoped = AppDatabase(
        NativeDatabase.memory().interceptWith(interceptor),
      );
      addTearDown(scoped.close);
      final OnboardingStateStore scopedStore = DriftOnboardingStateStore(
        scoped,
      );

      await scopedStore.markOnboardingComplete();

      expect(interceptor.inserts, hasLength(1));
      final String statement = interceptor.inserts.single;
      expect(
        statement,
        contains('DO UPDATE SET'),
        reason: 'it is still an upsert -- the row may not exist yet',
      );
      final String updateClause = statement.substring(
        statement.indexOf('DO UPDATE SET'),
      );
      expect(
        updateClause,
        contains('"onboarding_completed"'),
        reason: 'the one column this port owns',
      );
      expect(
        updateClause,
        isNot(contains('"id"')),
        reason:
            'A full-row update is the bug. Every column named in the update '
            'clause is a column this method overwrites, and it owns exactly '
            'one.',
      );
    });

    test('a fresh install reads as not completed', () async {
      // The fresh-install row of the matrix. There is no settings row at all,
      // and the absence of a row is a genuine "not completed" -- not an error,
      // and emphatically not a "completed".
      expect(await store.isOnboardingComplete(), isFalse);
    });

    test('marking completion is visible to the next read', () async {
      await store.markOnboardingComplete();

      expect(await store.isOnboardingComplete(), isTrue);
    });

    test('marking completion twice is not an error', () async {
      // The port promises idempotence, so no call site needs a guard against a
      // second completion -- a relaunch racing the write, or a re-entry from
      // some future Settings surface.
      await store.markOnboardingComplete();
      await store.markOnboardingComplete();

      expect(await store.isOnboardingComplete(), isTrue);
    });

    test(
      'completion is written to the one settings row, not a new one',
      () async {
        await store.markOnboardingComplete();
        await store.markOnboardingComplete();

        final int rows =
            (await database
                    .customSelect('SELECT COUNT(*) AS n FROM app_settings')
                    .getSingle())
                .read<int>('n');

        expect(
          rows,
          1,
          reason:
              'The upsert must update the singleton row. Two rows would mean two '
              'readers could disagree about what the settings are.',
        );
      },
    );

    test('completion survives reopening the same store', () async {
      await store.markOnboardingComplete();

      // A second adapter over the same database is what a relaunch looks like
      // from the adapter's point of view: same rows, new object, no cache.
      final OnboardingStateStore reopened = DriftOnboardingStateStore(database);

      expect(await reopened.isOnboardingComplete(), isTrue);
    });

    test('a read failure throws rather than answering false or true', () async {
      // The matrix's "database unreadable" row, at the layer where the failure
      // originates. The adapter must not translate "I could not read" into
      // either answer -- `false` would look like a fresh install and `true`
      // would hide onboarding from a first-time user. Only the caller has
      // enough context to choose, and it chooses to show the panels.
      // The store is damaged rather than closed. `AppDatabase.close()` looked
      // like the obvious way to break it and is not: drift's delegate simply
      // opens a fresh in-memory database on the next query, which then reads
      // as an empty -- and therefore *valid* -- fresh install. A missing table
      // is a failure the executor cannot paper over.
      await database.customStatement('DROP TABLE app_settings');

      await expectLater(
        store.isOnboardingComplete(),
        throwsA(isA<Object>()),
        reason: 'an unreadable store must not read as a fresh install',
      );
    });
  });
}
