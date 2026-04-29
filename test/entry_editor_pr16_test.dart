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

      // Step 1: simulate _save's syncBodyLinks call. Links are stored
      // unidirectionally (one row per `[[…]]` reference), so we expect
      // a single forward edge Beta -> Alpha.
      await repo.syncBodyLinks(beta);

      final links = await db.raw.query('entry_links');
      expect(links.length, 1,
          reason:
              'Unidirectional storage: one [[Alpha]] reference in Beta => '
              '1 forward row.');
      final forward = links.first;
      expect(forward['source_id'], beta.id,
          reason: 'Forward edge must originate from Beta (the body owner).');
      expect(forward['target_id'], alpha.id,
          reason: 'Forward edge must point Beta -> Alpha.');

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
      expect(links.length, 1,
          reason:
              'Unidirectional storage: one [[BrandNewTarget]] reference '
              'creates a single forward row source -> stub.');
      final forward = links.single;
      expect(forward['source_id'], source.id,
          reason: 'Forward edge must originate from Source (body owner).');
      expect(forward['target_id'], stub.id,
          reason: 'Forward edge must point Source -> stub.');
    },
  );

  test(
    'Test 5 (regression): syncBodyLinks prunes stale links when [[refs]] are removed',
    () async {
      // Devin Review bug: if the user saved a note with `[[Alpha]]`
      // and then edited the body to drop that link, `syncBodyLinks`
      // never removed the existing entry_links row — the graph
      // accumulated phantom edges. This test pins the new prune
      // behaviour.
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);

      final alpha = await repo.createEntry(
        title: 'Alpha',
        kind: EntryKind.note,
      );
      final beta = await repo.createEntry(
        title: 'Beta',
        kind: EntryKind.note,
      );

      // 1. Source references both. Links are stored unidirectionally
      //    now (one row per `[[…]]` reference, owned by the body text
      //    that contains it). Two refs => 2 forward rows.
      final withBoth = await repo.createEntry(
        title: 'Source',
        body: '[[Alpha]] and [[Beta]]',
        kind: EntryKind.note,
      );
      await repo.syncBodyLinks(withBoth);
      final after1 = await db.raw.query('entry_links');
      expect(after1.length, 2,
          reason: 'Unidirectional storage: two refs => 2 forward rows.');

      // 2. User deletes `[[Alpha]]` and saves again. We expect the
      //    forward Source->Alpha edge to be pruned; Beta unchanged.
      final withBetaOnly = withBoth.copyWith(
        body: 'only [[Beta]]',
        updatedAt: DateTime.now(),
      );
      await repo.upsertEntry(withBetaOnly);
      await repo.syncBodyLinks(withBetaOnly);
      final after2 = await db.raw.query('entry_links');
      expect(after2.length, 1,
          reason: 'Only Source->Beta should remain after pruning Alpha.');
      final toAlpha = after2.where((r) =>
          r['source_id'] == withBoth.id && r['target_id'] == alpha.id);
      expect(toAlpha, isEmpty,
          reason: 'Forward edge Source->Alpha must be pruned.');
      final toBeta = after2.where((r) =>
          r['source_id'] == withBoth.id && r['target_id'] == beta.id);
      expect(toBeta, hasLength(1),
          reason: 'Beta link must still be present.');

      // 3. User removes the last link. Expect all outgoing links gone.
      final blank = withBetaOnly.copyWith(
        body: 'no links here',
        updatedAt: DateTime.now(),
      );
      await repo.upsertEntry(blank);
      await repo.syncBodyLinks(blank);
      final after3 = await db.raw.query('entry_links');
      final fromSource = after3.where((r) => r['source_id'] == withBoth.id);
      expect(fromSource, isEmpty,
          reason:
              'When every `[[…]]` is removed, all outgoing links must be '
              'pruned — early-return on empty refs was the bug.');
    },
  );

  test(
    'Test 4 (regression): listBacklinks returns entries with axisIds populated',
    () async {
      // Devin Review caught this: listBacklinks used to call
      // `entries.map(m.Entry.fromMap).toList()` without joining
      // `entry_axes`, so every returned Entry had `axisIds = []`. If
      // the user opened a backlink in the editor and saved, it would
      // silently wipe all axis associations. This test reproduces the
      // scenario and asserts the fix loads axisIds like listEntries.
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);

      // Seed two axes directly via SQL — repository doesn't expose a
      // createAxis method and we only need them as FK targets for the
      // entry_axes join.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final a in const [
        ('axis-body', 'Body', 0),
        ('axis-mind', 'Mind', 1),
      ]) {
        await db.raw.insert('axes', {
          'id': a.$1,
          'name': a.$2,
          'symbol': '*',
          'position': a.$3,
          'created_at': nowMs,
          'updated_at': nowMs,
        });
      }

      // Create a target and a source that links to it; both carry
      // axis associations.
      final target = await repo.createEntry(
        title: 'Target',
        kind: EntryKind.note,
        axisIds: const ['axis-body'],
      );
      final source = await repo.createEntry(
        title: 'Source',
        body: '[[Target]]',
        kind: EntryKind.note,
        axisIds: const ['axis-mind'],
      );
      await repo.syncBodyLinks(source);

      final backlinks = await repo.listBacklinks(target.id);
      expect(backlinks.length, 1);
      expect(backlinks.first.id, source.id);
      expect(backlinks.first.axisIds, equals(['axis-mind']),
          reason:
              'Entry returned from listBacklinks must carry its axisIds — '
              'otherwise saving via the backlinks panel would wipe them.');
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

  test(
    "Test 6 (regression): syncBodyLinks doesn't destroy OTHER entries' links",
    () async {
      // Devin Review BUG_pr-review-job-39c67f0a…_0001: the previous
      // bidirectional storage model plus `source_id = ?` prune query
      // meant that when Entry A (with empty body) was re-saved,
      // syncBodyLinks would treat the reverse row inserted by Entry C's
      // `[[A]]` reference as a stale A-initiated link and delete both
      // directions — silently dropping C's legitimate link to A.
      // With unidirectional storage that class of bug can't happen:
      // A's syncBodyLinks only sees rows where source=A, and C's
      // wiki-link lives in a row with source=C.
      final db = await _openIsolatedDb();
      final repo = NoeticaRepository(db);

      // Seed: C's body has [[A]]. A has nothing.
      final a = await repo.createEntry(title: 'A', kind: EntryKind.note);
      final c = await repo.createEntry(
        title: 'C',
        body: '[[A]]',
        kind: EntryKind.note,
      );
      await repo.syncBodyLinks(c);

      expect(
        (await db.raw.query('entry_links')).length,
        1,
        reason: 'Only C->A forward row should exist.',
      );

      // Act: user opens A and saves with still-empty body. Under the
      // old bidirectional logic this would have deleted C->A. Under
      // unidirectional storage A's syncBodyLinks sees nothing to prune
      // because no row has source=A.
      final aReopened = a.copyWith(
        body: 'still nothing',
        updatedAt: DateTime.now(),
      );
      await repo.upsertEntry(aReopened);
      await repo.syncBodyLinks(aReopened);

      final after = await db.raw.query('entry_links');
      expect(after.length, 1,
          reason:
              "Saving A with an empty body must NOT remove C's "
              "forward link to A — C's body text owns that row.");
      expect(after.single['source_id'], c.id);
      expect(after.single['target_id'], a.id);

      // And backlinks on A should still return C.
      final backlinksToA = await repo.listBacklinks(a.id);
      expect(backlinksToA.map((e) => e.id).toList(), [c.id]);
    },
  );
}
