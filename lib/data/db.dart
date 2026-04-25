import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NoeticaDb {
  NoeticaDb._(this._db);

  final Database _db;
  Database get raw => _db;

  static Future<NoeticaDb> open() async {
    final path = await _databasePath();
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
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
    await db.execute(
        'CREATE INDEX idx_entries_created_at ON entries(created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_entries_kind_completed ON entries(kind, completed_at)');
    await db.execute('''
      CREATE TABLE entry_axes (
        entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        axis_id TEXT NOT NULL REFERENCES axes(id) ON DELETE CASCADE,
        PRIMARY KEY (entry_id, axis_id)
      )
    ''');
  }

  Future<void> close() => _db.close();
}
