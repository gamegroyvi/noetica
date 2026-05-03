import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Free-tier limits. Centralised so paywall checks and UI counters
/// reference the same constants.
abstract final class FreeLimits {
  static const int maxAxes = 3;
  static const int maxActiveTasks = 20;

  /// AI generations (roadmap, menu, etc.) allowed per calendar week.
  static const int aiGenerationsPerWeek = 1;

  /// History depth visible in the Memoir / Journal.
  static const int memoirDays = 30;
}

/// Subscription tier. [free] is the default for every new user.
/// [premium] unlocks all limits. [trial] behaves like premium but
/// expires after 7 days — used for first-install promos.
enum SubscriptionTier { free, trial, premium }

/// Lightweight service that answers "is the current user premium?"
/// without coupling to a specific payment provider.
///
/// The source of truth is [premiumUntil] — a UTC timestamp stored in
/// SharedPreferences. The backend sets it after a successful ЮКасса
/// payment and syncs it down; the client never extends it locally.
///
/// Usage:
/// ```dart
/// final svc = ref.watch(premiumServiceProvider);
/// if (svc.isPremium) { /* full access */ }
/// ```
class PremiumService {
  PremiumService({SharedPreferences? prefs}) : _prefs = prefs;

  static const _kPremiumUntilKey = 'noetica.premium_until.v1';
  static const _kWeeklyAiCountKey = 'noetica.ai_gen_count.v1';
  static const _kWeeklyAiResetKey = 'noetica.ai_gen_reset.v1';

  SharedPreferences? _prefs;
  DateTime? _premiumUntil;

  static final _changes = StreamController<bool>.broadcast();

  /// Stream that fires whenever premium status changes.
  static Stream<bool> get changes => _changes.stream;

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load persisted premium expiry from SharedPreferences.
  Future<void> load() async {
    final prefs = await _prefsInstance();
    final raw = prefs.getString(_kPremiumUntilKey);
    if (raw != null) {
      _premiumUntil = DateTime.tryParse(raw);
    }
  }

  /// Whether the user currently has an active premium subscription.
  /// In dev mode (DEV_SKIP_AUTH=true), always returns true so all
  /// features are testable without a real subscription.
  bool get isPremium {
    if (kDevSkipAuth) return true;
    if (_premiumUntil == null) return false;
    return _premiumUntil!.isAfter(DateTime.now().toUtc());
  }

  SubscriptionTier get tier {
    if (!isPremium) return SubscriptionTier.free;
    return SubscriptionTier.premium;
  }

  DateTime? get premiumUntil => _premiumUntil;

  /// Called by the sync layer when the backend confirms a subscription.
  Future<void> setPremiumUntil(DateTime? until) async {
    _premiumUntil = until;
    final prefs = await _prefsInstance();
    if (until != null) {
      await prefs.setString(_kPremiumUntilKey, until.toUtc().toIso8601String());
    } else {
      await prefs.remove(_kPremiumUntilKey);
    }
    if (!_changes.isClosed) _changes.add(isPremium);
  }

  // -------- AI generation rate-limiting (free tier) --------

  /// Returns the number of AI generations used this calendar week.
  Future<int> aiGenerationsThisWeek() async {
    final prefs = await _prefsInstance();
    final resetMs = prefs.getInt(_kWeeklyAiResetKey) ?? 0;
    final resetAt = DateTime.fromMillisecondsSinceEpoch(resetMs, isUtc: true);
    if (_isNewWeek(resetAt)) {
      await prefs.setInt(_kWeeklyAiCountKey, 0);
      await prefs.setInt(
        _kWeeklyAiResetKey,
        _startOfWeek(DateTime.now().toUtc()).millisecondsSinceEpoch,
      );
      return 0;
    }
    return prefs.getInt(_kWeeklyAiCountKey) ?? 0;
  }

  /// Whether the free user can still generate this week.
  Future<bool> canGenerate() async {
    if (isPremium) return true;
    final used = await aiGenerationsThisWeek();
    return used < FreeLimits.aiGenerationsPerWeek;
  }

  /// Increment the weekly counter after a successful generation.
  Future<void> recordGeneration() async {
    if (isPremium) return;
    final prefs = await _prefsInstance();
    final current = await aiGenerationsThisWeek();
    await prefs.setInt(_kWeeklyAiCountKey, current + 1);
  }

  static bool _isNewWeek(DateTime lastReset) {
    final now = DateTime.now().toUtc();
    final weekStart = _startOfWeek(now);
    return lastReset.isBefore(weekStart);
  }

  static DateTime _startOfWeek(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    final monday = d.subtract(Duration(days: diff));
    return DateTime.utc(monday.year, monday.month, monday.day);
  }

  void dispose() {
    // No owned resources to clean up; the static stream is app-scoped.
  }
}
