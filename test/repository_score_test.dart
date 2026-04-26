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
        version: 2,
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
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
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
              xp INTEGER NOT NULL DEFAULT 10,
              deleted_at INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE entry_axes (
              entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
              axis_id TEXT NOT NULL REFERENCES axes(id) ON DELETE CASCADE,
              weight REAL NOT NULL DEFAULT 1.0,
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

    // Reorder axes (swap Тело ↔ Дело) — IDs preserved, only `position`
    // changes. Scores must remain attached to their axes.
    await repo.replaceAxes([
      LifeAxis(
          id: delo.id, name: 'Дело', symbol: '■', position: 0,
          createdAt: delo.createdAt),
      LifeAxis(
          id: telo.id, name: 'Тело', symbol: '◐', position: 1,
          createdAt: telo.createdAt),
      LifeAxis(
          id: um.id, name: 'Ум', symbol: '◇', position: 2,
          createdAt: um.createdAt),
    ]);
    final afterSwap = await repo.computeScores();
    expect(
      afterSwap.firstWhere((s) => s.axis.id == telo.id).value,
      greaterThan(0),
      reason: 'reordering axes must NOT zero out their scores',
    );

    // Regenerate axes with NEW UUIDs but same names — migration must
    // remap entry_axes so XP is preserved.
    final telo2 = LifeAxis(
        id: 'new-telo', name: 'Тело', symbol: '◐', position: 0,
        createdAt: DateTime.now());
    final delo2 = LifeAxis(
        id: 'new-delo', name: 'Дело', symbol: '■', position: 1,
        createdAt: DateTime.now());
    final um2 = LifeAxis(
        id: 'new-um', name: 'Ум', symbol: '◇', position: 2,
        createdAt: DateTime.now());
    final migrated =
        await repo.replaceAxesWithMigration([telo2, delo2, um2]);
    expect(migrated, greaterThan(0),
        reason: 'replaceAxesWithMigration must remap entry_axes rows');
    final afterMig = await repo.computeScores();
    expect(
      afterMig.firstWhere((s) => s.axis.id == telo2.id).value,
      greaterThan(0),
      reason: 'after regeneration with same names, XP must be preserved',
    );
    expect(afterMig.firstWhere((s) => s.axis.id == delo2.id).value, 0);
    expect(afterMig.firstWhere((s) => s.axis.id == um2.id).value, 0);

    // After migration, completing a NEW task on the new-id axis must
    // raise that axis score too — i.e. the live db state isn't broken.
    final fresh = await repo.createEntry(
      title: 'Сделать дело',
      kind: EntryKind.task,
      xp: 30,
      axisIds: [delo2.id],
    );
    await repo.toggleTaskComplete(fresh);
    final afterFresh = await repo.computeScores();
    expect(
      afterFresh.firstWhere((s) => s.axis.id == delo2.id).value,
      greaterThan(0),
      reason: 'after migration the new axis must accept new XP normally',
    );
  });
}
