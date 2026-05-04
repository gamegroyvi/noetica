import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'generator_input.dart';
import 'generator_manifest.dart';
import 'generator_run_spec.dart';

/// Locally-authored generator. Stored as JSON in SharedPreferences for
/// the v1 release; PR #36 (sync) will migrate these into the SQLite
/// repo so manifests ride the existing sync engine across devices.
///
/// **Authoring surface (intentionally narrow for v1):**
/// - title / description (free-form, ≤ caps for sanity)
/// - icon (one of a fixed allow-list; raw `IconData` isn't safely
///   serialisable across releases — codepoints can shift between
///   tree-shake builds)
/// - promptSystem / promptUser (`{intent}`, `{notes}`, `{axis_id}`,
///   `{axis_id_name}` placeholders allowed)
///
/// **Hard-coded for v1 (will surface in the editor in later PRs):**
/// - one text input (`intent`) + one optional text input (`notes`).
/// - importSpec = task / today / xp 5 / no axis. Authors get a
///   "create N tasks for today" tool with one extra notes box.
/// - max_items = 10, temperature = 0.6.
@immutable
class UserManifest {
  const UserManifest({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.promptSystem,
    required this.promptUser,
    required this.intentLabel,
    required this.intentPlaceholder,
    required this.notesEnabled,
    required this.maxItems,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String promptSystem;
  final String promptUser;
  final String intentLabel;
  final String intentPlaceholder;
  final bool notesEnabled;
  final int maxItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Bare-minimum field validation. Returns null if the manifest is
  /// safe to save, otherwise a human-readable error.
  String? validate() {
    if (title.trim().isEmpty) return 'Назови инструмент.';
    if (title.trim().length > 60) {
      return 'Слишком длинный заголовок (>60 символов).';
    }
    if (description.length > 200) {
      return 'Слишком длинное описание (>200 символов).';
    }
    if (promptSystem.trim().isEmpty) {
      return 'Опиши, кто такой AI и какие у него правила (Системный промпт).';
    }
    if (promptUser.trim().isEmpty) {
      return 'Опиши, что AI должен сделать с интентом пользователя.';
    }
    if (promptSystem.length > 4000 || promptUser.length > 4000) {
      return 'Промпты слишком длинные (>4000 символов суммарно).';
    }
    if (intentLabel.trim().isEmpty) {
      return 'Опиши, о чём спрашивать пользователя (Подпись поля ввода).';
    }
    if (maxItems < 1 || maxItems > 30) {
      return 'Количество элементов: 1..30.';
    }
    return null;
  }

  UserManifest copyWith({
    String? title,
    String? description,
    String? iconKey,
    String? promptSystem,
    String? promptUser,
    String? intentLabel,
    String? intentPlaceholder,
    bool? notesEnabled,
    int? maxItems,
    DateTime? updatedAt,
  }) =>
      UserManifest(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        iconKey: iconKey ?? this.iconKey,
        promptSystem: promptSystem ?? this.promptSystem,
        promptUser: promptUser ?? this.promptUser,
        intentLabel: intentLabel ?? this.intentLabel,
        intentPlaceholder: intentPlaceholder ?? this.intentPlaceholder,
        notesEnabled: notesEnabled ?? this.notesEnabled,
        maxItems: maxItems ?? this.maxItems,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon_key': iconKey,
        'prompt_system': promptSystem,
        'prompt_user': promptUser,
        'intent_label': intentLabel,
        'intent_placeholder': intentPlaceholder,
        'notes_enabled': notesEnabled,
        'max_items': maxItems,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory UserManifest.fromJson(Map<String, Object?> json) => UserManifest(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        iconKey: (json['icon_key'] as String?) ?? 'auto_awesome',
        promptSystem: (json['prompt_system'] as String?) ?? '',
        promptUser: (json['prompt_user'] as String?) ?? '',
        intentLabel: (json['intent_label'] as String?) ?? 'Что нужно?',
        intentPlaceholder: (json['intent_placeholder'] as String?) ?? '',
        notesEnabled: (json['notes_enabled'] as bool?) ?? false,
        maxItems: (json['max_items'] as int?) ?? 10,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
                DateTime.now().toUtc(),
        updatedAt:
            DateTime.tryParse((json['updated_at'] as String?) ?? '') ??
                DateTime.now().toUtc(),
      );

  /// Convert this user manifest into the runtime-facing
  /// `GeneratorManifest`. The generator catalog mixes builtin and user
  /// manifests in the same list; both go through `GeneratorRunScreen`.
  GeneratorManifest toGenerator() {
    final inputs = <GeneratorInputField>[
      GeneratorInputText(
        id: 'intent',
        label: intentLabel,
        required: true,
        placeholder:
            intentPlaceholder.isEmpty ? null : intentPlaceholder,
        multiline: true,
        minLines: 2,
        maxLines: 5,
      ),
      if (notesEnabled)
        const GeneratorInputText(
          id: 'notes',
          label: 'Доп. пожелания (опционально)',
          multiline: true,
          minLines: 1,
          maxLines: 3,
        ),
    ];
    return GeneratorManifest(
      id: 'user/$id',
      title: title.trim(),
      description: description.trim(),
      icon: kUserManifestIcons[iconKey] ?? Icons.auto_awesome,
      status: GeneratorStatus.available,
      source: GeneratorSource.user,
      inputs: inputs,
      promptSystem: promptSystem,
      promptUser: promptUser,
      maxItems: maxItems,
      temperature: 0.6,
      // V1: tasks for today, no axis link, no challenge tag, 5 XP each.
      // Future: editor exposes import spec.
      importSpec: const GeneratorImportSpec(
        importAs: GeneratorImportTarget.task,
        dueStrategy: GeneratorDueStrategy.today,
        xpPerItem: 5,
      ),
    );
  }
}

/// Allow-list of icons users can pick for their custom tools. Keeping
/// the set small (a) avoids the "icon picker overload" UX trap and
/// (b) makes the iconKey ↔ IconData mapping resilient to Flutter's
/// tree-shaking of `Icons.*` codepoints across releases.
const Map<String, IconData> kUserManifestIcons = {
  'auto_awesome': Icons.auto_awesome_outlined,
  'lightbulb': Icons.lightbulb_outline,
  'rocket': Icons.rocket_launch_outlined,
  'palette': Icons.palette_outlined,
  'language': Icons.language_outlined,
  'fitness': Icons.fitness_center_outlined,
  'restaurant': Icons.restaurant_outlined,
  'school': Icons.school_outlined,
  'work': Icons.work_outline,
  'self_improvement': Icons.self_improvement_outlined,
  'spa': Icons.spa_outlined,
  'travel': Icons.flight_takeoff_outlined,
};

/// Default starter manifest seeded into the editor on "+ Создать".
UserManifest blankUserManifest({String? id}) {
  final now = DateTime.now().toUtc();
  return UserManifest(
    id: id ?? const Uuid().v4(),
    title: '',
    description: '',
    iconKey: 'auto_awesome',
    promptSystem:
        'Ты — внимательный AI-ассистент. Помогай пользователю '
        'разбивать желания на конкретные мини-шаги.\n\n'
        'ПРАВИЛА:\n'
        '1. Каждый элемент — конкретное действие (≤ 80 символов).\n'
        '2. Элементы должны быть выполнимы за один заход.\n'
        '3. Отвечай на том же языке, на котором пишет пользователь.',
    promptUser: 'Запрос пользователя:\n{intent}\n\n'
        'Сгенерируй до 8 шагов в массиве `items`.',
    intentLabel: 'Что нужно?',
    intentPlaceholder: 'опиши свободно, на любом языке',
    notesEnabled: false,
    maxItems: 8,
    createdAt: now,
    updatedAt: now,
  );
}

/// Persistent store for user-authored manifests. SharedPreferences
/// holds a JSON list under one key; the service emits a stream of
/// snapshots so providers can rebuild the catalog reactively.
class UserManifestStore {
  UserManifestStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _kListKey = 'noetica.user_manifests.v1';

  SharedPreferences? _prefs;
  final _changes = StreamController<List<UserManifest>>.broadcast();
  List<UserManifest>? _cached;

  Stream<List<UserManifest>> get changes async* {
    final initial = await load();
    yield initial;
    yield* _changes.stream;
  }

  /// Latest in-memory snapshot or null if `load()` hasn't been called.
  List<UserManifest>? get currentSync => _cached;

  Future<SharedPreferences> _prefsInstance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<UserManifest>> load() async {
    if (_cached != null) return _cached!;
    final prefs = await _prefsInstance();
    final raw = prefs.getString(_kListKey);
    final out = <UserManifest>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, Object?>) {
            final m = UserManifest.fromJson(item);
            if (m.id.isNotEmpty) out.add(m);
          }
        }
      } catch (e) {
        debugPrint('UserManifestStore.load: failed to parse: $e');
      }
    }
    _cached = out;
    return out;
  }

  Future<void> save(UserManifest manifest) async {
    final list = await load();
    final updated = [...list];
    final i = updated.indexWhere((m) => m.id == manifest.id);
    final next = manifest.copyWith(updatedAt: DateTime.now().toUtc());
    if (i >= 0) {
      updated[i] = next;
    } else {
      updated.add(next);
    }
    await _persist(updated);
  }

  Future<void> delete(String id) async {
    final list = await load();
    final updated = list.where((m) => m.id != id).toList();
    if (updated.length == list.length) return;
    await _persist(updated);
  }

  Future<void> _persist(List<UserManifest> list) async {
    final prefs = await _prefsInstance();
    final json = jsonEncode(list.map((m) => m.toJson()).toList());
    await prefs.setString(_kListKey, json);
    _cached = list;
    _changes.add(list);
  }

  void dispose() {
    _changes.close();
  }
}

/// `GeneratorRegistry` view over a snapshot of user manifests. The
/// composite registry asks each source for its current list at every
/// `list()` call; we cache the snapshot in `_userGeneratorListProvider`
/// (`providers.dart`) so the `ListView` rebuilds when the store
/// changes.
class UserGeneratorRegistry extends GeneratorRegistry {
  UserGeneratorRegistry(this._items);

  final List<GeneratorManifest> _items;

  @override
  List<GeneratorManifest> list() => List.unmodifiable(_items);
}
