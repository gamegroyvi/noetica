import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

const _kNotifEnabledKey = 'noetica.notif.enabled.v1';
const _kNotifMorningHourKey = 'noetica.notif.morning_hour.v1';
const _kNotifMorningMinuteKey = 'noetica.notif.morning_minute.v1';

const _kAndroidChannelId = 'noetica_deadlines';
const _kAndroidChannelName = 'Дедлайны и напоминания';
const _kAndroidChannelDescription =
    'Напоминания о приближающихся и просроченных задачах.';

/// Three notifications per task, identified by deterministic suffixes so
/// rescheduling/cancelling is straightforward.
enum _Slot { dayBefore, morningOf, lateAfter }

/// Lightweight wrapper that hides flutter_local_notifications on platforms
/// where it can't run (web, tests). On Android/iOS we schedule real local
/// alarms; everywhere else this becomes a no-op so the rest of the app
/// stays oblivious.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  bool _supported = false;

  bool get supported => _supported;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    if (kIsWeb) {
      _supported = false;
      return;
    }
    try {
      tzdata.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fall back to UTC; scheduling still works, just less accurate.
      }
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
      _supported = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
      _supported = false;
    }
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
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> cancelForEntry(String entryId) async {
    if (!_supported) return;
    for (final slot in _Slot.values) {
      await _plugin.cancel(_idFor(entryId, slot));
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
    final tzDue = tz.TZDateTime.from(due, tz.local);
    final dayBeforeDate = tzDue.subtract(const Duration(days: 1));
    final dayBefore = tz.TZDateTime(
      tz.local,
      dayBeforeDate.year,
      dayBeforeDate.month,
      dayBeforeDate.day,
      18,
      0,
    );
    final morningOf = tz.TZDateTime(
      tz.local,
      tzDue.year,
      tzDue.month,
      tzDue.day,
      morning.hour,
      morning.minute,
    );
    final lateAfter = tzDue.add(const Duration(hours: 1));

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
    tz.TZDateTime when, {
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) return;
    try {
      await _plugin.zonedSchedule(
        _idFor(entry.id, slot),
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kAndroidChannelId,
            _kAndroidChannelName,
            channelDescription: _kAndroidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
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
