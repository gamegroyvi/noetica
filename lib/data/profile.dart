import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kProfileKey = 'noetica.profile.v1';

/// Suggested interest chips shown in the questionnaire. They are *only*
/// label hints — the user can add custom phrases freely, and the AI is
/// what actually decides the axis names. We deliberately keep this list
/// short and broad so it never feels like a hard menu.
const List<String> suggestedInterests = <String>[
  'Спорт',
  'Чтение',
  'Изучение языков',
  'Программирование',
  'Музыка',
  'Рисование',
  'Медитация',
  'Дружба',
  'Семья',
  'Финансы',
  'Карьера',
  'Предпринимательство',
  'Питание',
  'Сон',
  'Путешествия',
  'Письмо',
  'Ремесла',
];

/// Self-assessed proficiency on an interest. Used by the LLM to pick task
/// difficulty (e.g. an "expert" Flutter dev gets architecture tasks, a
/// "novice" gets tutorial-style tasks).
const List<String> kInterestLevels = <String>[
  'novice',
  'learning',
  'confident',
  'expert',
];

const Map<String, String> kInterestLevelLabels = <String, String>{
  'novice': 'Новичок',
  'learning': 'Учусь',
  'confident': 'Уверенно',
  'expert': 'Эксперт',
};

class UserProfile {
  const UserProfile({
    required this.name,
    required this.aspiration,
    required this.interests,
    required this.interestLevels,
    required this.painPoint,
    required this.weeklyHours,
    required this.updatedAt,
    this.birthdate,
  });

  final String name;
  final DateTime? birthdate;
  final String aspiration;

  /// Free-form list of interests / desired growth areas the user typed in
  /// the questionnaire. Backend uses these to design personalised axes.
  final List<String> interests;

  /// Self-assessed level per interest. Keys must match `interests`; values
  /// are one of `kInterestLevels`. If a key is missing, treat as 'novice'.
  final Map<String, String> interestLevels;
  final String painPoint;
  final int weeklyHours;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (birthdate != null) 'birthdate': birthdate!.toIso8601String(),
        'aspiration': aspiration,
        'interests': interests,
        'interestLevels': interestLevels,
        'painPoint': painPoint,
        'weeklyHours': weeklyHours,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Backward-compat: older saves used 'priorities' (preset IDs); fall
    // back to those if 'interests' is missing so existing users don't
    // lose what they typed.
    final rawInterests = (json['interests'] as List?) ?? const [];
    final rawPriorities = (json['priorities'] as List?) ?? const [];
    final mergedInterests = <String>[
      ...rawInterests.whereType<String>(),
      if (rawInterests.isEmpty) ...rawPriorities.whereType<String>(),
    ];
    final rawLevels = (json['interestLevels'] as Map?) ?? const {};
    final levels = <String, String>{
      for (final e in rawLevels.entries)
        if (e.key is String && e.value is String && kInterestLevels.contains(e.value))
          e.key as String: e.value as String,
    };
    return UserProfile(
      name: (json['name'] as String?) ?? '',
      birthdate: (json['birthdate'] as String?) != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      aspiration: (json['aspiration'] as String?) ?? '',
      interests: mergedInterests,
      interestLevels: levels,
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
    List<String>? interests,
    Map<String, String>? interestLevels,
    String? painPoint,
    int? weeklyHours,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthdate: clearBirthdate ? null : (birthdate ?? this.birthdate),
      aspiration: aspiration ?? this.aspiration,
      interests: interests ?? this.interests,
      interestLevels: interestLevels ?? this.interestLevels,
      painPoint: painPoint ?? this.painPoint,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfileService {
  /// Broadcast every save/clear so the sync layer can push immediately.
  static final _changes = StreamController<UserProfile?>.broadcast();

  /// Stream of profile updates (null = cleared). Sync layer listens to push
  /// changes promptly without polling.
  static Stream<UserProfile?> get changes => _changes.stream;

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
    if (!_changes.isClosed) _changes.add(profile);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfileKey);
    if (!_changes.isClosed) _changes.add(null);
  }
}
