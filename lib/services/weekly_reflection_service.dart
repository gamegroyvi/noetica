import 'package:shared_preferences/shared_preferences.dart';

import 'notifications.dart';

const _kLastShownKey = 'noetica.weekly_reflection.last_shown.v1';
const _kFirstSeenKey = 'noetica.weekly_reflection.first_seen.v1';

/// Decides when to surface the weekly reflection sheet and writes back the
/// "last shown" timestamp so we don't pester the user. Reminder is fired
/// through the OS-level notification scheduler — it survives app restarts
/// even on desktop because the in-process scheduler keeps the slot.
class WeeklyReflectionService {
  WeeklyReflectionService._();
  static final WeeklyReflectionService instance = WeeklyReflectionService._();

  /// Returns true if the dashboard banner / sheet should be shown right now.
  /// Logic: at least 7 days since `firstSeen`, and at least 7 days since the
  /// last shown reflection. The 7-day-from-first-seen guard prevents asking
  /// for a "weekly" reflection on day 1.
  Future<bool> shouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final firstSeenRaw = prefs.getString(_kFirstSeenKey);
    if (firstSeenRaw == null) {
      await prefs.setString(_kFirstSeenKey, now.toIso8601String());
      return false;
    }
    final firstSeen = DateTime.tryParse(firstSeenRaw) ?? now;
    if (now.difference(firstSeen).inDays < 7) return false;

    final lastRaw = prefs.getString(_kLastShownKey);
    if (lastRaw == null) return true;
    final last = DateTime.tryParse(lastRaw) ?? now;
    return now.difference(last).inDays >= 7;
  }

  Future<DateTime?> lastShown() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastShownKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_kLastShownKey, now.toIso8601String());
    // Schedule next reminder ~7 days out so the user gets a notification
    // even if they don't open the app.
    await NotificationsService.instance.scheduleTest(
      delay: const Duration(days: 7),
      title: 'Время недельной рефлексии',
      body: 'Заглянем как прошла неделя?',
    );
  }

  /// Manual snooze (e.g. user closes the sheet without filling it). We push
  /// the next prompt 1 day forward so it shows again tomorrow.
  Future<void> snoozeOneDay() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Pretend last shown is 6 days ago — so the 7-day gate triggers tomorrow.
    final pseudo = now.subtract(const Duration(days: 6));
    await prefs.setString(_kLastShownKey, pseudo.toIso8601String());
  }
}
