import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

const _kNotifEnabledKey = 'noetica.notif.enabled.v1';
const _kNotifMorningHourKey = 'noetica.notif.morning_hour.v1';
const _kNotifMorningMinuteKey = 'noetica.notif.morning_minute.v1';
const _kNotifEveningHourKey = 'noetica.notif.evening_hour.v1';
const _kNotifEveningMinuteKey = 'noetica.notif.evening_minute.v1';
const _kNotifCoachEnabledKey = 'noetica.notif.coach.v1';

/// On desktop platforms `local_notifier` shows toasts immediately, so we
/// roll our own Timer-based scheduler. We persist all upcoming firing times
/// here so that a crash / restart re-arms the timers.
const _kNotifDesktopScheduleKey = 'noetica.notif.desktop_schedule.v1';

const _kAndroidChannelId = 'noetica_deadlines';
const _kAndroidChannelName = 'Дедлайны и напоминания';
const _kAndroidChannelDescription =
    'Напоминания о приближающихся и просроченных задачах.';

/// Three notifications per task, identified by deterministic suffixes so
/// rescheduling/cancelling is straightforward.
enum _Slot { dayBefore, morningOf, lateAfter }

/// Lightweight wrapper around platform-specific notification stacks.
///
/// On Android/iOS/macOS we use `flutter_local_notifications` with the OS
/// alarm scheduler.
///
/// On Windows/Linux we use `local_notifier` for the actual toast and a
/// process-local Timer queue (persisted to SharedPreferences) for the
/// scheduling — those platforms have no in-OS scheduled notification API
/// that's exposed by Flutter, so reminders fire while the app process is
/// running (we keep it alive via tray icon, see `services/tray_service.dart`).
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  bool _supported = false;
  _Backend _backend = _NoopBackend();

  /// `true` if reminders can be scheduled on this platform. UI uses this to
  /// hide / disable the toggle.
  bool get supported => _supported;

  /// Human-readable platform notes shown in Settings under the toggle.
  String get platformNote {
    switch (_backend.kind) {
      case _BackendKind.mobile:
        return 'OS-level scheduled reminders. Работают даже если приложение закрыто.';
      case _BackendKind.desktop:
        return 'Тосты Windows + иконка в трее. Чтобы напоминания приходили, не закрывай приложение полностью — сворачивай в трей (крестик это и делает).';
      case _BackendKind.none:
        return 'Эта платформа не поддерживается.';
    }
  }

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    if (kIsWeb) {
      _supported = false;
      return;
    }
    final platform = defaultTargetPlatform;
    try {
      tzdata.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fall back to UTC; scheduling still works, just less accurate.
      }
    } catch (_) {}

    if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS) {
      try {
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
        );
        await _plugin.initialize(initSettings);
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              _kAndroidChannelId,
              _kAndroidChannelName,
              description: _kAndroidChannelDescription,
              importance: Importance.high,
            ),
          );
          // Android 13+ runtime permission.
          try {
            await androidImpl.requestNotificationsPermission();
          } catch (_) {}
        }
        _backend = _MobileBackend(_plugin);
        _supported = true;
        return;
      } catch (e) {
        debugPrint('Mobile notifications init failed: $e');
        _supported = false;
        _backend = _NoopBackend();
        return;
      }
    }

    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux) {
      try {
        await localNotifier.setup(
          appName: 'Noetica',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        final desktop = _DesktopBackend();
        await desktop.restoreSchedule();
        _backend = desktop;
        _supported = true;
        return;
      } catch (e) {
        debugPrint('Desktop notifier init failed: $e');
        _supported = false;
        _backend = _NoopBackend();
        return;
      }
    }

    _supported = false;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifEnabledKey, value);
    if (!value) {
      await cancelAll();
    }
  }

  Future<({int hour, int minute})> morningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_kNotifMorningHourKey) ?? 8,
      minute: prefs.getInt(_kNotifMorningMinuteKey) ?? 0,
    );
  }

  Future<void> setMorningTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifMorningHourKey, hour);
    await prefs.setInt(_kNotifMorningMinuteKey, minute);
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    await _backend.cancelAll();
  }

  /// Fire a notification immediately (no scheduling). Used by features like
  /// Pomodoro to ring the user when a phase ends. Independent of the
  /// "enabled" flag because the user explicitly asked for the sound — if
  /// notifications are turned off in the OS, this just silently no-ops.
  ///
  /// Goes through the backend's `showNow` path which uses the plugin's
  /// direct `show()` API on mobile (no exact-alarm permission required —
  /// avoids `SecurityException` crashes on Android 12+ when the user
  /// hasn't granted `SCHEDULE_EXACT_ALARM`).
  Future<void> showImmediate({
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    try {
      final id = '${title}_${DateTime.now().microsecondsSinceEpoch}'
              .hashCode &
          0x7fffffff;
      await _backend.showNow(id: id, title: title, body: body);
    } catch (e) {
      debugPrint('showImmediate failed: $e');
    }
  }

  /// Schedule a one-shot test notification after `delay`. Used by the
  /// Settings screen for debugging the OS-level scheduler on each
  /// platform.
  Future<void> scheduleTest({
    required Duration delay,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    try {
      final id = '${title}_${DateTime.now().microsecondsSinceEpoch}'
              .hashCode &
          0x7fffffff;
      await _backend.schedule(
        id: id,
        when: DateTime.now().add(delay),
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('scheduleTest failed: $e');
    }
  }

  // ---- Coach daily reminders ----

  static const int _morningCoachNotifId = 0x4E4F4501; // "NOE" + 01
  static const int _eveningCoachNotifId = 0x4E4F4502; // "NOE" + 02

  Future<bool> isCoachEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifCoachEnabledKey) ?? false;
  }

  Future<void> setCoachEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifCoachEnabledKey, value);
    if (value) {
      await scheduleCoachReminders();
    } else {
      await _backend.cancel(_morningCoachNotifId);
      await _backend.cancel(_eveningCoachNotifId);
    }
  }

  Future<({int hour, int minute})> eveningTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_kNotifEveningHourKey) ?? 21,
      minute: prefs.getInt(_kNotifEveningMinuteKey) ?? 0,
    );
  }

  Future<void> setEveningTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifEveningHourKey, hour);
    await prefs.setInt(_kNotifEveningMinuteKey, minute);
  }

  Future<void> scheduleCoachReminders() async {
    if (!_supported) return;
    if (!await isCoachEnabled()) return;
    if (!await isEnabled()) return;

    final morning = await morningTime();
    final evening = await eveningTime();
    final now = DateTime.now();

    // Schedule morning coach for tomorrow (or today if not passed yet)
    var morningDt = DateTime(
      now.year, now.month, now.day,
      morning.hour, morning.minute,
    );
    if (morningDt.isBefore(now)) {
      morningDt = morningDt.add(const Duration(days: 1));
    }

    // Schedule evening reflection for today (or tomorrow if passed)
    var eveningDt = DateTime(
      now.year, now.month, now.day,
      evening.hour, evening.minute,
    );
    if (eveningDt.isBefore(now)) {
      eveningDt = eveningDt.add(const Duration(days: 1));
    }

    try {
      await _backend.schedule(
        id: _morningCoachNotifId,
        when: morningDt,
        title: 'Утренний план',
        body: 'Загляни в AI-коуч — спланируй свой день',
      );
    } catch (e) {
      debugPrint('Morning coach schedule failed: $e');
    }
    try {
      await _backend.schedule(
        id: _eveningCoachNotifId,
        when: eveningDt,
        title: 'Вечерний разбор',
        body: 'Подведём итоги дня — что получилось, что улучшить?',
      );
    } catch (e) {
      debugPrint('Evening coach schedule failed: $e');
    }
  }

  Future<void> cancelForEntry(String entryId) async {
    if (!_supported) return;
    for (final slot in _Slot.values) {
      await _backend.cancel(_idFor(entryId, slot));
    }
  }

  /// Reschedule notifications for a task. If the task is a note, completed,
  /// or has no deadline, all of its notifications are cancelled.
  Future<void> reschedule(Entry entry) async {
    if (!_supported) return;
    if (!await isEnabled()) {
      await cancelForEntry(entry.id);
      return;
    }
    await cancelForEntry(entry.id);
    if (entry.kind != EntryKind.task) return;
    if (entry.isCompleted) return;
    final due = entry.dueAt;
    if (due == null) return;

    final morning = await morningTime();
    final dayBefore = DateTime(
      due.year,
      due.month,
      due.day,
      18,
      0,
    ).subtract(const Duration(days: 1));
    final morningOf = DateTime(
      due.year,
      due.month,
      due.day,
      morning.hour,
      morning.minute,
    );
    final lateAfter = due.add(const Duration(hours: 1));

    await _scheduleIfFuture(
      entry,
      _Slot.dayBefore,
      dayBefore,
      title: 'Завтра дедлайн',
      body: entry.title,
    );
    await _scheduleIfFuture(
      entry,
      _Slot.morningOf,
      morningOf,
      title: 'Сегодня дедлайн',
      body: entry.title,
    );
    await _scheduleIfFuture(
      entry,
      _Slot.lateAfter,
      lateAfter,
      title: 'Дедлайн прошёл',
      body: entry.title,
    );
  }

  Future<void> _scheduleIfFuture(
    Entry entry,
    _Slot slot,
    DateTime when, {
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (!when.isAfter(now)) return;
    try {
      await _backend.schedule(
        id: _idFor(entry.id, slot),
        when: when,
        title: title,
        body: body,
        payload: entry.id,
      );
    } catch (e) {
      debugPrint('Notification schedule failed for ${entry.id}/$slot: $e');
    }
  }

  /// Stable, deterministic ID per (entry, slot). flutter_local_notifications
  /// requires int IDs, so we hash the entry UUID + slot ordinal.
  int _idFor(String entryId, _Slot slot) {
    final raw = '$entryId:${slot.index}'.hashCode;
    // Keep it positive and within Android's 32-bit int range.
    return raw & 0x7fffffff;
  }
}

enum _BackendKind { none, mobile, desktop }

abstract class _Backend {
  _BackendKind get kind;

  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  });

  /// Fire immediately, bypassing OS-level scheduling. Used for Pomodoro
  /// phase-end cues so we never trip Android 12+ exact-alarm permission
  /// requirements (which throw `SecurityException` and crash the app
  /// when not granted).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

class _NoopBackend implements _Backend {
  @override
  _BackendKind get kind => _BackendKind.none;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

class _MobileBackend implements _Backend {
  _MobileBackend(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  _BackendKind get kind => _BackendKind.mobile;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _kAndroidChannelId,
      _kAndroidChannelName,
      channelDescription: _kAndroidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    // Use `inexactAllowWhileIdle` instead of `exactAllowWhileIdle`. The
    // exact variant requires the Android 12+ runtime SCHEDULE_EXACT_ALARM
    // permission — if the user hasn't granted it, `zonedSchedule` throws
    // `SecurityException` which crashes the Flutter activity. Inexact is
    // good enough for our reminders (within ~10 min), works on every
    // Android version, and never crashes.
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    // Direct `show()` — bypasses the OS scheduler entirely so we never
    // need exact-alarm permission. Used by Pomodoro for phase-end cues.
    await _plugin.show(id, title, body, _details);
  }

  @override
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

/// Process-local scheduler used on Windows/Linux. Each pending notification
/// has a Timer + a persisted entry in SharedPreferences. On init the
/// service rebuilds Timers for everything that's still in the future.
class _DesktopBackend implements _Backend {
  final Map<int, Timer> _timers = {};
  final Map<int, _PendingDesktop> _pending = {};

  @override
  _BackendKind get kind => _BackendKind.desktop;

  Future<void> restoreSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotifDesktopScheduleKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final now = DateTime.now();
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        final value = entry.value;
        if (value is! Map) continue;
        final whenStr = value['when'];
        final when = whenStr is String ? DateTime.tryParse(whenStr) : null;
        if (when == null) continue;
        final title = (value['title'] as String?) ?? 'Noetica';
        final body = (value['body'] as String?) ?? '';
        final payload = value['payload'] as String?;
        if (when.isAfter(now)) {
          _arm(id, when, title, body, payload);
        }
        // Past-due entries are dropped silently — we don't fire historic
        // toasts on every startup.
      }
    } catch (e) {
      debugPrint('Desktop schedule restore failed: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pending.isEmpty) {
      await prefs.remove(_kNotifDesktopScheduleKey);
      return;
    }
    final out = <String, dynamic>{
      for (final e in _pending.entries)
        e.key.toString(): {
          'when': e.value.when.toIso8601String(),
          'title': e.value.title,
          'body': e.value.body,
          if (e.value.payload != null) 'payload': e.value.payload,
        },
    };
    await prefs.setString(_kNotifDesktopScheduleKey, jsonEncode(out));
  }

  void _arm(
    int id,
    DateTime when,
    String title,
    String body,
    String? payload,
  ) {
    final delay = when.difference(DateTime.now());
    final timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      _timers.remove(id);
      _pending.remove(id);
      unawaited(_persist());
      try {
        final notification = LocalNotification(title: title, body: body);
        await notification.show();
      } catch (e) {
        debugPrint('Desktop toast failed: $e');
      }
    });
    _timers[id] = timer;
    _pending[id] = _PendingDesktop(
      when: when,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    _timers.remove(id)?.cancel();
    _arm(id, when, title, body, payload);
    await _persist();
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final notification = LocalNotification(title: title, body: body);
      await notification.show();
    } catch (e) {
      debugPrint('Desktop showNow failed: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
    if (_pending.remove(id) != null) {
      await _persist();
    }
  }

  @override
  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pending.clear();
    await _persist();
  }
}

class _PendingDesktop {
  _PendingDesktop({
    required this.when,
    required this.title,
    required this.body,
    this.payload,
  });

  final DateTime when;
  final String title;
  final String body;
  final String? payload;
}
