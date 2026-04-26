import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';
import '../data/profile.dart';
import 'api_config.dart';
import 'auth_service.dart';

// Backend URL is resolved via `kDefaultBackendUrl` from api_config.dart
// (single source of truth). Used to be hardcoded here pointing at a
// different fly app than auth/sync, which silently broke cross-device
// sync because JWTs issued by one host were rejected by the other.

/// One generated roadmap task — a draft of an `Entry` we will create on import.
@immutable
class RoadmapDraft {
  const RoadmapDraft({
    required this.title,
    required this.body,
    required this.axisIds,
    required this.xp,
    this.dueAt,
    this.axisWeights = const {},
  });

  final String title;
  final String body;
  final List<String> axisIds;
  /// Optional explicit weights; keys subset of [axisIds]. Empty ⇒ even split.
  final Map<String, double> axisWeights;
  final int xp;
  final DateTime? dueAt;

  RoadmapDraft copyWith({
    String? title,
    String? body,
    List<String>? axisIds,
    Map<String, double>? axisWeights,
    int? xp,
    DateTime? dueAt,
    bool clearDue = false,
  }) =>
      RoadmapDraft(
        title: title ?? this.title,
        body: body ?? this.body,
        axisIds: axisIds ?? this.axisIds,
        axisWeights: axisWeights ?? this.axisWeights,
        xp: xp ?? this.xp,
        dueAt: clearDue ? null : (dueAt ?? this.dueAt),
      );
}

@immutable
class RoadmapResult {
  const RoadmapResult({
    required this.model,
    required this.summary,
    required this.tasks,
  });

  final String model;
  final String summary;
  final List<RoadmapDraft> tasks;
}

class RoadmapApiException implements Exception {
  RoadmapApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => 'RoadmapApiException(${status ?? '-'}): $message';
}

class RoadmapApi {
  RoadmapApi({
    String? baseUrl,
    http.Client? client,
    AuthService? authService,
  })  : _baseUrl = (baseUrl ?? _resolveBaseUrl()).trim().replaceAll(
              RegExp(r'/+$'),
              '',
            ),
        _client = client ?? http.Client(),
        _auth = authService;

  final String _baseUrl;
  final http.Client _client;
  final AuthService? _auth;

  static String _resolveBaseUrl() => kDefaultBackendUrl;

  String get baseUrl => _baseUrl;

  Future<RoadmapResult> generate({
    required String goal,
    required UserProfile? profile,
    required List<LifeAxis> axes,
    PersonalKnowledge? knowledge,
    int horizonDays = 30,
    int taskCount = 6,
  }) async {
    final uri = Uri.parse('$_baseUrl/roadmap/generate');
    final payload = {
      'goal': goal,
      'profile': {
        'name': profile?.name ?? '',
        'aspiration': profile?.aspiration ?? '',
        'pain_point': profile?.painPoint ?? '',
        'weekly_hours': profile?.weeklyHours ?? 5,
        'interest_levels': profile?.interestLevels ?? const <String, String>{},
      },
      // Optional persistent context. Backend will fold this into the
      // system prompt so the LLM stops generating things the user has
      // already done or that contradict known constraints.
      if (knowledge != null && knowledge.summary.isNotEmpty)
        'knowledge': {
          'summary': knowledge.summary,
          'goals': knowledge.goals,
          'constraints': knowledge.constraints,
          'recent_reflections': knowledge.recentReflections,
          'completed_highlights': knowledge.completedHighlights,
        },
      'axes': [
        for (final a in axes)
          {'id': a.id, 'name': a.name, 'symbol': a.symbol},
      ],
      'horizon_days': horizonDays,
      'task_count': taskCount,
    };

    final token = _auth?.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw RoadmapApiException(
        'Не выполнен вход в Google. Перезайдите и попробуйте снова.',
        status: 401,
      );
    }
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw RoadmapApiException('Не удалось связаться с сервером: $e');
    }

    if (response.statusCode >= 400) {
      String message = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        }
      } catch (_) {}
      throw RoadmapApiException(message, status: response.statusCode);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw RoadmapApiException('Сервер вернул некорректный JSON: $e');
    }

    final now = DateTime.now();
    final tasks = <RoadmapDraft>[];
    final raw = (json['tasks'] as List?) ?? const [];
    for (final item in raw) {
      if (item is! Map) continue;
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      var body = (item['body'] as String?)?.trim() ?? '';
      final rawSteps = (item['steps'] as List?) ?? const [];
      final steps = rawSteps
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      // Persist steps as a markdown checklist appended to the body. The
      // app's note/task editor renders plain text, so this is the
      // simplest way to surface the substeps without schema changes.
      if (steps.isNotEmpty) {
        final checklist = steps.map((s) => '- [ ] $s').join('\n');
        body = body.isEmpty ? checklist : '$body\n\n$checklist';
      }
      final xp = (item['xp'] as num?)?.toInt() ?? 20;
      final axisIds = ((item['axis_ids'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      // Optional axis_weights: { axisId: number } where the model tells
      // us how much of the task's XP belongs to each axis. Server has
      // already filtered to known axisIds; we just coerce + drop zeros.
      final rawWeights = item['axis_weights'];
      final axisWeights = <String, double>{};
      if (rawWeights is Map) {
        final allowed = axisIds.toSet();
        for (final e in rawWeights.entries) {
          final k = e.key;
          if (k is! String || !allowed.contains(k)) continue;
          final v = e.value;
          double? parsed;
          if (v is num) {
            parsed = v.toDouble();
          } else if (v is String) {
            parsed = double.tryParse(v);
          }
          if (parsed != null && parsed > 0) {
            axisWeights[k] = parsed;
          }
        }
      }
      final dueDays = (item['due_in_days'] as num?)?.toInt();
      final due = dueDays == null
          ? null
          : DateTime(now.year, now.month, now.day)
              .add(Duration(days: dueDays.clamp(0, 365)));
      tasks.add(
        RoadmapDraft(
          title: title,
          body: body,
          axisIds: axisIds,
          axisWeights: axisWeights,
          xp: xp.clamp(5, 100),
          dueAt: due,
        ),
      );
    }

    return RoadmapResult(
      model: (json['model'] as String?) ?? 'unknown',
      summary: (json['summary'] as String?)?.trim() ?? '',
      tasks: tasks,
    );
  }
}
