/// Domain models for Noetica.
///
/// All entities use string UUIDs and millisecond Unix timestamps so they can
/// be serialised cleanly to SQLite and (later) to a sync layer.
library;

import 'package:flutter/foundation.dart';

enum EntryKind { note, task }

/// A single user-defined growth axis (one vertex of the pentagon).
@immutable
class LifeAxis {
  const LifeAxis({
    required this.id,
    required this.name,
    required this.symbol,
    required this.position,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// A 1-2 character symbol shown in chips/cards. Black & white friendly.
  final String symbol;

  /// 0..n - controls vertex order on the pentagon.
  final int position;
  final DateTime createdAt;

  LifeAxis copyWith({String? name, String? symbol, int? position}) => LifeAxis(
        id: id,
        name: name ?? this.name,
        symbol: symbol ?? this.symbol,
        position: position ?? this.position,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'symbol': symbol,
        'position': position,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory LifeAxis.fromMap(Map<String, Object?> m) => LifeAxis(
        id: m['id']! as String,
        name: m['name']! as String,
        symbol: m['symbol']! as String,
        position: (m['position'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );
}

/// A single piece of content in the system. Notes and tasks share the same
/// table — a task is just an entry with `kind == task` and an optional [dueAt].
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.xp,
    this.dueAt,
    this.completedAt,
    this.axisIds = const [],
  });

  final String id;
  final String title;
  final String body;
  final EntryKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueAt;
  final DateTime? completedAt;

  /// XP awarded to each linked axis on completion. 1..100.
  final int xp;

  final List<String> axisIds;

  bool get isTask => kind == EntryKind.task;
  bool get isCompleted => completedAt != null;

  Entry copyWith({
    String? title,
    String? body,
    EntryKind? kind,
    DateTime? updatedAt,
    DateTime? dueAt,
    DateTime? completedAt,
    int? xp,
    List<String>? axisIds,
    bool clearDue = false,
    bool clearCompleted = false,
  }) =>
      Entry(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        kind: kind ?? this.kind,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        dueAt: clearDue ? null : (dueAt ?? this.dueAt),
        completedAt:
            clearCompleted ? null : (completedAt ?? this.completedAt),
        xp: xp ?? this.xp,
        axisIds: axisIds ?? this.axisIds,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'kind': kind.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'due_at': dueAt?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'xp': xp,
      };

  factory Entry.fromMap(
    Map<String, Object?> m, {
    List<String> axisIds = const [],
  }) =>
      Entry(
        id: m['id']! as String,
        title: m['title']! as String,
        body: (m['body'] as String?) ?? '',
        kind: EntryKind.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => EntryKind.note,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
        dueAt: m['due_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_at']! as int),
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completed_at']! as int),
        xp: (m['xp'] as int?) ?? 10,
        axisIds: axisIds,
      );
}

/// Aggregated XP score for a single axis, normalised to 0..100.
@immutable
class AxisScore {
  const AxisScore({
    required this.axis,
    required this.value,
    required this.rawXp,
  });

  final LifeAxis axis;

  /// 0..100 — used for pentagon rendering.
  final double value;

  /// Sum of decayed XP contributions over the look-back window.
  final double rawXp;
}
