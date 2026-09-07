// A drift `QueryInterceptor` that records what actually reached SQLite.
//
// Two things in this story are only observable at the statement level:
//
//   * whether `markOnboardingComplete` writes ONE column or the whole row --
//     the difference between an upsert that is safe to repeat and one that
//     resets every other setting to a constructor default. Both produce the
//     same visible result today, because the table has one useful column.
//   * whether `deleteMedicine` removes a Medicine and its Schedules in ONE
//     transaction (AD-12). The result is the same either way -- both rows are
//     gone -- so the only evidence that a failure part-way could not leave one
//     without the other is the order of BEGIN, the two deletes, and COMMIT.
//   * whether the app's `detached` teardown actually closes the connection.
//     `AppDatabase` exposes no `isClosed`, and a query after `close()` does not
//     throw -- drift's delegate quietly opens a fresh in-memory database -- so
//     the close has to be watched where it happens.

import 'package:drift/drift.dart';

/// Records the statements and the close that pass through it.
final class RecordingInterceptor extends QueryInterceptor {
  /// Every insert statement, in order.
  final List<String> inserts = <String>[];

  /// Every update statement, in order.
  final List<String> updates = <String>[];

  /// Every delete statement, in order.
  final List<String> deletes = <String>[];

  /// Every statement, transaction boundary and close, interleaved in the order
  /// they happened.
  ///
  /// "Every" includes `runCustom` and `runBatched`, which is not obvious and
  /// matters: `customStatement` -- which several tests use to plant a row a
  /// repository would refuse to write -- travels through `runCustom`, and the
  /// migration travels through `runCustom`/`runBatched`. Overriding only the
  /// four typed statement kinds made the log look complete while silently
  /// omitting them, which turns an exact `equals` over this list from a strong
  /// assertion into a weak one.
  ///
  /// The per-kind lists above answer "did this statement run"; only one
  /// ordered log answers "did both deletes run between the same BEGIN and
  /// COMMIT", which is the whole of AD-12's single-transaction promise.
  ///
  /// Entries are `begin`, `commit`, `rollback`, `close`, or one of `insert:`,
  /// `update:`, `delete:` and `select:` followed by the statement.
  final List<String> log = <String>[];

  /// How many times the executor was asked to close.
  int closes = 0;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    inserts.add(statement);
    log.add('insert: $statement');
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    updates.add(statement);
    log.add('update: $statement');
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    deletes.add(statement);
    log.add('delete: $statement');
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    log.add('select: $statement');
    return super.runSelect(executor, statement, args);
  }

  // Drift's transaction boundaries. `beginTransaction` is called when the
  // transaction executor is created and `commitTransaction` when it is sent;
  // a statement recorded between the two ran inside it, because the nested
  // executor drift hands out shares this interceptor instance.
  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    log.add('begin');
    return super.beginTransaction(parent);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    log.add('commit');
    return super.commitTransaction(inner);
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    log.add('rollback');
    return super.rollbackTransaction(inner);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    log.add('custom: $statement');
    return super.runCustom(executor, statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    for (final String statement in statements.statements) {
      log.add('batch: $statement');
    }
    return super.runBatched(executor, statements);
  }

  @override
  Future<void> close(QueryExecutor inner) {
    closes++;
    log.add('close');
    return super.close(inner);
  }

  /// Clears the statement record.
  ///
  /// Opening the database issues statements of its own -- the migration, the
  /// `beforeOpen` pragma -- and a test about one method's SQL has to start
  /// from a clean log or it asserts over the setup as well.
  ///
  /// [closes] is deliberately NOT reset. It counts a lifecycle event rather
  /// than a statement, `test/app_startup_test.dart` reads it to prove the
  /// app's teardown closed the connection, and a `clear()` added to an
  /// unrelated test in the same file would silently zero the number that test
  /// depends on.
  void clear() {
    inserts.clear();
    updates.clear();
    deletes.clear();
    log.clear();
  }
}
