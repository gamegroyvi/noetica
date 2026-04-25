import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart' as m;
import '../data/profile.dart';
import '../data/repository.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Two-way sync between local SQLite + SharedPreferences profile and the
/// Noetica backend. Last-Writer-Wins by `updated_at`.
///
/// Public API:
/// - `bind(authStream)` — listens to sign-in/sign-out and wires push/pull.
/// - `pull()` — fetch + merge remote changes since `last_pull_ms`.
/// - `pushPending()` — send local changes since `last_push_ms`.
/// - `bootstrap()` — full pull then push, called once after sign-in.
///
/// All HTTP errors are swallowed and logged via debugPrint — sync is
/// best-effort, never blocks the UI, and resumes automatically next time the
/// dirty stream fires.
class SyncService {
  SyncService({
    required NoeticaRepository repository,
    required AuthService auth,
    required ProfileService profileService,
    String? backendBaseUrl,
    http.Client? httpClient,
    Duration pushDebounce = const Duration(milliseconds: 800),
    Duration httpTimeout = const Duration(seconds: 20),
  })  : _repo = repository,
        _auth = auth,
        _profileService = profileService,
        _baseUrl = (backendBaseUrl ?? kDefaultBackendUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        _http = httpClient ?? http.Client(),
        _pushDebounce = pushDebounce,
        _httpTimeout = httpTimeout;

  static const _kLastPushKey = 'noetica.sync.last_push_ms.v1';
  static const _kLastPullKey = 'noetica.sync.last_pull_ms.v1';
  static const _kBoundUserKey = 'noetica.sync.bound_user_id.v1';

  final NoeticaRepository _repo;
  final AuthService _auth;
  final ProfileService _profileService;
  final String _baseUrl;
  final http.Client _http;
  final Duration _pushDebounce;
  final Duration _httpTimeout;

  StreamSubscription<AuthSession?>? _authSub;
  StreamSubscription<void>? _dirtySub;
  StreamSubscription<UserProfile?>? _profileSub;
  Timer? _pushTimer;
  bool _busy = false;
  String? _boundUserId;

  /// Subscribes to auth changes; on sign-in, kicks off bootstrap; on
  /// sign-out, stops listening.
  void start() {
    _authSub ??= _auth.sessionStream.listen(_onSessionChange);
    final current = _auth.current;
    if (current != null) {
      unawaited(_onSessionChange(current));
    }
  }

  Future<void> _onSessionChange(AuthSession? session) async {
    if (session == null) {
      await _dirtySub?.cancel();
      _dirtySub = null;
      await _profileSub?.cancel();
      _profileSub = null;
      _pushTimer?.cancel();
      _pushTimer = null;
      _boundUserId = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final previousBound = prefs.getString(_kBoundUserKey);
    if (previousBound != null && previousBound != session.user.id) {
      // Different account opened on this device. Reset sync timestamps so
      // we re-pull everything fresh — the local DB still belongs to the old
      // user but we don't blow it away here; the user can wipe data via
      // Settings.
      await prefs.remove(_kLastPullKey);
      await prefs.remove(_kLastPushKey);
    }
    await prefs.setString(_kBoundUserKey, session.user.id);
    _boundUserId = session.user.id;

    _dirtySub ??= _repo.dirty.listen((_) => _scheduleDebouncedPush());
    _profileSub ??=
        ProfileService.changes.listen((_) => _scheduleDebouncedPush());
    unawaited(bootstrap());
  }

  void _scheduleDebouncedPush() {
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDebounce, () => unawaited(pushPending()));
  }

  Future<void> bootstrap() async {
    if (_auth.current == null) return;
    await pull();
    await pushPending();
  }

  // ---------- pull ----------

  Future<void> pull() async {
    final session = _auth.current;
    if (session == null) return;
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getInt(_kLastPullKey) ?? 0;
      final response = await _http
          .post(
            Uri.parse('$_baseUrl/sync/pull'),
            headers: _authHeaders(session),
            body: jsonEncode({'since_ms': since}),
          )
          .timeout(_httpTimeout);
      if (response.statusCode != 200) {
        debugPrint('SyncService.pull: HTTP ${response.statusCode} '
            '${response.body}');
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final serverNow = body['server_time_ms'] as int;

      final axes = (body['axes'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      var axesAccepted = 0;
      for (final raw in axes) {
        final axis = _axisFromRemote(raw);
        if (await _repo.mergeRemoteAxis(axis)) axesAccepted += 1;
      }
      final entries = (body['entries'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      var entriesAccepted = 0;
      for (final raw in entries) {
        final entry = _entryFromRemote(raw);
        if (await _repo.mergeRemoteEntry(entry)) entriesAccepted += 1;
      }

      final profile = body['profile'] as Map<String, dynamic>?;
      var profileAccepted = false;
      if (profile != null) {
        profileAccepted =
            await _maybeApplyRemoteProfile(profile);
      }

      await prefs.setInt(_kLastPullKey, serverNow);
      if (axesAccepted > 0 || entriesAccepted > 0) {
        await _repo.notifyChanged();
      }
      if (profileAccepted) {
        // ProfileService already fired its own notifier; nothing to do.
      }
    } catch (e, stack) {
      debugPrint('SyncService.pull failed: $e\n$stack');
    } finally {
      _busy = false;
    }
  }

  Future<bool> _maybeApplyRemoteProfile(Map<String, dynamic> raw) async {
    try {
      final dataJson = raw['data_json'] as String;
      final updatedAtMs = raw['updated_at'] as int;
      final remoteUpdatedAt =
          DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
      final local = await _profileService.load();
      if (local != null && !local.updatedAt.isBefore(remoteUpdatedAt)) {
        return false;
      }
      final decoded = jsonDecode(dataJson) as Map<String, dynamic>;
      // Stamp updatedAt from server payload so subsequent pushes don't
      // bounce the same row back.
      decoded['updatedAt'] = remoteUpdatedAt.toIso8601String();
      final remote = UserProfile.fromJson(decoded);
      await _profileService.save(remote);
      return true;
    } catch (e) {
      debugPrint('SyncService._maybeApplyRemoteProfile: $e');
      return false;
    }
  }

  // ---------- push ----------

  Future<void> pushPending() async {
    final session = _auth.current;
    if (session == null) return;
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getInt(_kLastPushKey) ?? 0;

      final axesDirty = await _repo.axesUpdatedSince(since);
      final entriesDirty = await _repo.entriesUpdatedSince(since);
      final profile = await _profileService.load();
      final profileDirty =
          profile != null && profile.updatedAt.millisecondsSinceEpoch > since;

      if (axesDirty.isEmpty && entriesDirty.isEmpty && !profileDirty) {
        return;
      }

      final body = <String, dynamic>{
        'axes': axesDirty.map(_axisToRemote).toList(),
        'entries': entriesDirty.map(_entryToRemote).toList(),
      };
      if (profileDirty) {
        body['profile'] = {
          'data_json': jsonEncode(profile.toJson()),
          'updated_at': profile.updatedAt.millisecondsSinceEpoch,
        };
      }

      final response = await _http
          .post(
            Uri.parse('$_baseUrl/sync/push'),
            headers: _authHeaders(session),
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
      if (response.statusCode != 200) {
        debugPrint('SyncService.pushPending: HTTP ${response.statusCode} '
            '${response.body}');
        return;
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final serverNow = result['server_time_ms'] as int;
      await prefs.setInt(_kLastPushKey, serverNow);
    } catch (e, stack) {
      debugPrint('SyncService.pushPending failed: $e\n$stack');
    } finally {
      _busy = false;
    }
  }

  // ---------- mappers ----------

  Map<String, String> _authHeaders(AuthSession session) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };

  Map<String, dynamic> _axisToRemote(m.LifeAxis a) => {
        'id': a.id,
        'name': a.name,
        'symbol': a.symbol,
        'position': a.position,
        'created_at': a.createdAt.millisecondsSinceEpoch,
        'updated_at': a.updatedAt.millisecondsSinceEpoch,
        if (a.deletedAt != null)
          'deleted_at': a.deletedAt!.millisecondsSinceEpoch,
      };

  m.LifeAxis _axisFromRemote(Map<String, dynamic> r) => m.LifeAxis(
        id: r['id'] as String,
        name: r['name'] as String,
        symbol: r['symbol'] as String,
        position: (r['position'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
        deletedAt: r['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
      );

  Map<String, dynamic> _entryToRemote(m.Entry e) => {
        'id': e.id,
        'title': e.title,
        'body': e.body,
        'kind': e.kind.name,
        'created_at': e.createdAt.millisecondsSinceEpoch,
        'updated_at': e.updatedAt.millisecondsSinceEpoch,
        if (e.dueAt != null) 'due_at': e.dueAt!.millisecondsSinceEpoch,
        if (e.completedAt != null)
          'completed_at': e.completedAt!.millisecondsSinceEpoch,
        if (e.deletedAt != null)
          'deleted_at': e.deletedAt!.millisecondsSinceEpoch,
        'xp': e.xp,
        'axis_ids': e.axisIds,
      };

  m.Entry _entryFromRemote(Map<String, dynamic> r) => m.Entry(
        id: r['id'] as String,
        title: r['title'] as String,
        body: (r['body'] as String?) ?? '',
        kind: m.EntryKind.values.firstWhere(
          (k) => k.name == r['kind'],
          orElse: () => m.EntryKind.note,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
        dueAt: r['due_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['due_at'] as int),
        completedAt: r['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['completed_at'] as int),
        deletedAt: r['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
        xp: (r['xp'] as int?) ?? 10,
        axisIds: ((r['axis_ids'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  void dispose() {
    _authSub?.cancel();
    _dirtySub?.cancel();
    _profileSub?.cancel();
    _pushTimer?.cancel();
    _http.close();
  }

  /// Currently bound user id, or null if not signed in. Useful for tests.
  @visibleForTesting
  String? get boundUserId => _boundUserId;
}
