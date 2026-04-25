import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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

  // ---------- axes ----------

  Future<List<m.LifeAxis>> listAxes() async {
    final rows =
        await _db.raw.query('axes', orderBy: 'position ASC, created_at ASC');
    return rows.map(m.LifeAxis.fromMap).toList();
  }

  Future<m.LifeAxis> createAxis({
    required String name,
    required String symbol,
    required int position,
  }) async {
    final axis = m.LifeAxis(
      id: _uuid.v4(),
      name: name,
      symbol: symbol,
      position: position,
      createdAt: DateTime.now(),
    );
    await _db.raw.insert('axes', axis.toMap());
    await _emitAxes();
    return axis;
  }

  Future<void> updateAxis(m.LifeAxis axis) async {
    await _db.raw.update(
      'axes',
      axis.toMap(),
      where: 'id = ?',
      whereArgs: [axis.id],
    );
    await _emitAxes();
  }

  Future<void> deleteAxis(String id) async {
    await _db.raw.delete('axes', where: 'id = ?', whereArgs: [id]);
    await _emitAxes();
    await _emitEntries();
  }

  Future<void> replaceAxes(List<m.LifeAxis> axes) async {
    await _db.raw.transaction((txn) async {
      await txn.delete('axes');
      for (final a in axes) {
        await txn.insert('axes', a.toMap());
      }
    });
    await _emitAxes();
    await _emitEntries();
  }

  // ---------- entries ----------

  Future<List<m.Entry>> listEntries({
    m.EntryKind? kind,
    bool? completed,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
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
    for (final l in links) {
      byEntry
          .putIfAbsent(l['entry_id']! as String, () => [])
          .add(l['axis_id']! as String);
    }
    return rows
        .map((r) => m.Entry.fromMap(r, axisIds: byEntry[r['id']] ?? const []))
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
        await txn.insert(
          'entry_axes',
          {'entry_id': entry.id, 'axis_id': aid},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await _emitEntries();
    return entry;
  }

  Future<m.Entry> createEntry({
    required String title,
    String body = '',
    m.EntryKind kind = m.EntryKind.note,
    DateTime? dueAt,
    int xp = 10,
    List<String> axisIds = const [],
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
    );
    return upsertEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    await _db.raw.delete('entries', where: 'id = ?', whereArgs: [id]);
    await _emitEntries();
  }

  Future<m.Entry> toggleTaskComplete(m.Entry entry) async {
    final updated = entry.copyWith(
      completedAt: entry.isCompleted ? null : DateTime.now(),
      clearCompleted: entry.isCompleted,
      updatedAt: DateTime.now(),
    );
    await upsertEntry(updated);
    return updated;
  }

  // ---------- scores ----------

  /// Compute a 0..100 axis score based on completed tasks within
  /// [_xpDecayWindow]. Linear decay: contribution = xp * (1 - age/window).
  Future<List<m.AxisScore>> computeScores() async {
    final axes = await listAxes();
    if (axes.isEmpty) return const [];
    final now = DateTime.now();
    final cutoff = now.subtract(_xpDecayWindow).millisecondsSinceEpoch;
    final rows = await _db.raw.rawQuery(
      '''
      SELECT ea.axis_id AS axis_id, e.completed_at AS completed_at, e.xp AS xp
      FROM entries e
      JOIN entry_axes ea ON ea.entry_id = e.id
      WHERE e.kind = ?
        AND e.completed_at IS NOT NULL
        AND e.completed_at >= ?
      ''',
      [m.EntryKind.task.name, cutoff],
    );
    final raw = <String, double>{for (final a in axes) a.id: 0.0};
    for (final r in rows) {
      final axisId = r['axis_id']! as String;
      final completedAt = r['completed_at']! as int;
      final xp = (r['xp'] as int?) ?? 0;
      final ageMs = now.millisecondsSinceEpoch - completedAt;
      final factor = 1.0 - (ageMs / _xpDecayWindow.inMilliseconds);
      if (factor <= 0) continue;
      raw[axisId] = (raw[axisId] ?? 0) + xp * factor;
    }
    return axes.map((axis) {
      final r = raw[axis.id] ?? 0.0;
      final v = (r / _maxAxisXpInWindow * 100).clamp(0.0, 100.0);
      return m.AxisScore(axis: axis, value: v, rawXp: r);
    }).toList();
  }
}
