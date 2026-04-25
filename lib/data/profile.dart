import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kProfileKey = 'noetica.profile.v1';

/// Predefined growth domains the user can choose between in the questionnaire.
/// Each maps to a default `LifeAxis` preset (name + symbol) used when we
/// generate the initial axis drafts on the next step. The IDs are stable
/// strings so we can persist the user's choices reliably.
class PriorityPreset {
  const PriorityPreset({
    required this.id,
    required this.label,
    required this.axisName,
    required this.axisSymbol,
  });

  final String id;
  final String label;
  final String axisName;
  final String axisSymbol;
}

const priorityPresets = <PriorityPreset>[
  PriorityPreset(
    id: 'health',
    label: 'Здоровье',
    axisName: 'Тело',
    axisSymbol: '◐',
  ),
  PriorityPreset(
    id: 'career',
    label: 'Карьера',
    axisName: 'Дело',
    axisSymbol: '■',
  ),
  PriorityPreset(
    id: 'knowledge',
    label: 'Знание',
    axisName: 'Ум',
    axisSymbol: '◇',
  ),
  PriorityPreset(
    id: 'relationships',
    label: 'Отношения',
    axisName: 'Связи',
    axisSymbol: '◯',
  ),
  PriorityPreset(
    id: 'soul',
    label: 'Внутренний покой',
    axisName: 'Душа',
    axisSymbol: '✦',
  ),
  PriorityPreset(
    id: 'creativity',
    label: 'Творчество',
    axisName: 'Творчество',
    axisSymbol: '✎',
  ),
  PriorityPreset(
    id: 'finance',
    label: 'Финансы',
    axisName: 'Финансы',
    axisSymbol: '₽',
  ),
  PriorityPreset(
    id: 'family',
    label: 'Семья',
    axisName: 'Семья',
    axisSymbol: '⌂',
  ),
];

class UserProfile {
  const UserProfile({
    required this.name,
    required this.aspiration,
    required this.priorities,
    required this.painPoint,
    required this.weeklyHours,
    required this.updatedAt,
    this.birthdate,
  });

  final String name;
  final DateTime? birthdate;
  final String aspiration;

  /// Selected priority preset IDs (1..N from [priorityPresets]).
  final List<String> priorities;
  final String painPoint;
  final int weeklyHours;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (birthdate != null) 'birthdate': birthdate!.toIso8601String(),
        'aspiration': aspiration,
        'priorities': priorities,
        'painPoint': painPoint,
        'weeklyHours': weeklyHours,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: (json['name'] as String?) ?? '',
      birthdate: (json['birthdate'] as String?) != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      aspiration: (json['aspiration'] as String?) ?? '',
      priorities: ((json['priorities'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      painPoint: (json['painPoint'] as String?) ?? '',
      weeklyHours: (json['weeklyHours'] as num?)?.toInt() ?? 5,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? name,
    DateTime? birthdate,
    bool clearBirthdate = false,
    String? aspiration,
    List<String>? priorities,
    String? painPoint,
    int? weeklyHours,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthdate: clearBirthdate ? null : (birthdate ?? this.birthdate),
      aspiration: aspiration ?? this.aspiration,
      priorities: priorities ?? this.priorities,
      painPoint: painPoint ?? this.painPoint,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfileService {
  Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfileKey);
  }
}
