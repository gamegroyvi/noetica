import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

/// Morning plan returned by the AI coach.
@immutable
class MorningPlan {
  const MorningPlan({
    required this.greeting,
    required this.focus,
    required this.tasks,
    required this.motivation,
  });

  final String greeting;
  final String focus;
  final List<String> tasks;
  final String motivation;

  factory MorningPlan.fromJson(Map<String, dynamic> json) {
    return MorningPlan(
      greeting: json['greeting'] as String? ?? '',
      focus: json['focus'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      motivation: json['motivation'] as String? ?? '',
    );
  }
}

/// Evening reflection returned by the AI coach.
@immutable
class EveningReflection {
  const EveningReflection({
    required this.summary,
    required this.wins,
    required this.improvements,
    required this.encouragement,
  });

  final String summary;
  final List<String> wins;
  final List<String> improvements;
  final String encouragement;

  factory EveningReflection.fromJson(Map<String, dynamic> json) {
    return EveningReflection(
      summary: json['summary'] as String? ?? '',
      wins: (json['wins'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      improvements: (json['improvements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      encouragement: json['encouragement'] as String? ?? '',
    );
  }
}

class CoachApiException implements Exception {
  CoachApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => 'CoachApiException($status): $message';
}

class CoachApi {
  CoachApi({AuthService? auth}) : _auth = auth;
  final AuthService? _auth;

  Future<MorningPlan> generateMorningPlan({
    required String name,
    required String aspiration,
    required List<String> axes,
    required List<String> activeTasks,
    required int streak,
  }) async {
    final body = await _call({
      'mode': 'morning',
      'name': name,
      'aspiration': aspiration,
      'axes': axes,
      'active_tasks': activeTasks,
      'streak': streak,
    });
    final morning = body['morning'] as Map<String, dynamic>?;
    if (morning == null) {
      throw CoachApiException('No morning data in response');
    }
    return MorningPlan.fromJson(morning);
  }

  Future<EveningReflection> generateEveningReflection({
    required String name,
    required List<String> completedToday,
    required List<String> remaining,
    required int entriesToday,
    required int streak,
  }) async {
    final body = await _call({
      'mode': 'evening',
      'name': name,
      'completed_today': completedToday,
      'remaining': remaining,
      'entries_today': entriesToday,
      'streak': streak,
    });
    final evening = body['evening'] as Map<String, dynamic>?;
    if (evening == null) {
      throw CoachApiException('No evening data in response');
    }
    return EveningReflection.fromJson(evening);
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    final token = _auth?.current?.accessToken;
    if (!kDevSkipAuth && (token == null || token.isEmpty)) {
      throw CoachApiException(
        'Не выполнен вход в Google. Перезайдите и попробуйте снова.',
        status: 401,
      );
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final url = Uri.parse('$kDefaultBackendUrl/coach/generate');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw CoachApiException(
        response.body,
        status: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
