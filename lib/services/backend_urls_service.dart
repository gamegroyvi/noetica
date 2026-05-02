import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_config.dart';

/// A single named backend deployment the app can talk to.
@immutable
class BackendEndpoint {
  const BackendEndpoint({
    required this.id,
    required this.name,
    required this.url,
  });

  final String id;
  final String name;
  final String url;

  BackendEndpoint copyWith({String? name, String? url}) => BackendEndpoint(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'url': url,
      };

  factory BackendEndpoint.fromJson(Map<String, Object?> json) =>
      BackendEndpoint(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is BackendEndpoint &&
      other.id == id &&
      other.name == name &&
      other.url == url;

  @override
  int get hashCode => Object.hash(id, name, url);
}

/// Snapshot of the [BackendUrlsService] state. Riverpod streams these so
/// every UI/widget that depends on the active URL automatically rebuilds
/// when the user adds, edits, removes or switches backends.
@immutable
class BackendUrlsState {
  const BackendUrlsState({
    required this.endpoints,
    required this.activeId,
  });

  final List<BackendEndpoint> endpoints;
  final String? activeId;

  /// Resolved active backend URL — falls back to the compile-time default
  /// when no endpoints are stored yet (first run, or after the user wiped
  /// every URL by hand).
  String get activeUrl {
    if (endpoints.isEmpty) return kDefaultBackendUrl;
    if (activeId != null) {
      for (final e in endpoints) {
        if (e.id == activeId) return e.url;
      }
    }
    return endpoints.first.url;
  }

  /// Other endpoints to try if the active one fails — preserves order so
  /// callers can implement deterministic round-robin fallback.
  List<BackendEndpoint> get fallbacks {
    final out = <BackendEndpoint>[];
    for (final e in endpoints) {
      if (e.id != activeId) out.add(e);
    }
    return out;
  }
}

/// Persists a list of backend deployments and which one is currently
/// active. Used by every API client (auth, sync, roadmap, axes, tools)
/// to resolve `_baseUrl` instead of reading the compile-time
/// [kDefaultBackendUrl] directly.
///
/// On first launch we seed the list with [kDefaultBackendUrl] under the
/// label "По умолчанию" so existing installs don't lose their backend.
class BackendUrlsService {
  BackendUrlsService({SharedPreferences? prefs, Uuid? uuid})
      : _prefs = prefs,
        _uuid = uuid ?? const Uuid();

  static const _kListKey = 'noetica.backends.v1';
  static const _kActiveKey = 'noetica.backends.active.v1';

  SharedPreferences? _prefs;
  final Uuid _uuid;

  final _changes = StreamController<BackendUrlsState>.broadcast();
  BackendUrlsState? _cached;
  bool _loaded = false;

  /// Stream of state snapshots. Emits the current snapshot on subscription
  /// (so consumers don't need to remember to call [load] separately).
  Stream<BackendUrlsState> get changes async* {
    final state = await load();
    yield state;
    yield* _changes.stream;
  }

  /// Latest in-memory state (or `null` if [load] has never been called).
  BackendUrlsState? get currentSync => _cached;

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Synchronously expose the active URL when [load] has been called at
  /// least once; otherwise fall back to the compile-time default. Used by
  /// services that are constructed before Riverpod has resolved the
  /// async provider (e.g. unit tests or the first frame of cold start).
  String get activeUrlOrDefault =>
      _cached?.activeUrl ?? kDefaultBackendUrl;

  Future<BackendUrlsState> load() async {
    if (_loaded && _cached != null) return _cached!;
    final prefs = await _prefsInstance();
    final raw = prefs.getString(_kListKey);
    final endpoints = <BackendEndpoint>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, Object?>) {
            final ep = BackendEndpoint.fromJson(item);
            if (ep.id.isNotEmpty && ep.url.isNotEmpty) endpoints.add(ep);
          }
        }
      } catch (e) {
        debugPrint('BackendUrlsService.load: failed to parse: $e');
      }
    }
    String? activeId = prefs.getString(_kActiveKey);
    // Seed the default endpoint on first run so the user has something
    // to switch from, and so existing installs continue to talk to the
    // same Fly app they were before.
    if (endpoints.isEmpty) {
      final seeded = BackendEndpoint(
        id: _uuid.v4(),
        name: 'По умолчанию',
        url: kDefaultBackendUrl,
      );
      endpoints.add(seeded);
      activeId = seeded.id;
      await _persist(endpoints, activeId, prefs: prefs);
    } else if (activeId == null ||
        endpoints.indexWhere((e) => e.id == activeId) == -1) {
      activeId = endpoints.first.id;
      await prefs.setString(_kActiveKey, activeId);
    }
    _cached = BackendUrlsState(endpoints: endpoints, activeId: activeId);
    _loaded = true;
    return _cached!;
  }

  Future<BackendEndpoint> add({
    required String name,
    required String url,
    bool makeActive = false,
  }) async {
    final state = await load();
    final cleanUrl = _normalize(url);
    if (cleanUrl.isEmpty) {
      throw const FormatException('URL не должен быть пустым.');
    }
    final ep = BackendEndpoint(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? cleanUrl : name.trim(),
      url: cleanUrl,
    );
    final next = [...state.endpoints, ep];
    final activeId = makeActive ? ep.id : state.activeId ?? ep.id;
    await _commit(next, activeId);
    return ep;
  }

  Future<void> update(String id, {String? name, String? url}) async {
    final state = await load();
    final next = <BackendEndpoint>[];
    var found = false;
    for (final e in state.endpoints) {
      if (e.id == id) {
        found = true;
        next.add(e.copyWith(
          name: name?.trim().isEmpty == true ? e.name : name?.trim(),
          url: url == null ? null : _normalize(url),
        ));
      } else {
        next.add(e);
      }
    }
    if (!found) return;
    await _commit(next, state.activeId);
  }

  Future<void> remove(String id) async {
    final state = await load();
    if (state.endpoints.length <= 1) {
      // Refuse to delete the last endpoint — the app would have nothing
      // to point at and would silently fall back to the build-time
      // default, which is exactly the kind of "ghost backend" we're
      // trying to make explicit with this feature.
      throw StateError(
        'Нельзя удалить единственный бэкенд. Сначала добавь другой.',
      );
    }
    final next = state.endpoints.where((e) => e.id != id).toList();
    final activeId = state.activeId == id ? next.first.id : state.activeId;
    await _commit(next, activeId);
  }

  Future<void> setActive(String id) async {
    final state = await load();
    if (state.endpoints.indexWhere((e) => e.id == id) == -1) return;
    if (state.activeId == id) return;
    await _commit(state.endpoints, id);
  }

  Future<void> _commit(List<BackendEndpoint> endpoints, String? activeId) async {
    final prefs = await _prefsInstance();
    await _persist(endpoints, activeId, prefs: prefs);
    _cached = BackendUrlsState(endpoints: endpoints, activeId: activeId);
    _changes.add(_cached!);
  }

  Future<void> _persist(
    List<BackendEndpoint> endpoints,
    String? activeId, {
    required SharedPreferences prefs,
  }) async {
    final list = endpoints.map((e) => e.toJson()).toList();
    await prefs.setString(_kListKey, jsonEncode(list));
    if (activeId != null) {
      await prefs.setString(_kActiveKey, activeId);
    } else {
      await prefs.remove(_kActiveKey);
    }
  }

  static String _normalize(String url) {
    var v = url.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
