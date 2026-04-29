import 'dart:async';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/notifications.dart';
import 'db.dart';
import 'models.dart' as m;

/// Window over which completed-task XP contributes to axis scores.
const Duration _xpDecayWindow = Duration(days: 30);

/// Maximum total XP we expect a healthy axis to accumulate in the window.
/// Used to normalise scores to a 0..100 scale.
const double _maxAxisXpInWindow = 200.0;

class NoeticaRepository {
  NoeticaRepository(this._db);

  final NoeticaDb _db;
  final _uuid = const Uuid();

  final _axesController = StreamController<List<m.LifeAxis>>.broadcast();
  final _entriesController = StreamController<List<m.Entry>>.broadcast();

  /// Fires whenever a write happens — sync layer hooks here to schedule a
  /// debounced push. The payload is intentionally void; consumers re-read
  /// pending changes from SQLite themselves.
  final _dirtyController = StreamController<void>.broadcast();
  Stream<void> get dirty => _dirtyController.stream;

  Stream<List<m.LifeAxis>> watchAxes() async* {
    yield await listAxes();
    yield* _axesController.stream;
  }

  Stream<List<m.Entry>> watchEntries() async* {
    yield await listEntries();
    yield* _entriesController.stream;
  }

  Future<void> _emitAxes() async => _axesController.add(await listAxes());
  Future<void> _emitEntries() async =>
      _entriesController.add(await listEntries());

  void _markDirty() {
    if (_dirtyController.isClosed) return;
    _dirtyController.add(null);
  }

  /// Release stream subscriptions. Called from `dbProvider.onDispose` via the
  /// repository owner; safe to call multiple times.
  void dispose() {
    _axesController.close();
    _entriesController.close();
    _dirtyController.close();
  }

  // ---------- axes ----------

  Future<List<m.LifeAxis>> listAxes({bool includeDeleted = false}) async {
    final rows = await _db.raw.query(
      'axes',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(m.LifeAxis.fromMap).toList();
  }

  Future<m.LifeAxis> createAxis({
    required String name,
    required String symbol,
    required int position,
  }) async {
    final now = DateTime.now();
    final axis = m.LifeAxis(
      id: _uuid.v4(),
      name: name,
      symbol: symbol,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
    await _db.raw.insert('axes', axis.toMap());
    await _emitAxes();
    _markDirty();
    return axis;
  }

  Future<void> updateAxis(m.LifeAxis axis) async {
    final touched = axis.copyWith(updatedAt: DateTime.now());
    await _db.raw.update(
      'axes',
      touched.toMap(),
      where: 'id = ?',
      whereArgs: [axis.id],
    );
    await _emitAxes();
    _markDirty();
  }

  /// Soft-delete: marks `deleted_at = now()` so the row syncs as a tombstone.
  Future<void> deleteAxis(String id) async {
    final now = DateTime.now();
    await _db.raw.update(
      'axes',
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitAxes();
    await _emitEntries();
    _markDirty();
  }

  Future<void> replaceAxes(List<m.LifeAxis> axes) async {
    final now = DateTime.now();
    await _db.raw.transaction((txn) async {
      // Soft-delete everything that isn't in the new list, then upsert the
      // new set. We don't hard-delete because the tombstones need to sync
      // to other devices.
      final existing = await txn.query('axes', columns: ['id']);
      final keepIds = axes.map((a) => a.id).toSet();
      final existingIds = <String>{};
      for (final r in existing) {
        final id = r['id']! as String;
        existingIds.add(id);
        if (!keepIds.contains(id)) {
          // Soft-delete: mark deleted_at, do NOT physically remove the
          // row. Physical DELETE would cascade through entry_axes
          // (ON DELETE CASCADE) and orphan all completed-task XP.
          await txn.update(
            'axes',
            {
              'deleted_at': now.millisecondsSinceEpoch,
              'updated_at': now.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      for (final a in axes) {
        final touched = a.copyWith(updatedAt: now, clearDeleted: true);
        // CRITICAL: do NOT use ConflictAlgorithm.replace here — REPLACE
        // is implemented as DELETE+INSERT which trips the
        // entry_axes(axis_id) ON DELETE CASCADE foreign key and wipes
        // every link from completed tasks to this axis. That's exactly
        // the bug where reordering axes makes the Древо forget all XP.
        // Instead branch on existence: UPDATE for known IDs, INSERT
        // otherwise.
        if (existingIds.contains(a.id)) {
          await txn.update(
            'axes',
            touched.toMap(),
            where: 'id = ?',
            whereArgs: [a.id],
          );
        } else {
          await txn.insert('axes', touched.toMap());
        }
      }
    });
    await _emitAxes();
    await _emitEntries();
    _markDirty();
  }

  /// Replace axes AND remap any pre-existing `entry_axes` links to the
  /// new axis IDs by best-effort name/symbol matching. Without this,
  /// every regeneration of axes would orphan all completed-task XP and
  /// the Древо would silently reset to zero — even though the user can
  /// see the tasks themselves are still completed in Журнал.
  ///
  /// Returns the number of axis-link rows that were remapped.
  Future<int> replaceAxesWithMigration(List<m.LifeAxis> newAxes) async {
    final oldAxes = await listAxes();
    final byName = <String, String>{
      for (final a in newAxes) a.name.toLowerCase().trim(): a.id,
    };
    final bySymbol = <String, String>{
      for (final a in newAxes) a.symbol.trim(): a.id,
    };
    final mapping = <String, String>{};
    for (final o in oldAxes) {
      final n = byName[o.name.toLowerCase().trim()];
      if (n != null) {
        mapping[o.id] = n;
        continue;
      }
      final s = bySymbol[o.symbol.trim()];
      if (s != null) mapping[o.id] = s;
    }
    await replaceAxes(newAxes);
    if (mapping.isEmpty) return 0;
    var migrated = 0;
    final touchedEntryIds = <String>{};
    await _db.raw.transaction((txn) async {
      for (final pair in mapping.entries) {
        if (pair.key == pair.value) continue;
        // De-duplicate: if the entry already has a row pointing to the new
        // axis, drop the old one instead of duplicating the link.
        final dupes = await txn.rawQuery(
          '''
          SELECT a.entry_id AS entry_id
          FROM entry_axes a
          JOIN entry_axes b ON a.entry_id = b.entry_id
          WHERE a.axis_id = ? AND b.axis_id = ?
          ''',
          [pair.key, pair.value],
        );
        for (final r in dupes) {
          touchedEntryIds.add(r['entry_id']! as String);
          await txn.delete(
            'entry_axes',
            where: 'entry_id = ? AND axis_id = ?',
            whereArgs: [r['entry_id'], pair.key],
          );
        }
        // Capture which entries we're about to remap so we can bump
        // their `updated_at` and let the sync layer push the migrated
        // axisIds upstream — otherwise the next pull from the server
        // would resurrect the old axis IDs and re-orphan the XP.
        final affected = await txn.query(
          'entry_axes',
          columns: ['entry_id'],
          where: 'axis_id = ?',
          whereArgs: [pair.key],
        );
        for (final r in affected) {
          touchedEntryIds.add(r['entry_id']! as String);
        }
        final n = await txn.update(
          'entry_axes',
          {'axis_id': pair.value},
          where: 'axis_id = ?',
          whereArgs: [pair.key],
        );
        migrated += n;
      }
      if (touchedEntryIds.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await txn.update(
          'entries',
          {'updated_at': nowMs},
          where:
              'id IN (${List.filled(touchedEntryIds.length, '?').join(',')})',
          whereArgs: touchedEntryIds.toList(),
        );
      }
    });
    await _emitAxes();
    await _emitEntries();
    _markDirty();
    return migrated;
  }

  // ---------- entries ----------

  Future<List<m.Entry>> listEntries({
    m.EntryKind? kind,
    bool? completed,
    bool includeDeleted = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeDeleted) {
      where.add('deleted_at IS NULL');
    }
    if (kind != null) {
      where.add('kind = ?');
      args.add(kind.name);
    }
    if (completed != null) {
      where.add(completed ? 'completed_at IS NOT NULL' : 'completed_at IS NULL');
    }
    final rows = await _db.raw.query(
      'entries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final links = await _db.raw.query(
      'entry_axes',
      where: 'entry_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byEntry = <String, List<String>>{};
    final weightsByEntry = <String, Map<String, double>>{};
    for (final l in links) {
      final eid = l['entry_id']! as String;
      final aid = l['axis_id']! as String;
      byEntry.putIfAbsent(eid, () => []).add(aid);
      final w = l['weight'];
      if (w is num && w != 1.0) {
        weightsByEntry.putIfAbsent(eid, () => {})[aid] = w.toDouble();
      }
    }
    return rows
        .map((r) => m.Entry.fromMap(
              r,
              axisIds: byEntry[r['id']] ?? const [],
              axisWeights: weightsByEntry[r['id']] ?? const {},
            ))
        .toList();
  }

  Future<m.Entry> upsertEntry(m.Entry entry) async {
    await _db.raw.transaction((txn) async {
      // CRITICAL: don't use `INSERT OR REPLACE` on `entries`. REPLACE
      // does DELETE+INSERT under the hood, which trips the
      // entry_links(source_id/target_id) ON DELETE CASCADE foreign keys
      // and wipes every wiki-link row referencing this entry on every
      // save. Branch on existence (same pattern as `mergeRemoteAxis`
      // above): UPDATE for known IDs, INSERT otherwise.
      final existing = await txn.query(
        'entries',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('entries', entry.toMap());
      } else {
        await txn.update(
          'entries',
          entry.toMap(),
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
      await txn
          .delete('entry_axes', where: 'entry_id = ?', whereArgs: [entry.id]);
      for (final aid in entry.axisIds) {
        // If explicit weights were supplied, persist them; otherwise leave
        // the column at its DEFAULT 1.0 (interpreted as "even split" at
        // score time).
        final weight = entry.axisWeights[aid];
        await txn.insert(
          'entry_axes',
          {
            'entry_id': entry.id,
            'axis_id': aid,
            if (weight != null) 'weight': weight,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await _emitEntries();
    _markDirty();
    unawaited(NotificationsService.instance.reschedule(entry));
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final now = DateTime.now();
    await _db.raw.update(
      'entries',
      {
        'deleted_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitEntries();
    _markDirty();
    unawaited(NotificationsService.instance.cancelForEntry(id));
  }

  // ---------- reflections ----------

  /// Persist a reflection for a task. One reflection per task — calling
  /// twice replaces the existing row.
  Future<m.TaskReflection> saveReflection({
    required String entryId,
    required m.ReflectionStatus status,
    String outcome = '',
    String difficulties = '',
    int? actualMinutes,
  }) async {
    final existing = await getReflection(entryId);
    final reflection = m.TaskReflection(
      id: existing?.id ?? _uuid.v4(),
      entryId: entryId,
      status: status,
      createdAt: existing?.createdAt ?? DateTime.now(),
      outcome: outcome,
      difficulties: difficulties,
      actualMinutes: actualMinutes,
    );
    await _db.raw.insert(
      'task_reflections',
      reflection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _markDirty();
    return reflection;
  }

  Future<m.TaskReflection?> getReflection(String entryId) async {
    final rows = await _db.raw.query(
      'task_reflections',
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return m.TaskReflection.fromMap(rows.first);
  }

  /// Most recent reflections across all tasks. Used by the personal
  /// knowledge base to summarise the user's recent activity.
  Future<List<m.TaskReflection>> recentReflections({int limit = 20}) async {
    final rows = await _db.raw.query(
      'task_reflections',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(m.TaskReflection.fromMap).toList();
  }

  /// Flip a task's completion state in-place via a targeted SQL UPDATE.
  ///
  /// Crucially this does **not** rewrite the `entry_axes` table — it would be
  /// a no-op delete+reinsert at best, and on web (sqflite_common_ffi_web) a
  /// transactional rewrite of join rows can race with the score recompute and
  /// the user sees the pentagon stay flat after ticking a roadmap-imported
  /// task. UPDATE keeps axes attached, full stop.
  Future<m.Entry> toggleTaskComplete(
    m.Entry entry, {
    m.ReflectionStatus? reflectionStatus,
  }) async {
    final now = DateTime.now();
    final newCompletedAt = entry.isCompleted ? null : now;

    // Apply reflection-based XP adjustment when completing. The factor
    // is ALWAYS applied to `base_xp` (the original XP this task shipped
    // with) — never to the current `xp`, otherwise re-opening +
    // re-completing a "hard" task would compound the multiplier each
    // time (30 → 36 → 43 → 52 → …). Re-opening still doesn't reset xp
    // here; that happens implicitly on the next completion when the
    // factor reapplies cleanly to base_xp.
    int? newXp;
    if (newCompletedAt != null && reflectionStatus != null) {
      final factor = reflectionStatus.xpFactor;
      newXp = (entry.baseXp * factor).round().clamp(1, 999);
    }

    await _db.raw.update(
      'entries',
      {
        'completed_at': newCompletedAt?.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        if (newXp != null) 'xp': newXp,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await _emitEntries();
    _markDirty();
    final updated = entry.copyWith(
      completedAt: newCompletedAt,
      clearCompleted: newCompletedAt == null,
      updatedAt: now,
      xp: newXp,
    );
    unawaited(NotificationsService.instance.reschedule(updated));
    return updated;
  }

  // ---------- sync helpers ----------

  /// Returns axes (including tombstones) whose `updated_at` is strictly
  /// greater than [sinceMs]. Sync layer pushes these to the backend.
  Future<List<m.LifeAxis>> axesUpdatedSince(int sinceMs) async {
    final rows = await _db.raw.query(
      'axes',
      where: 'updated_at > ?',
      whereArgs: [sinceMs],
    );
    return rows.map(m.LifeAxis.fromMap).toList();
  }

  /// Returns entries (including tombstones) whose `updated_at` is strictly
  /// greater than [sinceMs], with their axis_ids.
  Future<List<m.Entry>> entriesUpdatedSince(int sinceMs) async {
    final rows = await _db.raw.query(
      'entries',
      where: 'updated_at > ?',
      whereArgs: [sinceMs],
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final links = await _db.raw.query(
      'entry_axes',
      where: 'entry_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byEntry = <String, List<String>>{};
    for (final l in links) {
      byEntry
          .putIfAbsent(l['entry_id']! as String, () => [])
          .add(l['axis_id']! as String);
    }
    return rows
        .map((r) => m.Entry.fromMap(r, axisIds: byEntry[r['id']] ?? const []))
        .toList();
  }

  /// Apply a remote axis row using Last-Writer-Wins. Returns true if accepted.
  ///
  /// CRITICAL: this used to use `INSERT OR REPLACE`, but REPLACE on
  /// existing rows trips the entry_axes(axis_id) ON DELETE CASCADE
  /// foreign key and wipes every link from completed tasks to the axis
  /// — silently zeroing the Древо on every sync pull. We now branch on
  /// existence: UPDATE for known IDs, INSERT otherwise.
  Future<bool> mergeRemoteAxis(m.LifeAxis remote) async {
    final existing = await _db.raw.query(
      'axes',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final localUpdated = (existing.first['updated_at'] as int?) ??
          (existing.first['created_at']! as int);
      if (localUpdated >= remote.updatedAt.millisecondsSinceEpoch) {
        return false;
      }
      await _db.raw.update(
        'axes',
        remote.toMap(),
        where: 'id = ?',
        whereArgs: [remote.id],
      );
    } else {
      await _db.raw.insert('axes', remote.toMap());
    }
    return true;
  }

  /// Apply a remote entry row + its axis_ids using LWW. Returns true if
  /// accepted.
  Future<bool> mergeRemoteEntry(m.Entry remote) async {
    final existing = await _db.raw.query(
      'entries',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final localUpdated = existing.first['updated_at']! as int;
      if (localUpdated >= remote.updatedAt.millisecondsSinceEpoch) {
        return false;
      }
    }
    await _db.raw.transaction((txn) async {
      // Same rationale as `upsertEntry`: avoid INSERT OR REPLACE on
      // `entries` because REPLACE cascade-deletes entry_links. Branch
      // on existence and UPDATE-or-INSERT instead.
      if (existing.isEmpty) {
        await txn.insert('entries', remote.toMap());
      } else {
        await txn.update(
          'entries',
          remote.toMap(),
          where: 'id = ?',
          whereArgs: [remote.id],
        );
      }
      await txn.delete(
        'entry_axes',
        where: 'entry_id = ?',
        whereArgs: [remote.id],
      );
      if (!remote.isDeleted) {
        for (final axisId in remote.axisIds) {
          await txn.insert(
            'entry_axes',
            {'entry_id': remote.id, 'axis_id': axisId},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
    return true;
  }

  /// Used by SyncService after a full pull/merge to refresh streams without
  /// triggering another sync push.
  Future<void> notifyChanged({bool axes = true, bool entries = true}) async {
    if (axes) await _emitAxes();
    if (entries) await _emitEntries();
  }

  // ---------- knowledge base: links ----------

  /// Create a directed wiki-style link from [sourceId] to [targetId]
  /// (one row only — the body text owns the outgoing edge, same as
  /// Obsidian). Storing a single row avoids the previous
  /// "syncBodyLinks destroys links created by OTHER entries" bug where
  /// a bidirectional row inserted by A's wiki-link appeared as a stale
  /// outgoing edge when B later saved (Devin Review
  /// BUG_pr-review-job-39c67f0a…_0001).
  Future<void> linkEntries(String sourceId, String targetId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.insert(
      'entry_links',
      {
        'source_id': sourceId,
        'target_id': targetId,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _markDirty();
  }

  /// Remove the directed link from [sourceId] to [targetId]. The reverse
  /// row (if any) is owned by the other entry's body text and stays
  /// intact — deleting both directions here would silently drop links
  /// legitimately created by that other entry's `[[…]]` references.
  Future<void> unlinkEntries(String sourceId, String targetId) async {
    await _db.raw.delete(
      'entry_links',
      where: 'source_id = ? AND target_id = ?',
      whereArgs: [sourceId, targetId],
    );
    _markDirty();
  }

  /// Get all entry IDs connected to [entryId] via a wiki-link, in either
  /// direction. Backwards-compatible with callers that expected the old
  /// bidirectional storage model.
  Future<List<String>> linkedEntryIds(String entryId) async {
    final rows = await _db.raw.rawQuery(
      'SELECT target_id AS other FROM entry_links WHERE source_id = ? '
      'UNION '
      'SELECT source_id AS other FROM entry_links WHERE target_id = ?',
      [entryId, entryId],
    );
    return rows.map((r) => r['other']! as String).toList();
  }

  /// All entries that link _to_ [entryId] via `[[…]]`. Used to drive
  /// the backlinks panel on the entry editor.
  Future<List<m.Entry>> listBacklinks(String entryId) async {
    final rows = await _db.raw.query(
      'entry_links',
      columns: ['source_id'],
      where: 'target_id = ?',
      whereArgs: [entryId],
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['source_id']! as String).toSet().toList();
    final entries = await _db.raw.query(
      'entries',
      where:
          'deleted_at IS NULL AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'updated_at DESC',
    );
    if (entries.isEmpty) return const [];
    // Join `entry_axes` so returned entries carry their axis IDs and
    // weights — without this, opening a backlink in the editor would
    // re-save with axisIds = [] and silently wipe existing associations
    // (Devin Review bug BUG_pr-review-job-567c5fd4c2f84900be8e0ce8d7e84bdd_0001).
    final entryIds = entries.map((r) => r['id'] as String).toList();
    final links = await _db.raw.query(
      'entry_axes',
      where: 'entry_id IN (${List.filled(entryIds.length, '?').join(',')})',
      whereArgs: entryIds,
    );
    final byEntry = <String, List<String>>{};
    final weightsByEntry = <String, Map<String, double>>{};
    for (final l in links) {
      final eid = l['entry_id']! as String;
      final aid = l['axis_id']! as String;
      byEntry.putIfAbsent(eid, () => []).add(aid);
      final w = l['weight'];
      if (w is num && w != 1.0) {
        weightsByEntry.putIfAbsent(eid, () => {})[aid] = w.toDouble();
      }
    }
    return entries
        .map((r) => m.Entry.fromMap(
              r,
              axisIds: byEntry[r['id']] ?? const [],
              axisWeights: weightsByEntry[r['id']] ?? const {},
            ))
        .toList();
  }

  /// Get all links in the database (for graph rendering). Links are
  /// stored unidirectionally (A's body → B creates one row `A→B`); to
  /// avoid drawing A↔B twice when the two entries reference each other
  /// mutually we normalise to unordered `(min, max)` pairs and DISTINCT.
  Future<List<({String source, String target})>> allLinks() async {
    final rows = await _db.raw.rawQuery(
      'SELECT DISTINCT '
      '  CASE WHEN source_id < target_id THEN source_id ELSE target_id END AS a, '
      '  CASE WHEN source_id < target_id THEN target_id ELSE source_id END AS b '
      'FROM entry_links',
    );
    return rows
        .map((r) => (
              source: r['a']! as String,
              target: r['b']! as String,
            ))
        .toList();
  }

  // ---------- knowledge base: search ----------

  /// Full-text search across entry titles and bodies.
  Future<List<m.Entry>> searchEntries(String query) async {
    if (query.trim().isEmpty) return const [];
    final pattern = '%${query.trim()}%';
    final rows = await _db.raw.query(
      'entries',
      where:
          "deleted_at IS NULL AND (title LIKE ? OR body LIKE ? OR tags LIKE ?)",
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'updated_at DESC',
      limit: 50,
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final links = await _db.raw.query(
      'entry_axes',
      where: 'entry_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byEntry = <String, List<String>>{};
    final weightsByEntry = <String, Map<String, double>>{};
    for (final l in links) {
      final eid = l['entry_id']! as String;
      final aid = l['axis_id']! as String;
      byEntry.putIfAbsent(eid, () => []).add(aid);
      final w = l['weight'];
      if (w is num && w != 1.0) {
        weightsByEntry.putIfAbsent(eid, () => {})[aid] = w.toDouble();
      }
    }
    return rows
        .map((r) => m.Entry.fromMap(
              r,
              axisIds: byEntry[r['id']] ?? const [],
              axisWeights: weightsByEntry[r['id']] ?? const {},
            ))
        .toList();
  }

  // ---------- knowledge base: bookmarks ----------

  /// Toggle bookmark state for an entry.
  Future<m.Entry> toggleBookmark(m.Entry entry) async {
    final now = DateTime.now();
    final newBookmarked = !entry.bookmarked;
    await _db.raw.update(
      'entries',
      {
        'bookmarked': newBookmarked ? 1 : 0,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await _emitEntries();
    _markDirty();
    return entry.copyWith(bookmarked: newBookmarked, updatedAt: now);
  }

  // ---------- knowledge base: daily notes ----------

  /// Get or create today's daily note.
  Future<m.Entry> getOrCreateDailyNote() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final title = 'Дневник · $dateStr';
    final rows = await _db.raw.query(
      'entries',
      where: "title = ? AND kind = ? AND deleted_at IS NULL",
      whereArgs: [title, m.EntryKind.note.name],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      // Same axis-join as listEntries / listBacklinks / searchEntries:
      // without it, editing today's daily note would rewrite
      // `entry_axes` with an empty list and silently drop any axes
      // the user previously associated with it.
      final row = rows.first;
      final axisRows = await _db.raw.query(
        'entry_axes',
        where: 'entry_id = ?',
        whereArgs: [row['id']! as String],
      );
      final axisIds = <String>[];
      final axisWeights = <String, double>{};
      for (final l in axisRows) {
        final aid = l['axis_id']! as String;
        axisIds.add(aid);
        final w = l['weight'];
        if (w is num && w != 1.0) axisWeights[aid] = w.toDouble();
      }
      return m.Entry.fromMap(
        row,
        axisIds: axisIds,
        axisWeights: axisWeights,
      );
    }
    return createEntry(
      title: title,
      body: '',
      kind: m.EntryKind.note,
      tags: ['daily'],
    );
  }

  /// Create an entry with tags.
  Future<m.Entry> createEntry({
    required String title,
    String body = '',
    m.EntryKind kind = m.EntryKind.note,
    DateTime? dueAt,
    int xp = 10,
    List<String> axisIds = const [],
    Map<String, double> axisWeights = const {},
    List<String> tags = const [],
    bool bookmarked = false,
  }) {
    final now = DateTime.now();
    final entry = m.Entry(
      id: _uuid.v4(),
      title: title,
      body: body,
      kind: kind,
      createdAt: now,
      updatedAt: now,
      dueAt: dueAt,
      xp: xp,
      axisIds: axisIds,
      axisWeights: axisWeights,
      tags: tags,
      bookmarked: bookmarked,
    );
    return upsertEntry(entry);
  }

  // ---------- knowledge base: parse [[links]] ----------

  /// Extract `[[...]]` references from entry body text.
  static List<String> extractWikiLinks(String body) {
    final regex = RegExp(r'\[\[([^\]]+)\]\]');
    return regex.allMatches(body).map((m) => m.group(1)!.trim()).toList();
  }

  /// Sync the entry_links table based on `[[...]]` references in the
  /// body. Creates target entries if they don't exist yet (Obsidian-style)
  /// AND prunes any stale links whose `[[…]]` reference was removed from
  /// the body since the previous save.
  Future<void> syncBodyLinks(m.Entry entry) async {
    final refs = extractWikiLinks(entry.body);

    // Resolve current references to target IDs (creating stub entries
    // for unknown titles, same Obsidian behaviour as before).
    final desiredTargetIds = <String>{};
    for (final ref in refs) {
      final rows = await _db.raw.query(
        'entries',
        where: 'title = ? AND deleted_at IS NULL',
        whereArgs: [ref],
        limit: 1,
      );
      String targetId;
      if (rows.isNotEmpty) {
        targetId = rows.first['id']! as String;
      } else {
        final stub = await createEntry(title: ref, body: '');
        targetId = stub.id;
      }
      if (targetId == entry.id) continue;
      desiredTargetIds.add(targetId);
    }

    // Query existing outgoing links so we can prune any that no longer
    // correspond to a `[[…]]` in the body — without this the graph
    // accumulates phantom edges when the user deletes a wiki link
    // (Devin Review bug BUG_pr-review-job-03fd7440081141f190487d3ad0f0edb0_0001).
    final existing = await _db.raw.query(
      'entry_links',
      columns: ['target_id'],
      where: 'source_id = ?',
      whereArgs: [entry.id],
    );
    final existingTargetIds = existing
        .map((r) => r['target_id']! as String)
        .toSet();

    for (final stale in existingTargetIds.difference(desiredTargetIds)) {
      await unlinkEntries(entry.id, stale);
    }
    for (final fresh in desiredTargetIds.difference(existingTargetIds)) {
      await linkEntries(entry.id, fresh);
    }
  }

  /// Hard-delete every row in every table. Called by SyncService when the
  /// signed-in Google account changes — we drop the previous user's local
  /// cache wholesale so the new account isn't bleeding through it.
  ///
  /// Crucially this skips the `_markDirty()` machinery: we don't want to
  /// publish tombstones for the previous user's rows on the *new* user's
  /// timeline. Streams are still re-emitted so the UI redraws empty.
  Future<void> wipeLocalData() async {
    await _db.raw.transaction((txn) async {
      // Order respects the FK references (entry_axes, task_reflections,
      // entry_links all point at entries/axes; clear them first).
      await txn.delete('entry_links');
      await txn.delete('entry_axes');
      await txn.delete('task_reflections');
      await txn.delete('entries');
      await txn.delete('axes');
    });
    await _emitAxes();
    await _emitEntries();
  }

  // ---------- scores ----------

  /// Compute a 0..100 axis score based on completed tasks within
  /// [_xpDecayWindow].
  ///
  /// Each task's XP is split across its attached axes via *normalised*
  /// weights — i.e. the per-axis contribution is `xp * decayFactor *
  /// weight / sumOfWeightsForThisTask`. With the default `weight = 1.0`
  /// this is exactly an even 1/N split, which is the deterministic
  /// "fair share" the user asked for. LLM-generated tasks ship explicit
  /// weights; manual tasks fall through to the even split.
  /// Computes per-axis scores from the rolling XP-decay window.
  ///
  /// [baselineCutoff] is an optional override that shifts the window's
  /// earliest contribution forward. Callers pass it when the user
  /// taps «Углубиться» on the эпоха-overlay — that timestamp gets
  /// stored on the profile and fed back here, which effectively
  /// resets the pentagon without deleting any history.
  Future<List<m.AxisScore>> computeScores({
    DateTime? baselineCutoff,
  }) async {
    final axes = await listAxes();
    if (axes.isEmpty) return const [];
    final now = DateTime.now();
    final defaultCutoff =
        now.subtract(_xpDecayWindow).millisecondsSinceEpoch;
    final cutoff = baselineCutoff != null
        ? math.max(defaultCutoff, baselineCutoff.millisecondsSinceEpoch)
        : defaultCutoff;
    final rows = await _db.raw.rawQuery(
      '''
      SELECT ea.entry_id AS entry_id,
             ea.axis_id AS axis_id,
             ea.weight AS weight,
             e.completed_at AS completed_at,
             e.xp AS xp
      FROM entries e
      JOIN entry_axes ea ON ea.entry_id = e.id
      WHERE e.kind = ?
        AND e.completed_at IS NOT NULL
        AND e.completed_at >= ?
        AND e.deleted_at IS NULL
      ''',
      [m.EntryKind.task.name, cutoff],
    );
    final knownAxisIds = {for (final a in axes) a.id};

    // Group rows by entry so we can normalise weights per task.
    final perEntry = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final eid = r['entry_id']! as String;
      perEntry.putIfAbsent(eid, () => []).add(r);
    }

    final raw = <String, double>{for (final a in axes) a.id: 0.0};
    for (final entry in perEntry.values) {
      // Filter to known axes only — drops orphan link rows from deleted
      // axes that haven't been hard-deleted yet.
      final live =
          entry.where((r) => knownAxisIds.contains(r['axis_id'])).toList();
      if (live.isEmpty) continue;
      final totalWeight =
          live.fold<double>(0, (s, r) => s + ((r['weight'] as num?) ?? 1.0));
      if (totalWeight <= 0) continue;
      final completedAt = live.first['completed_at']! as int;
      final xp = (live.first['xp'] as int?) ?? 0;
      final ageMs = now.millisecondsSinceEpoch - completedAt;
      final decay = 1.0 - (ageMs / _xpDecayWindow.inMilliseconds);
      if (decay <= 0) continue;
      for (final r in live) {
        final axisId = r['axis_id']! as String;
        final w = ((r['weight'] as num?) ?? 1.0) / totalWeight;
        raw[axisId] = (raw[axisId] ?? 0) + xp * decay * w;
      }
    }
    return axes.map((axis) {
      final r = raw[axis.id] ?? 0.0;
      final v = (r / _maxAxisXpInWindow * 100).clamp(0.0, 100.0);
      return m.AxisScore(axis: axis, value: v, rawXp: r);
    }).toList();
  }

  // ---------- lifetime stats ----------

  /// Lifetime XP per axis (no decay window). Each completed task's XP
  /// is split across its axes via the same normalised-weight scheme as
  /// [computeScores], so this is consistent with what the user sees on
  /// the Древо. Powers per-axis level rings ("Тело L3 · 540 XP").
  Future<Map<String, int>> axisLifetimeXp() async {
    final axes = await listAxes();
    if (axes.isEmpty) return const {};
    final knownAxisIds = {for (final a in axes) a.id};
    final rows = await _db.raw.rawQuery(
      '''
      SELECT ea.entry_id AS entry_id,
             ea.axis_id AS axis_id,
             ea.weight AS weight,
             e.xp AS xp
      FROM entries e
      JOIN entry_axes ea ON ea.entry_id = e.id
      WHERE e.kind = ?
        AND e.completed_at IS NOT NULL
        AND e.deleted_at IS NULL
      ''',
      [m.EntryKind.task.name],
    );
    final perEntry = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      perEntry.putIfAbsent(r['entry_id']! as String, () => []).add(r);
    }
    final out = <String, double>{for (final a in axes) a.id: 0};
    for (final entry in perEntry.values) {
      final live =
          entry.where((r) => knownAxisIds.contains(r['axis_id'])).toList();
      if (live.isEmpty) continue;
      final totalWeight =
          live.fold<double>(0, (s, r) => s + ((r['weight'] as num?) ?? 1.0));
      if (totalWeight <= 0) continue;
      final xp = (live.first['xp'] as int?) ?? 0;
      for (final r in live) {
        final axisId = r['axis_id']! as String;
        final w = ((r['weight'] as num?) ?? 1.0) / totalWeight;
        out[axisId] = (out[axisId] ?? 0) + xp * w;
      }
    }
    return out.map((k, v) => MapEntry(k, v.round()));
  }

  /// Total XP across **all** completed tasks ever — no decay window.
  /// Powers the persistent profile level.
  Future<int> lifetimeXp() async {
    final rows = await _db.raw.rawQuery(
      '''
      SELECT COALESCE(SUM(xp), 0) AS total
      FROM entries
      WHERE kind = ?
        AND completed_at IS NOT NULL
        AND deleted_at IS NULL
      ''',
      [m.EntryKind.task.name],
    );
    if (rows.isEmpty) return 0;
    final total = rows.first['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return 0;
  }

  /// Daily streak: number of consecutive local-time days, ending today,
  /// with at least one completed task. 0 if today has no completed task.
  Future<int> streakDays() async {
    final rows = await _db.raw.rawQuery(
      '''
      SELECT completed_at FROM entries
      WHERE kind = ? AND completed_at IS NOT NULL AND deleted_at IS NULL
      ORDER BY completed_at DESC
      ''',
      [m.EntryKind.task.name],
    );
    if (rows.isEmpty) return 0;
    final daysWithCompletion = <DateTime>{};
    for (final r in rows) {
      final ts = r['completed_at'] as int?;
      if (ts == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      daysWithCompletion.add(DateTime(dt.year, dt.month, dt.day));
    }
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!daysWithCompletion.contains(cursor)) {
      // Allow grace if user hasn't started today yet — we count yesterday's
      // streak still as alive (will break at end-of-day anyway).
      final y = cursor.subtract(const Duration(days: 1));
      if (!daysWithCompletion.contains(y)) return 0;
      cursor = y;
    }
    var streak = 0;
    while (daysWithCompletion.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
