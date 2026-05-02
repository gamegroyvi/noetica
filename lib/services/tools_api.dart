import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

/// One ingredient line item — name + free-form amount string. The
/// backend produces these for each meal and for the consolidated weekly
/// shopping list; we render them as bullets / checkbox lines in the
/// imported Entry bodies.
@immutable
class MenuIngredient {
  const MenuIngredient({required this.name, this.amount = ''});

  final String name;
  final String amount;

  Map<String, Object?> toJson() => {'name': name, 'amount': amount};

  factory MenuIngredient.fromJson(Map<String, Object?> json) => MenuIngredient(
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as String?) ?? '',
      );
}

/// One named meal in a day plan. KBJU fields are integers and may be 0
/// when the model failed to estimate them — the UI treats 0 as "—".
@immutable
class MenuMeal {
  const MenuMeal({
    required this.name,
    this.ingredients = const [],
    this.calories = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });

  final String name;
  final List<MenuIngredient> ingredients;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;

  factory MenuMeal.fromJson(Map<String, Object?> json) => MenuMeal(
        name: (json['name'] as String?) ?? '',
        ingredients: ((json['ingredients'] as List?) ?? const [])
            .whereType<Map<String, Object?>>()
            .map(MenuIngredient.fromJson)
            .toList(),
        calories: _asInt(json['calories']),
        protein: _asInt(json['protein']),
        fat: _asInt(json['fat']),
        carbs: _asInt(json['carbs']),
      );
}

@immutable
class MenuDay {
  const MenuDay({
    required this.dayName,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.snack,
  });

  final String dayName;
  final MenuMeal? breakfast;
  final MenuMeal? lunch;
  final MenuMeal? dinner;
  final MenuMeal? snack;

  factory MenuDay.fromJson(Map<String, Object?> json) => MenuDay(
        dayName: (json['day_name'] as String?) ?? '',
        breakfast: _maybeMeal(json['breakfast']),
        lunch: _maybeMeal(json['lunch']),
        dinner: _maybeMeal(json['dinner']),
        snack: _maybeMeal(json['snack']),
      );
}

@immutable
class MenuPlan {
  const MenuPlan({
    required this.model,
    required this.days,
    this.dailyAvgCalories = 0,
    this.notes = '',
    this.shoppingList = const {},
  });

  final String model;
  final List<MenuDay> days;
  final int dailyAvgCalories;
  final String notes;

  /// Map of category → ingredients. Keys are pre-translated by the
  /// backend (e.g. "Овощи и фрукты") so we don't need to localise on
  /// the client.
  final Map<String, List<MenuIngredient>> shoppingList;

  factory MenuPlan.fromJson(Map<String, Object?> json) {
    final rawShop = (json['shopping_list'] as Map?) ?? const {};
    final shop = <String, List<MenuIngredient>>{};
    rawShop.forEach((k, v) {
      if (k is! String || v is! List) return;
      shop[k] = v
          .whereType<Map<String, Object?>>()
          .map(MenuIngredient.fromJson)
          .toList();
    });
    return MenuPlan(
      model: (json['model'] as String?) ?? '',
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map<String, Object?>>()
          .map(MenuDay.fromJson)
          .toList(),
      dailyAvgCalories: _asInt(json['daily_avg_calories']),
      notes: (json['notes'] as String?) ?? '',
      shoppingList: shop,
    );
  }
}

/// Five canonical nutrition goals matching the Pydantic `MenuGoal`
/// literal on the backend. The `MenuRequest.goal` field is validated
/// server-side; sending anything else returns 422 before hitting the
/// LLM.
enum MenuGoal {
  loseWeight('lose_weight', 'Похудение'),
  health('health', 'Здоровье'),
  muscle('muscle', 'Набор мышц'),
  energy('energy', 'Энергия / спорт'),
  classic('classic', 'Классическое сбалансированное');

  const MenuGoal(this.wire, this.label);
  final String wire;
  final String label;

  static MenuGoal fromWire(String value) {
    for (final g in MenuGoal.values) {
      if (g.wire == value) return g;
    }
    return MenuGoal.classic;
  }
}

/// One day's micro-action returned by `/tools/habits/generate`.
@immutable
class HabitDay {
  const HabitDay({
    required this.dayIndex,
    required this.title,
    this.why = '',
  });

  final int dayIndex;
  final String title;
  final String why;

  factory HabitDay.fromJson(Map<String, Object?> json) => HabitDay(
        dayIndex: _asInt(json['day_index']),
        title: (json['title'] as String?) ?? '',
        why: (json['why'] as String?) ?? '',
      );
}

/// Full N-day micro-habit plan. `intent` echoes the user's free-form
/// goal so the import view can render it as the plan's title without
/// re-storing it.
@immutable
class HabitsPlan {
  const HabitsPlan({
    required this.model,
    required this.intent,
    required this.days,
    this.summary = '',
  });

  final String model;
  final String intent;
  final String summary;
  final List<HabitDay> days;

  factory HabitsPlan.fromJson(Map<String, Object?> json) => HabitsPlan(
        model: (json['model'] as String?) ?? '',
        intent: (json['intent'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        days: ((json['days'] as List?) ?? const [])
            .whereType<Map<String, Object?>>()
            .map(HabitDay.fromJson)
            .toList(),
      );
}

class ToolsApiException implements Exception {
  ToolsApiException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => 'ToolsApiException(${status ?? '-'}): $message';
}

/// Client for `/tools/menu/*` endpoints. Mirrors the existing
/// [AxesApi] / [RoadmapApi] shape: takes an optional [baseUrl] override
/// so providers can rebuild it when the user switches backends without
/// restarting the app.
class ToolsApi {
  ToolsApi({
    String? baseUrl,
    http.Client? client,
    AuthService? authService,
    Duration generateTimeout = const Duration(seconds: 90),
    Duration recipeTimeout = const Duration(seconds: 60),
  })  : _baseUrl = (baseUrl ?? kDefaultBackendUrl).trim().replaceAll(
              RegExp(r'/+$'),
              '',
            ),
        _client = client ?? http.Client(),
        _auth = authService,
        _generateTimeout = generateTimeout,
        _recipeTimeout = recipeTimeout;

  final String _baseUrl;
  final http.Client _client;
  final AuthService? _auth;
  final Duration _generateTimeout;
  final Duration _recipeTimeout;

  String get baseUrl => _baseUrl;

  Future<MenuPlan> generateMenu({
    required MenuGoal goal,
    required int servings,
    String restrictions = '',
    String extraNotes = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/tools/menu/generate');
    final payload = <String, Object?>{
      'goal': goal.wire,
      'servings': servings,
      'restrictions': restrictions,
      'extra_notes': extraNotes,
    };
    final json = await _post(uri, payload, _generateTimeout);
    return MenuPlan.fromJson(json);
  }

  Future<HabitsPlan> generateHabits({
    required String intent,
    required int durationDays,
    String axisHint = '',
    String notes = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/tools/habits/generate');
    final payload = <String, Object?>{
      'intent': intent,
      'duration_days': durationDays,
      'axis_hint': axisHint,
      'notes': notes,
    };
    final json = await _post(uri, payload, _generateTimeout);
    return HabitsPlan.fromJson(json);
  }

  Future<String> generateRecipe({
    required String mealName,
    required List<MenuIngredient> ingredients,
    required MenuGoal goal,
    required int servings,
  }) async {
    final uri = Uri.parse('$_baseUrl/tools/menu/recipe');
    final payload = <String, Object?>{
      'meal_name': mealName,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'goal': goal.wire,
      'servings': servings,
    };
    final json = await _post(uri, payload, _recipeTimeout);
    return (json['markdown'] as String?) ?? '';
  }

  Future<Map<String, Object?>> _post(
    Uri uri,
    Map<String, Object?> payload,
    Duration timeout,
  ) async {
    final token = _auth?.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw ToolsApiException(
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
          .timeout(timeout);
    } catch (e) {
      throw ToolsApiException('Не удалось связаться с сервером: $e');
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
        unawaited(_auth?.handleUnauthorized() ?? Future.value());
        throw ToolsApiException(
          'Сессия истекла. Зайдите через Google ещё раз.',
          status: 401,
        );
      }
      throw ToolsApiException(message, status: response.statusCode);
    }
    final Map<String, Object?> json;
    try {
      json = jsonDecode(response.body) as Map<String, Object?>;
    } catch (e) {
      throw ToolsApiException('Сервер вернул некорректный JSON: $e');
    }
    return json;
  }

  void close() => _client.close();
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final v = num.tryParse(raw);
    return v?.round() ?? 0;
  }
  return 0;
}

MenuMeal? _maybeMeal(Object? raw) {
  if (raw == null) return null;
  if (raw is Map<String, Object?>) {
    if (raw.isEmpty) return null;
    return MenuMeal.fromJson(raw);
  }
  return null;
}
