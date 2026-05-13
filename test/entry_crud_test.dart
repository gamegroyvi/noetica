import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:noetica/data/db.dart';
import 'package:noetica/data/models.dart';
import 'package:noetica/data/repository.dart';

Future<NoeticaDb> _openTestDb() async {
  final raw = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: NoeticaDb.currentSchemaVersion,
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
            base_xp INTEGER NOT NULL DEFAULT 10,
            deleted_at INTEGER,
            tags TEXT NOT NULL DEFAULT '',
            bookmarked INTEGER NOT NULL DEFAULT 0
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
        await db.execute('''
          CREATE TABLE IF NOT EXISTS task_reflections (
            id TEXT PRIMARY KEY,
            entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            outcome TEXT NOT NULL DEFAULT '',
            difficulties TEXT NOT NULL DEFAULT '',
            actual_minutes INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS entry_links (
            source_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            target_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (source_id, target_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS profile (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    ),
  );
  return NoeticaDb.test(raw);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Entry CRUD', () {
    test('createEntry adds a new entry and listEntries returns it', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      final entry = await repo.createEntry(
        title: 'My Task',
        body: 'Some body',
        kind: EntryKind.task,
        xp: 15,
      );

      expect(entry.title, 'My Task');
      expect(entry.body, 'Some body');
      expect(entry.kind, EntryKind.task);
      expect(entry.xp, 15);
      expect(entry.isCompleted, isFalse);

      final all = await repo.listEntries();
      expect(all, hasLength(1));
      expect(all.first.id, entry.id);

      await db.close();
    });

    test('createEntry with note kind', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      final note = await repo.createEntry(
        title: 'My Note',
        kind: EntryKind.note,
      );

      expect(note.kind, EntryKind.note);
      final notes = await repo.listEntries(kind: EntryKind.note);
      expect(notes, hasLength(1));

      await db.close();
    });

    test('deleteEntry soft-deletes (sets deleted_at)', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      final entry = await repo.createEntry(title: 'To Delete');
      expect(await repo.listEntries(), hasLength(1));

      await repo.deleteEntry(entry.id);

      // Default: excludes deleted
      expect(await repo.listEntries(), isEmpty);

      // With includeDeleted
      final withDeleted = await repo.listEntries(includeDeleted: true);
      expect(withDeleted, hasLength(1));
      expect(withDeleted.first.deletedAt, isNotNull);

      await db.close();
    });

    test('upsertEntry updates existing entry', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      final original = await repo.createEntry(
        title: 'Original',
        body: 'v1',
      );

      final updated = original.copyWith(title: 'Updated', body: 'v2');
      await repo.upsertEntry(updated);

      final entries = await repo.listEntries();
      expect(entries, hasLength(1));
      expect(entries.first.title, 'Updated');
      expect(entries.first.body, 'v2');

      await db.close();
    });

    test('listEntries filters by kind', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      await repo.createEntry(title: 'Task 1', kind: EntryKind.task);
      await repo.createEntry(title: 'Note 1', kind: EntryKind.note);
      await repo.createEntry(title: 'Task 2', kind: EntryKind.task);

      final tasks = await repo.listEntries(kind: EntryKind.task);
      expect(tasks, hasLength(2));

      final notes = await repo.listEntries(kind: EntryKind.note);
      expect(notes, hasLength(1));

      await db.close();
    });

    test('entry completion filters work', () async {
      final db = await _openTestDb();
      final repo = NoeticaRepository(db);

      final task = await repo.createEntry(
        title: 'Task',
        kind: EntryKind.task,
      );

      // Initially not completed
      var open = await repo.listEntries(completed: false);
      expect(open, hasLength(1));
      var done = await repo.listEntries(completed: true);
      expect(done, isEmpty);

      // Complete the task
      final completed = task.copyWith(completedAt: DateTime.now());
      await repo.upsertEntry(completed);

      open = await repo.listEntries(completed: false);
      expect(open, isEmpty);
      done = await repo.listEntries(completed: true);
      expect(done, hasLength(1));

      await db.close();
    });
  });
}
