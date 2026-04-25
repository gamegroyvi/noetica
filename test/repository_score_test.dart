import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:noetica/data/db.dart';
import 'package:noetica/data/models.dart';
import 'package:noetica/data/repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('roadmap-style import + complete flips pentagon score above zero',
      () async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE axes (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              symbol TEXT NOT NULL,
              position INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE entries (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              body TEXT NOT NULL DEFAULT '',
              kind TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              due_at INTEGER,
              completed_at INTEGER,
              xp INTEGER NOT NULL DEFAULT 10
            )
          ''');
          await db.execute('''
            CREATE TABLE entry_axes (
              entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
              axis_id TEXT NOT NULL REFERENCES axes(id) ON DELETE CASCADE,
              PRIMARY KEY (entry_id, axis_id)
            )
          ''');
        },
      ),
    );
    final db = NoeticaDb.test(raw);
    final repo = NoeticaRepository(db);

    final telo =
        await repo.createAxis(name: 'Тело', symbol: '◐', position: 0);
    final delo =
        await repo.createAxis(name: 'Дело', symbol: '■', position: 1);
    final um = await repo.createAxis(name: 'Ум', symbol: '◇', position: 2);

    final task = await repo.createEntry(
      title: 'Пробежать 5 км',
      kind: EntryKind.task,
      xp: 30,
      axisIds: [telo.id],
    );

    expect(task.axisIds, contains(telo.id));

    final reloaded = (await repo.listEntries(kind: EntryKind.task)).first;
    expect(reloaded.axisIds, contains(telo.id),
        reason: 'axisIds must round-trip through SQLite');

    await repo.toggleTaskComplete(reloaded);

    final scores = await repo.computeScores();
    final teloScore = scores.firstWhere((s) => s.axis.id == telo.id);
    expect(teloScore.value, greaterThan(0),
        reason: 'completing a roadmap task should raise its axis score');
    expect(scores.firstWhere((s) => s.axis.id == delo.id).value, 0);
    expect(scores.firstWhere((s) => s.axis.id == um.id).value, 0);

    // Toggling completion must not strip the axis link — ticking off, then
    // ticking back on, must keep the score pinned to Тело and zero elsewhere.
    final completed = (await repo.listEntries(kind: EntryKind.task)).first;
    expect(completed.axisIds, contains(telo.id),
        reason: 'completing must not detach the entry from its axis');

    await repo.toggleTaskComplete(completed);
    final reopened = (await repo.listEntries(kind: EntryKind.task)).first;
    expect(reopened.axisIds, contains(telo.id),
        reason: 'reopening must not detach the entry from its axis either');

    await repo.toggleTaskComplete(reopened);
    final scoresAgain = await repo.computeScores();
    expect(
      scoresAgain.firstWhere((s) => s.axis.id == telo.id).value,
      greaterThan(0),
    );
  });
}
