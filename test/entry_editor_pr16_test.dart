// PR #16 regression tests for the new notes-editor data path:
// `[[wiki link]]` round-trip, stub-entry creation, tag round-trip,
// and backlinks query. Driven through the real production
// repository against an isolated SQLite db per test — same pattern as
// `repository_score_test.dart`.
//
// We deliberately avoid pumping the modal editor sheet here because
// `pumpAndSettle` loops forever on the StreamProvider that backs
// `entriesProvider`. The assertions below all live in the
// repository / data layer, which is where a broken implementation
// would actually break.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:noetica/data/db.dart';
import 'package:noetica/data/models.dart';
import 'package:noetica/data/repository.dart';

Future<NoeticaDb> _openIsolatedDb() async {
  // Each test gets its own real on-disk SQLite file under the system
  // tmpdir. Using `inMemoryDatabasePath` (`:memory:`) was sharing
  // state across tests in this process, which leaked the bidirectional
  // entry_links rows from Test 1 into Test 2.
  final dir = await Directory.systemTemp.createTemp('noetica-pr16-');
  final path = p.join(dir.path, 'noetica.db');
  final raw = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 6,
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
            tags TEXT NOT NULL DEFAULT '',
            bookmarked INTEGER NOT NULL DEFAULT 0,
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
        await db.execute('''
          CREATE TABLE entry_links (
            source_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            target_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (source_id, target_id)
          )
        ''');
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

  test(
    'Test 1: [[wiki link]] save creates entry_links + listBacklinks returns the referrer',
    () async {
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);

      final alpha = await repo.createEntry(
        title: 'Alpha',
        kind: EntryKind.note,
      );
      final beta = await repo.createEntry(
        title: 'Beta',
        body: '[[Alpha]]',
        kind: EntryKind.note,
      );

      // Step 1: simulate _save's syncBodyLinks call. linkEntries is
      // bidirectional, so we expect 2 rows: one (beta -> alpha)
      // forward, one (alpha -> beta) reverse.
      await repo.syncBodyLinks(beta);

      final links = await db.raw.query('entry_links');
      expect(links.length, 2,
          reason:
              'linkEntries inserts 2 rows per logical link '
              '(forward + reverse). One [[Alpha]] reference => 2 rows.');
      final forward = links.firstWhere(
        (r) => r['source_id'] == beta.id,
        orElse: () => throw StateError('Missing forward link Beta->Alpha'),
      );
      expect(forward['target_id'], alpha.id,
          reason: 'Forward edge must point Beta -> Alpha.');
      final reverse = links.firstWhere(
        (r) => r['source_id'] == alpha.id,
        orElse: () => throw StateError('Missing reverse link Alpha->Beta'),
      );
      expect(reverse['target_id'], beta.id,
          reason: 'Reverse edge must point Alpha -> Beta.');

      // Step 2: backlinks query must return Beta as a referrer of Alpha.
      final backlinks = await repo.listBacklinks(alpha.id);
      expect(backlinks.length, 1,
          reason: 'Alpha has exactly one referrer.');
      expect(backlinks.first.id, beta.id,
          reason:
              'Backlink target must be Beta — if listBacklinks queried '
              "source_id instead of target_id we'd see Alpha here.");
      expect(backlinks.first.title, 'Beta');
    },
  );

  test(
    'Test 2: [[BrandNewTarget]] body creates a stub entry on save',
    () async {
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);
      final source = await repo.createEntry(
        title: 'Source',
        body: 'see [[BrandNewTarget]]',
        kind: EntryKind.note,
      );

      await repo.syncBodyLinks(source);

      final all = await repo.listEntries();
      final stubMatches = all.where((e) => e.title == 'BrandNewTarget').toList();
      expect(stubMatches.length, 1,
          reason: 'syncBodyLinks must auto-create a stub for unknown titles.');
      final stub = stubMatches.first;
      expect(stub.kind, EntryKind.note,
          reason: 'Stub entries are notes by default.');

      final links = await db.raw.query('entry_links');
      expect(links.length, 2,
          reason:
              'One [[BrandNewTarget]] reference creates 2 bidirectional '
              'rows (source <-> stub).');
      final forward = links.firstWhere(
        (r) => r['source_id'] == source.id,
        orElse: () =>
            throw StateError('Missing forward link Source -> stub'),
      );
      expect(forward['target_id'], stub.id,
          reason: 'Forward edge must point Source -> stub.');
      final reverse = links.firstWhere(
        (r) => r['source_id'] == stub.id,
        orElse: () =>
            throw StateError('Missing reverse link stub -> Source'),
      );
      expect(reverse['target_id'], source.id,
          reason: 'Reverse edge must point stub -> Source.');
    },
  );

  test(
    'Test 3: tags round-trip through createEntry / upsertEntry / listEntries',
    () async {
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);

      // Step 1.
      final created = await repo.createEntry(
        title: 'Tagged',
        kind: EntryKind.note,
        tags: ['growth', 'health'],
      );
      expect(created.tags, equals(['growth', 'health']),
          reason: 'createEntry must echo tags back on the returned model.');

      // Step 2.
      final all = await repo.listEntries();
      final reloaded = all.firstWhere((e) => e.id == created.id);
      expect(reloaded.tags, equals(['growth', 'health']),
          reason:
              'Tags must round-trip through SQLite — a missing migration '
              'or a copyWith bug would surface here.');

      // Step 3: drop one tag, reload, ensure it's actually gone.
      final pruned = reloaded.copyWith(
        tags: ['health'],
        updatedAt: DateTime.now(),
      );
      await repo.upsertEntry(pruned);

      final all2 = await repo.listEntries();
      final reloaded2 = all2.firstWhere((e) => e.id == created.id);
      expect(reloaded2.tags, equals(['health']),
          reason:
              'upsertEntry must overwrite tags exactly — partial merge or '
              'append-on-update would leave growth in the list.');
    },
  );
}
