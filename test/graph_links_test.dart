// Integration test for the wiki-link → graph edge pipeline.
//
// Reproduces the user-reported bug: "I created a note with a `[[…]]`
// reference but the graph doesn't draw an edge." Pins the contract
// each layer (`syncBodyLinks` → `entry_links` table → `allLinks` →
// graph edge build) must satisfy so the regression can't return.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:noetica/data/db.dart';
import 'package:noetica/data/models.dart';
import 'package:noetica/data/repository.dart';

Future<NoeticaDb> _openIsolatedDb() async {
  final dir = await Directory.systemTemp.createTemp('noetica-graph-');
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

/// Mirror of the edge-building logic in `_rebuildGraph`. Kept here so
/// the test can verify the same `idToIndex`-style pipeline the screen
/// uses without needing to pump the whole widget tree.
List<({String from, String to})> buildGraphEdges({
  required List<Entry> entries,
  required List<({String source, String target})> links,
}) {
  final byId = <String, int>{
    for (var i = 0; i < entries.length; i++) entries[i].id: i,
  };
  final out = <({String from, String to})>[];
  for (final l in links) {
    final si = byId[l.source];
    final ti = byId[l.target];
    if (si != null && ti != null) {
      out.add((from: entries[si].id, to: entries[ti].id));
    }
  }
  return out;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('one [[wiki]] reference produces one normalised graph edge',
      () async {
    final db = await _openIsolatedDb();
    final repo = NoeticaRepository(db);

    final a = await repo.createEntry(title: 'Alpha', kind: EntryKind.note);
    final b = await repo.createEntry(
      title: 'Beta',
      body: 'see [[Alpha]] for context',
      kind: EntryKind.note,
    );
    await repo.syncBodyLinks(b);

    final links = await repo.allLinks();
    expect(links, hasLength(1));

    final edges = buildGraphEdges(
      entries: await repo.listEntries(),
      links: links,
    );
    expect(edges, hasLength(1));
    expect({edges.first.from, edges.first.to}, {a.id, b.id});
  });

  test('mutual `[[…]]` references collapse to a single graph edge',
      () async {
    final db = await _openIsolatedDb();
    final repo = NoeticaRepository(db);

    final a = await repo.createEntry(
      title: 'Alpha',
      body: '[[Beta]]',
      kind: EntryKind.note,
    );
    final b = await repo.createEntry(
      title: 'Beta',
      body: '[[Alpha]]',
      kind: EntryKind.note,
    );
    await repo.syncBodyLinks(a);
    await repo.syncBodyLinks(b);

    final links = await repo.allLinks();
    expect(links, hasLength(1),
        reason: 'allLinks normalises bidirectional pairs to one row');
    final edges = buildGraphEdges(
      entries: await repo.listEntries(),
      links: links,
    );
    expect(edges, hasLength(1));
    expect({edges.first.from, edges.first.to}, {a.id, b.id});
  });

  test('removing a `[[…]]` reference removes the graph edge', () async {
    final db = await _openIsolatedDb();
    final repo = NoeticaRepository(db);

    await repo.createEntry(title: 'Alpha', kind: EntryKind.note);
    final b = await repo.createEntry(
      title: 'Beta',
      body: '[[Alpha]]',
      kind: EntryKind.note,
    );
    await repo.syncBodyLinks(b);
    expect(await repo.allLinks(), hasLength(1));

    final cleared = b.copyWith(body: '');
    await repo.upsertEntry(cleared);
    await repo.syncBodyLinks(cleared);

    expect(await repo.allLinks(), isEmpty);
    expect(
      buildGraphEdges(
        entries: await repo.listEntries(),
        links: await repo.allLinks(),
      ),
      isEmpty,
    );
  });

  test('linking to unknown title auto-creates a stub + edge', () async {
    final db = await _openIsolatedDb();
    final repo = NoeticaRepository(db);

    final source = await repo.createEntry(
      title: 'SourceNote',
      body: 'see [[BrandNew]]',
      kind: EntryKind.note,
    );
    await repo.syncBodyLinks(source);

    final all = await repo.listEntries();
    final stub = all.where((e) => e.title == 'BrandNew').toList();
    expect(stub, hasLength(1));
    expect(stub.first.kind, EntryKind.note);

    final edges = buildGraphEdges(
      entries: all,
      links: await repo.allLinks(),
    );
    expect(edges, hasLength(1));
    expect({edges.first.from, edges.first.to},
        {source.id, stub.first.id});
  });

  test('many spokes pointing at one hub render every edge', () async {
    final db = await _openIsolatedDb();
    final repo = NoeticaRepository(db);

    final hub = await repo.createEntry(title: 'Hub', kind: EntryKind.note);
    final spokes = <Entry>[];
    for (var i = 0; i < 5; i++) {
      final s = await repo.createEntry(
        title: 'Spoke$i',
        body: 'links to [[Hub]]',
        kind: EntryKind.note,
      );
      spokes.add(s);
      await repo.syncBodyLinks(s);
    }

    final edges = buildGraphEdges(
      entries: await repo.listEntries(),
      links: await repo.allLinks(),
    );
    expect(edges, hasLength(5));
    for (final e in edges) {
      final ids = {e.from, e.to};
      expect(ids.contains(hub.id), isTrue);
      expect(ids.any((id) => spokes.any((s) => s.id == id)), isTrue);
    }
  });
}
