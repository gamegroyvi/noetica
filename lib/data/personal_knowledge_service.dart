import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persists the user's [PersonalKnowledge] document and lets the sync /
/// LLM layers subscribe to updates. Stored in SharedPreferences as a
/// single JSON blob — the document is intentionally small (≤ ~4 KB) so
/// the overhead is fine and we avoid a SQLite migration just for one
/// row.
class PersonalKnowledgeService {
  static const _kKey = 'noetica.personal_knowledge.v1';
  static final _changes = StreamController<PersonalKnowledge>.broadcast();
  static Stream<PersonalKnowledge> get changes => _changes.stream;

  Future<PersonalKnowledge> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return PersonalKnowledge.empty();
    try {
      return PersonalKnowledge.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (_) {
      return PersonalKnowledge.empty();
    }
  }

  Future<void> save(PersonalKnowledge knowledge) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(knowledge.toJson()));
    if (!_changes.isClosed) _changes.add(knowledge);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    if (!_changes.isClosed) _changes.add(PersonalKnowledge.empty());
  }

  /// Append a freshly captured reflection summary to `recentReflections`,
  /// trimming to the most recent N. Also adds the task title to
  /// `completedHighlights` so future LLM prompts know what the user has
  /// already done.
  Future<PersonalKnowledge> recordReflection({
    required String taskTitle,
    required ReflectionStatus status,
    required String outcome,
    required String difficulties,
  }) async {
    final current = await load();
    final summaryLine = _buildLine(
      title: taskTitle,
      status: status,
      outcome: outcome,
      difficulties: difficulties,
    );
    final highlight = '${status.label}: $taskTitle';

    PersonalKnowledge next = current.copyWith(
      recentReflections: _prepend(
        current.recentReflections,
        summaryLine,
        max: 5,
      ),
      completedHighlights: _prepend(
        current.completedHighlights,
        highlight,
        max: 10,
      ),
      updatedAt: DateTime.now(),
    );
    await save(next);
    return next;
  }

  /// Set the high-level descriptive fields. Called from onboarding.
  Future<PersonalKnowledge> recordOnboarding({
    required String summary,
    required List<String> goals,
    required List<String> constraints,
  }) async {
    final current = await load();
    final next = current.copyWith(
      summary: summary,
      goals: goals,
      constraints: constraints,
      updatedAt: DateTime.now(),
    );
    await save(next);
    return next;
  }

  static String _buildLine({
    required String title,
    required ReflectionStatus status,
    required String outcome,
    required String difficulties,
  }) {
    final parts = <String>['[${status.label}] $title'];
    if (outcome.isNotEmpty) parts.add('+ $outcome');
    if (difficulties.isNotEmpty) parts.add('- $difficulties');
    return parts.join(' / ');
  }

  static List<String> _prepend(List<String> list, String item, {required int max}) {
    final out = <String>[item, ...list.where((e) => e != item)];
    if (out.length > max) return out.sublist(0, max);
    return out;
  }
}
