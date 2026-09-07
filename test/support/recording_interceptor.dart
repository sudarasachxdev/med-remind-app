// A drift `QueryInterceptor` that records what actually reached SQLite.
//
// Two things in this story are only observable at the statement level:
//
//   * whether `markOnboardingComplete` writes ONE column or the whole row --
//     the difference between an upsert that is safe to repeat and one that
//     resets every other setting to a constructor default. Both produce the
//     same visible result today, because the table has one useful column.
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

  /// How many times the executor was asked to close.
  int closes = 0;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    inserts.add(statement);
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    updates.add(statement);
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<void> close(QueryExecutor inner) {
    closes++;
    return super.close(inner);
  }
}
