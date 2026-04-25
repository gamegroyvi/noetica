import 'dart:async';

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
      // new set. We don't hard-delete because the tombstones need to sync to
      // other devices.
      final existing = await txn.query('axes', columns: ['id']);
      final keepIds = axes.map((a) => a.id).toSet();
      for (final r in existing) {
        final id = r['id']! as String;
        if (!keepIds.contains(id)) {
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
        await txn.insert(
          'axes',
          touched.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _emitAxes();
    await _emitEntries();
    _markDirty();
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
      await txn.insert(
        'entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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

  Future<m.Entry> createEntry({
    required String title,
    String body = '',
    m.EntryKind kind = m.EntryKind.note,
    DateTime? dueAt,
    int xp = 10,
    List<String> axisIds = const [],
    Map<String, double> axisWeights = const {},
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
    );
    return upsertEntry(entry);
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

    // Apply reflection-based XP adjustment when completing. Re-opening a
    // task does NOT reset XP (the user might re-close it later — keep the
    // history simple and idempotent).
    int? newXp;
    if (newCompletedAt != null && reflectionStatus != null) {
      final factor = reflectionStatus.xpFactor;
      newXp = (entry.xp * factor).round().clamp(1, 999);
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
    }
    await _db.raw.insert(
      'axes',
      remote.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      await txn.insert(
        'entries',
        remote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
  Future<List<m.AxisScore>> computeScores() async {
    final axes = await listAxes();
    if (axes.isEmpty) return const [];
    final now = DateTime.now();
    final cutoff = now.subtract(_xpDecayWindow).millisecondsSinceEpoch;
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
