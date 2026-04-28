import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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

/// A frozen-in-time record of an эпоха the user has already completed.
/// Captured the moment they tap «Новая эпоха», so the «Я» screen can
/// render that эпоха's tree read-only later. We store the axes the
/// user lived with during that эпоха (their names/symbols may differ
/// from the current ones) plus the final 0..100 score per axis at the
/// moment of transition, so the pentagon and tree visually freeze at
/// "where the user was when they closed that chapter".
class EpochSnapshot {
  const EpochSnapshot({
    required this.epoch,
    required this.tier,
    required this.axes,
    required this.scores,
    required this.startedAt,
    required this.endedAt,
    this.summary,
  });

  /// Which эпоха this snapshot represents.
  final int epoch;

  /// Last tier the user reached inside that эпоха before transitioning.
  final int tier;

  /// Snapshot of the axes (id/name/symbol) the user lived with during
  /// this эпоха. Stored verbatim so renaming axes later doesn't rewrite
  /// the past.
  final List<LifeAxis> axes;

  /// Final 0..100 score per axis at the moment of transition. Keys
  /// match `axes[i].id`. Missing keys treated as 0.
  final Map<String, double> scores;

  /// Boundaries of this эпоха.
  final DateTime startedAt;
  final DateTime endedAt;

  /// Optional one-liner the user typed at transition time (we don't
  /// prompt for it yet, reserved for a future "what did this эпоха
  /// teach you" screen).
  final String? summary;

  Map<String, dynamic> toJson() => {
        'epoch': epoch,
        'tier': tier,
        'axes': [for (final a in axes) a.toMap()],
        'scores': scores,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        if (summary != null) 'summary': summary,
      };

  factory EpochSnapshot.fromJson(Map<String, dynamic> json) {
    final rawAxes = (json['axes'] as List?) ?? const [];
    final rawScores = (json['scores'] as Map?) ?? const {};
    return EpochSnapshot(
      epoch: (json['epoch'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      axes: [
        for (final raw in rawAxes)
          if (raw is Map)
            LifeAxis.fromMap(raw.map(
              (k, v) => MapEntry(k.toString(), v as Object?),
            )),
      ],
      scores: <String, double>{
        for (final e in rawScores.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toDouble(),
      },
      startedAt: DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse((json['endedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      summary: json['summary'] as String?,
    );
  }
}

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
    this.currentEpoch = 1,
    this.epochStartedAt,
    this.epochAckedAt,
    this.epochTier = 1,
    this.epochRefreshedAt,
    this.epochArchive = const [],
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

  /// Which "эпоха" the user is currently living in. Starts at 1; bumps
  /// each time the user accepts the "Начать новую эпоху" ceremony
  /// after filling the pentagon to 100 %. Persists so the ceremony
  /// runs at most once per epoch.
  final int currentEpoch;
  final DateTime? epochStartedAt;

  /// Last moment the user acknowledged the "пентагон заполнен" dialog
  /// for the *current* epoch. Used to stop nagging them every time
  /// they reopen the self screen while already fully decorated.
  final DateTime? epochAckedAt;

  /// Inner "tier" inside the current epoch. Bumps every time the user
  /// picks «Углубиться» from the epoch overlay — signalling they want
  /// another round of tougher tasks along the same axes without
  /// redrawing them. Starts at 1, resets to 1 when a new эпоха begins.
  final int epochTier;

  /// Moment the user last tapped «Углубиться». Used as an override
  /// cutoff when computing axis scores — completions before this date
  /// no longer decay into the pentagon, so the tree visually resets
  /// and the user has to refill it in the new tier.
  final DateTime? epochRefreshedAt;

  /// Frozen records of all the эпохи the user has already completed.
  /// Each transition «Новая эпоха» pushes the *previous* state here
  /// before the new axes are generated, so the «Я» screen can let the
  /// user swipe back into a read-only view of past эпох. Empty for
  /// users who haven't transitioned yet OR whose transitions happened
  /// before this archive feature shipped (those are represented as a
  /// «архива нет» placeholder in the UI).
  final List<EpochSnapshot> epochArchive;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (birthdate != null) 'birthdate': birthdate!.toIso8601String(),
        'aspiration': aspiration,
        'interests': interests,
        'interestLevels': interestLevels,
        'painPoint': painPoint,
        'weeklyHours': weeklyHours,
        'updatedAt': updatedAt.toIso8601String(),
        'currentEpoch': currentEpoch,
        if (epochStartedAt != null)
          'epochStartedAt': epochStartedAt!.toIso8601String(),
        if (epochAckedAt != null)
          'epochAckedAt': epochAckedAt!.toIso8601String(),
        'epochTier': epochTier,
        if (epochRefreshedAt != null)
          'epochRefreshedAt': epochRefreshedAt!.toIso8601String(),
        if (epochArchive.isNotEmpty)
          'epochArchive': [for (final s in epochArchive) s.toJson()],
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
      currentEpoch: (json['currentEpoch'] as num?)?.toInt() ?? 1,
      epochStartedAt: (json['epochStartedAt'] as String?) != null
          ? DateTime.tryParse(json['epochStartedAt'] as String)
          : null,
      epochAckedAt: (json['epochAckedAt'] as String?) != null
          ? DateTime.tryParse(json['epochAckedAt'] as String)
          : null,
      epochTier: (json['epochTier'] as num?)?.toInt() ?? 1,
      epochRefreshedAt: (json['epochRefreshedAt'] as String?) != null
          ? DateTime.tryParse(json['epochRefreshedAt'] as String)
          : null,
      epochArchive: [
        for (final raw in (json['epochArchive'] as List?) ?? const [])
          if (raw is Map)
            EpochSnapshot.fromJson(raw.map(
              (k, v) => MapEntry(k.toString(), v),
            )),
      ],
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
    int? currentEpoch,
    DateTime? epochStartedAt,
    bool clearEpochStartedAt = false,
    DateTime? epochAckedAt,
    bool clearEpochAckedAt = false,
    int? epochTier,
    DateTime? epochRefreshedAt,
    bool clearEpochRefreshedAt = false,
    List<EpochSnapshot>? epochArchive,
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
      currentEpoch: currentEpoch ?? this.currentEpoch,
      epochStartedAt: clearEpochStartedAt
          ? null
          : (epochStartedAt ?? this.epochStartedAt),
      epochAckedAt:
          clearEpochAckedAt ? null : (epochAckedAt ?? this.epochAckedAt),
      epochTier: epochTier ?? this.epochTier,
      epochRefreshedAt: clearEpochRefreshedAt
          ? null
          : (epochRefreshedAt ?? this.epochRefreshedAt),
      epochArchive: epochArchive ?? this.epochArchive,
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
