import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NoeticaDb {
  NoeticaDb._(this._db);

  /// Test-only constructor; allows wiring an in-memory DB directly.
  @visibleForTesting
  NoeticaDb.test(this._db);

  final Database _db;
  Database get raw => _db;

  /// v3 adds `task_reflections` for the post-completion reflection sheet.
  /// v4 adds `entry_axes.weight` so XP can be split deterministically
  /// across the axes a task touches (LLM-generated tasks ship explicit
  /// weights; manually-tagged tasks fall back to an even 1/N split).
  /// v5 adds `entries.base_xp` so the reflection-difficulty multiplier
  /// is always applied to the original XP, never to a previously-
  /// adjusted value (used to compound on every re-complete cycle).
  static const int currentSchemaVersion = 6;

  static Future<NoeticaDb> open() async {
    final path = await _databasePath();
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return NoeticaDb._(db);
  }

  static Future<String> _databasePath() async {
    if (kIsWeb) return 'noetica.db';
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'noetica.db');
  }

  static Future<void> _onCreate(Database db, int version) async {
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
    await db.execute('CREATE INDEX idx_axes_updated_at ON axes(updated_at)');
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
    await db.execute(
        'CREATE INDEX idx_entries_created_at ON entries(created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_entries_kind_completed ON entries(kind, completed_at)');
    await db.execute(
        'CREATE INDEX idx_entries_updated_at ON entries(updated_at)');
    await db.execute('''
      CREATE TABLE entry_axes (
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        axis_id TEXT NOT NULL REFERENCES axes(id) ON DELETE CASCADE,
        weight REAL NOT NULL DEFAULT 1.0,
        PRIMARY KEY (entry_id, axis_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_entry_axes_entry ON entry_axes(entry_id)');
    await db.execute(
        'CREATE INDEX idx_entry_axes_axis ON entry_axes(axis_id)');
    await _createReflectionsTable(db);
    await _createEntryLinksTable(db);
  }

  static Future<void> _createReflectionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE task_reflections (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        outcome TEXT NOT NULL DEFAULT '',
        difficulties TEXT NOT NULL DEFAULT '',
        actual_minutes INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_task_reflections_entry ON task_reflections(entry_id)');
  }

  static Future<void> _createEntryLinksTable(Database db) async {
    await db.execute('''
      CREATE TABLE entry_links (
        source_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        target_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (source_id, target_id)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_entry_links_source ON entry_links(source_id)');
    await db.execute(
        'CREATE INDEX idx_entry_links_target ON entry_links(target_id)');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // axes: add updated_at (default to created_at) + deleted_at.
      // SQLite doesn't allow a non-constant default, so we add the column
      // first with a literal default and then backfill.
      await db.execute('ALTER TABLE axes ADD COLUMN updated_at INTEGER');
      await db.execute('ALTER TABLE axes ADD COLUMN deleted_at INTEGER');
      await db.execute(
          'UPDATE axes SET updated_at = created_at WHERE updated_at IS NULL');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_axes_updated_at ON axes(updated_at)');

      // entries: only deleted_at is missing; updated_at already exists.
      await db.execute('ALTER TABLE entries ADD COLUMN deleted_at INTEGER');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_entries_updated_at ON entries(updated_at)');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_entry_axes_entry ON entry_axes(entry_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_entry_axes_axis ON entry_axes(axis_id)');
    }
    if (oldVersion < 3) {
      await _createReflectionsTable(db);
    }
    if (oldVersion < 4) {
      // SQLite ALTER TABLE ADD COLUMN with a literal default is allowed.
      // Existing rows get weight = 1.0; the score routine normalises so
      // that's interpreted as an even 1/N split, matching legacy
      // behaviour on the displayed pentagon.
      await db.execute(
          'ALTER TABLE entry_axes ADD COLUMN weight REAL NOT NULL DEFAULT 1.0');
    }
    if (oldVersion < 5) {
      // base_xp = whatever xp was at migration time, since we have no
      // record of the original. Future completions will pin themselves
      // to this value, so the compounding bug stops. Old rows that
      // never get re-completed are unaffected.
      await db.execute(
          'ALTER TABLE entries ADD COLUMN base_xp INTEGER NOT NULL DEFAULT 10');
      await db.execute('UPDATE entries SET base_xp = xp');
    }
    if (oldVersion < 6) {
      // Knowledge-base features: bidirectional links, bookmarks, tags.
      await _createEntryLinksTable(db);
      await db.execute(
          "ALTER TABLE entries ADD COLUMN tags TEXT NOT NULL DEFAULT ''");
      await db.execute(
          'ALTER TABLE entries ADD COLUMN bookmarked INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> close() => _db.close();
}
