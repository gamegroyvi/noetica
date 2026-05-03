import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';
import '../data/profile.dart';
import 'api_config.dart';
import 'auth_service.dart';

@immutable
class AxisDraft {
  const AxisDraft({
    required this.name,
    required this.symbol,
    this.description = '',
  });

  final String name;
  final String symbol;
  final String description;
}

@immutable
class AxesGenerationResult {
  const AxesGenerationResult({required this.model, required this.axes});

  final String model;
  final List<AxisDraft> axes;
}

class AxesApiException implements Exception {
  AxesApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => 'AxesApiException(${status ?? '-'}): $message';
}

class AxesApi {
  AxesApi({
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

  Future<AxesGenerationResult> generate({
    required UserProfile? profile,
    required List<String> interests,
    PersonalKnowledge? knowledge,
    int count = 5,
    String? regenHint,
    int? variationSeed,
  }) async {
    final uri = Uri.parse('$_baseUrl/onboarding/axes');
    final payload = <String, dynamic>{
      'profile': {
        'name': profile?.name ?? '',
        'aspiration': profile?.aspiration ?? '',
        'pain_point': profile?.painPoint ?? '',
        'weekly_hours': profile?.weeklyHours ?? 5,
        'interest_levels': profile?.interestLevels ?? const <String, String>{},
      },
      if (knowledge != null && knowledge.summary.isNotEmpty)
        'knowledge': {
          'summary': knowledge.summary,
          'goals': knowledge.goals,
          'constraints': knowledge.constraints,
          'recent_reflections': knowledge.recentReflections,
          'completed_highlights': knowledge.completedHighlights,
        },
      'interests': interests,
      'count': count,
      if (regenHint != null && regenHint.trim().isNotEmpty)
        'regen_hint': regenHint.trim(),
      if (variationSeed != null) 'variation_seed': variationSeed,
    };

    final token = _auth?.current?.accessToken;
    if (!kDevSkipAuth && (token == null || token.isEmpty)) {
      throw AxesApiException(
        'Не выполнен вход в Google. Перезайдите и попробуйте снова.',
        status: 401,
      );
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw AxesApiException('Не удалось связаться с сервером: $e');
    }

    if (response.statusCode >= 400) {
      String message = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        }
      } catch (_) {}
      if (response.statusCode == 401) {
        // Token is stale (backend rotated JWT_SECRET or we switched
        // Fly apps). Clear it so AuthGate forces a re-login instead of
        // letting the user stare at "Gemini doesn't work".
        unawaited(_auth?.handleUnauthorized() ?? Future.value());
        throw AxesApiException(
          'Сессия истекла. Зайдите через Google ещё раз.',
          status: 401,
        );
      }
      throw AxesApiException(message, status: response.statusCode);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw AxesApiException('Сервер вернул некорректный JSON: $e');
    }

    final axes = <AxisDraft>[];
    final raw = (json['axes'] as List?) ?? const [];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = (item['name'] as String?)?.trim() ?? '';
      final symbol = (item['symbol'] as String?)?.trim() ?? '';
      final description = (item['description'] as String?)?.trim() ?? '';
      if (name.isEmpty || symbol.isEmpty) continue;
      axes.add(AxisDraft(
        name: name,
        symbol: symbol,
        description: description,
      ));
    }

    return AxesGenerationResult(
      model: (json['model'] as String?) ?? '',
      axes: axes,
    );
  }
}
