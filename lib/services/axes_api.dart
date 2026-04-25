import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/profile.dart';
import 'auth_service.dart';

/// Mirrors `services/roadmap_api.dart` — same backend, different endpoint.
const String _kDefaultBackendUrl =
    'https://noetica-backend-nzlazosh.fly.dev';

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

  static String _resolveBaseUrl() {
    const fromDefine = String.fromEnvironment(
      'NOETICA_BACKEND_URL',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    return _kDefaultBackendUrl;
  }

  Future<AxesGenerationResult> generate({
    required UserProfile? profile,
    required List<String> interests,
    int count = 5,
  }) async {
    final uri = Uri.parse('$_baseUrl/onboarding/axes');
    final payload = {
      'profile': {
        'name': profile?.name ?? '',
        'aspiration': profile?.aspiration ?? '',
        'pain_point': profile?.painPoint ?? '',
        'weekly_hours': profile?.weeklyHours ?? 5,
      },
      'interests': interests,
      'count': count,
    };

    final token = _auth?.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw AxesApiException(
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
