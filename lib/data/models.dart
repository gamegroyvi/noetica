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
    DateTime? updatedAt,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String name;

  /// A 1-2 character symbol shown in chips/cards. Black & white friendly.
  final String symbol;

  /// 0..n - controls vertex order on the pentagon.
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  LifeAxis copyWith({
    String? name,
    String? symbol,
    int? position,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) =>
      LifeAxis(
        id: id,
        name: name ?? this.name,
        symbol: symbol ?? this.symbol,
        position: position ?? this.position,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'symbol': symbol,
        'position': position,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
      };

  factory LifeAxis.fromMap(Map<String, Object?> m) => LifeAxis(
        id: m['id']! as String,
        name: m['name']! as String,
        symbol: m['symbol']! as String,
        position: (m['position'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt: m['updated_at'] == null
            ? DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int)
            : DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deleted_at']! as int),
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
    int? baseXp,
    this.dueAt,
    this.completedAt,
    this.deletedAt,
    this.axisIds = const [],
    this.axisWeights = const {},
  }) : baseXp = baseXp ?? xp;

  final String id;
  final String title;
  final String body;
  final EntryKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  /// XP awarded to each linked axis on completion. 1..100. May be
  /// adjusted by the post-completion reflection (easy/normal/hard/
  /// blocked → 0.7×/1.0×/1.2×/0.5×). Always derived from [baseXp] so
  /// re-completing a task doesn't compound the multiplier.
  final int xp;

  /// The XP this task originally shipped with — set at creation time
  /// and never modified after. The reflection multiplier is always
  /// applied to `baseXp`, never to the (possibly already-adjusted)
  /// `xp` value, so re-opening + re-completing a "hard" task gives the
  /// same xp it would have given on the first completion.
  final int baseXp;

  final List<String> axisIds;

  /// Optional per-axis split of this task's XP. Keys are subset of
  /// [axisIds]; values normalised to sum to 1.0 at score time. Empty
  /// map ⇒ fall back to even 1/N split, which matches every legacy
  /// task (including v3-and-earlier rows after migration).
  final Map<String, double> axisWeights;

  bool get isTask => kind == EntryKind.task;
  bool get isCompleted => completedAt != null;
  bool get isDeleted => deletedAt != null;

  Entry copyWith({
    String? title,
    String? body,
    EntryKind? kind,
    DateTime? updatedAt,
    DateTime? dueAt,
    DateTime? completedAt,
    DateTime? deletedAt,
    int? xp,
    int? baseXp,
    List<String>? axisIds,
    Map<String, double>? axisWeights,
    bool clearDue = false,
    bool clearCompleted = false,
    bool clearDeleted = false,
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
        deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
        xp: xp ?? this.xp,
        baseXp: baseXp ?? this.baseXp,
        axisIds: axisIds ?? this.axisIds,
        axisWeights: axisWeights ?? this.axisWeights,
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
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'xp': xp,
        'base_xp': baseXp,
      };

  factory Entry.fromMap(
    Map<String, Object?> m, {
    List<String> axisIds = const [],
    Map<String, double> axisWeights = const {},
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
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deleted_at']! as int),
        xp: (m['xp'] as int?) ?? 10,
        baseXp: (m['base_xp'] as int?) ?? (m['xp'] as int?) ?? 10,
        axisIds: axisIds,
        axisWeights: axisWeights,
      );
}

/// How a task felt to the user when they finished it. Captured optionally
/// in a small bottom sheet right after completion. Powers two things:
///   1. XP adjustment — a task that turned out hard pays a bit more,
///      one that flew by pays a bit less.
///   2. Personal knowledge base — feeds back into future LLM prompts so
///      the assistant stops generating content the user has clearly
///      mastered (or has clearly bounced off).
enum ReflectionStatus { easy, normal, hard, blocked }

extension ReflectionStatusX on ReflectionStatus {
  String get label {
    switch (this) {
      case ReflectionStatus.easy:
        return 'Легко';
      case ReflectionStatus.normal:
        return 'Норм';
      case ReflectionStatus.hard:
        return 'Сложно';
      case ReflectionStatus.blocked:
        return 'Не пошло';
    }
  }

  /// XP multiplier applied to the base award.
  double get xpFactor {
    switch (this) {
      case ReflectionStatus.easy:
        return 0.8;
      case ReflectionStatus.normal:
        return 1.0;
      case ReflectionStatus.hard:
        return 1.2;
      case ReflectionStatus.blocked:
        return 0.5;
    }
  }
}

@immutable
class TaskReflection {
  const TaskReflection({
    required this.id,
    required this.entryId,
    required this.status,
    required this.createdAt,
    this.outcome = '',
    this.difficulties = '',
    this.actualMinutes,
  });

  final String id;
  final String entryId;
  final ReflectionStatus status;
  final DateTime createdAt;

  /// "What worked / what got done." Free-form, may be empty.
  final String outcome;

  /// "What got in the way." Free-form, may be empty.
  final String difficulties;

  /// Self-reported actual time spent. Optional.
  final int? actualMinutes;

  TaskReflection copyWith({
    ReflectionStatus? status,
    String? outcome,
    String? difficulties,
    int? actualMinutes,
  }) =>
      TaskReflection(
        id: id,
        entryId: entryId,
        status: status ?? this.status,
        createdAt: createdAt,
        outcome: outcome ?? this.outcome,
        difficulties: difficulties ?? this.difficulties,
        actualMinutes: actualMinutes ?? this.actualMinutes,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'entry_id': entryId,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'outcome': outcome,
        'difficulties': difficulties,
        'actual_minutes': actualMinutes,
      };

  factory TaskReflection.fromMap(Map<String, Object?> m) => TaskReflection(
        id: m['id']! as String,
        entryId: m['entry_id']! as String,
        status: ReflectionStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => ReflectionStatus.normal,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        outcome: (m['outcome'] as String?) ?? '',
        difficulties: (m['difficulties'] as String?) ?? '',
        actualMinutes: m['actual_minutes'] as int?,
      );
}

/// Persistent, slowly-changing summary of who the user is, accumulated
/// from onboarding answers, weekly reflections, and task reflections.
/// Kept as a single JSON document instead of a normalised model because
/// almost everything in here is free-form text destined for an LLM
/// system prompt anyway.
@immutable
class PersonalKnowledge {
  const PersonalKnowledge({
    required this.summary,
    required this.goals,
    required this.constraints,
    required this.preferences,
    required this.completedHighlights,
    required this.recentReflections,
    required this.updatedAt,
  });

  final String summary;
  final List<String> goals;
  final List<String> constraints;
  final Map<String, String> preferences;
  final List<String> completedHighlights;
  final List<String> recentReflections;
  final DateTime updatedAt;

  factory PersonalKnowledge.empty() => PersonalKnowledge(
        summary: '',
        goals: const [],
        constraints: const [],
        preferences: const {},
        completedHighlights: const [],
        recentReflections: const [],
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  PersonalKnowledge copyWith({
    String? summary,
    List<String>? goals,
    List<String>? constraints,
    Map<String, String>? preferences,
    List<String>? completedHighlights,
    List<String>? recentReflections,
    DateTime? updatedAt,
  }) =>
      PersonalKnowledge(
        summary: summary ?? this.summary,
        goals: goals ?? this.goals,
        constraints: constraints ?? this.constraints,
        preferences: preferences ?? this.preferences,
        completedHighlights: completedHighlights ?? this.completedHighlights,
        recentReflections: recentReflections ?? this.recentReflections,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, Object?> toJson() => {
        'summary': summary,
        'goals': goals,
        'constraints': constraints,
        'preferences': preferences,
        'completedHighlights': completedHighlights,
        'recentReflections': recentReflections,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory PersonalKnowledge.fromJson(Map<String, Object?> j) =>
      PersonalKnowledge(
        summary: (j['summary'] as String?) ?? '',
        goals: ((j['goals'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        constraints: ((j['constraints'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        preferences: ((j['preferences'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        completedHighlights:
            ((j['completedHighlights'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(),
        recentReflections: ((j['recentReflections'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (j['updatedAt'] as int?) ?? 0,
        ),
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
