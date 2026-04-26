import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications.dart';

/// Persisted across app restarts.
const _kPomodoroEndKey = 'noetica.pomodoro.end_at.v1';
const _kPomodoroPhaseKey = 'noetica.pomodoro.phase.v1';
const _kPomodoroFocusMinKey = 'noetica.pomodoro.focus_min.v1';
const _kPomodoroBreakMinKey = 'noetica.pomodoro.break_min.v1';
const _kPomodoroLongBreakMinKey = 'noetica.pomodoro.long_break_min.v1';
const _kPomodoroLongBreakEveryKey = 'noetica.pomodoro.long_break_every.v1';
const _kPomodoroAutoNextKey = 'noetica.pomodoro.auto_next.v1';
const _kPomodoroSoundKey = 'noetica.pomodoro.sound.v1';
const _kPomodoroCompletedKey = 'noetica.pomodoro.completed_focus.v1';

enum PomodoroPhase { idle, focus, breakTime, longBreak }

extension PomodoroPhaseX on PomodoroPhase {
  String get storage => switch (this) {
        PomodoroPhase.idle => 'idle',
        PomodoroPhase.focus => 'focus',
        PomodoroPhase.breakTime => 'break',
        PomodoroPhase.longBreak => 'long_break',
      };

  String get label => switch (this) {
        PomodoroPhase.idle => 'Pomodoro',
        PomodoroPhase.focus => 'Фокус',
        PomodoroPhase.breakTime => 'Короткий отдых',
        PomodoroPhase.longBreak => 'Длинный отдых',
      };
}

PomodoroPhase _parsePhase(String? raw) => switch (raw) {
      'focus' => PomodoroPhase.focus,
      'break' => PomodoroPhase.breakTime,
      'long_break' => PomodoroPhase.longBreak,
      _ => PomodoroPhase.idle,
    };

/// Process-wide singleton. Owns the timer + state regardless of whether the
/// sheet is open. Fires OS notifications independently of any UI.
class PomodoroService extends ChangeNotifier {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  Timer? _ticker;
  DateTime? _endAt;

  PomodoroPhase _phase = PomodoroPhase.idle;
  Duration _remaining = Duration.zero;

  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _longBreakMinutes = 15;
  int _longBreakEvery = 4;
  bool _autoNext = true;
  bool _soundOn = false;

  int _completedFocus = 0;
  bool _hydrated = false;

  /// Lazily-instantiated melody player. Loops `assets/sounds/chime.wav`
  /// after a phase ends so the user has a chance to come back to the app
  /// and dismiss before the next phase starts. Re-used across phases —
  /// dispose on app shutdown.
  AudioPlayer? _player;

  /// True between «phase just ended» and «user dismissed the cue». The UI
  /// surfaces this as a blocking alert; the next phase's ticker will not
  /// run until [acknowledgePhaseTransition] flips it back to false. Only
  /// used when [_soundOn] is true — silent mode keeps the previous
  /// auto-advance behaviour.
  bool _awaitingDismissal = false;

  /// Snapshot of the phase that just completed — used to render the
  /// dismissal copy («Фокус завершён» vs «Отдых завершён»).
  PomodoroPhase _justCompleted = PomodoroPhase.idle;

  PomodoroPhase get phase => _phase;
  Duration get remaining => _remaining;
  int get focusMinutes => _focusMinutes;
  int get breakMinutes => _breakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get longBreakEvery => _longBreakEvery;
  bool get autoNext => _autoNext;
  bool get soundOn => _soundOn;
  int get completedFocus => _completedFocus;
  bool get hydrated => _hydrated;
  bool get awaitingDismissal => _awaitingDismissal;
  PomodoroPhase get justCompleted => _justCompleted;

  Future<void> init() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();

    _focusMinutes = prefs.getInt(_kPomodoroFocusMinKey) ?? 25;
    _breakMinutes = prefs.getInt(_kPomodoroBreakMinKey) ?? 5;
    _longBreakMinutes = prefs.getInt(_kPomodoroLongBreakMinKey) ?? 15;
    _longBreakEvery = prefs.getInt(_kPomodoroLongBreakEveryKey) ?? 4;
    _autoNext = prefs.getBool(_kPomodoroAutoNextKey) ?? true;
    _soundOn = prefs.getBool(_kPomodoroSoundKey) ?? false;
    _completedFocus = prefs.getInt(_kPomodoroCompletedKey) ?? 0;

    final phase = _parsePhase(prefs.getString(_kPomodoroPhaseKey));
    final endRaw = prefs.getString(_kPomodoroEndKey);
    final end = endRaw != null ? DateTime.tryParse(endRaw) : null;

    if (phase != PomodoroPhase.idle && end != null) {
      _phase = phase;
      _endAt = end;
      final now = DateTime.now();
      if (end.isAfter(now)) {
        _remaining = end.difference(now);
        _startTicker();
      } else {
        // Phase already ran out while we were away — advance to next phase
        // immediately so the user sees a coherent state on resume.
        _remaining = Duration.zero;
        _onPhaseDone(silent: true);
      }
    } else {
      _phase = PomodoroPhase.idle;
      _remaining = Duration(minutes: _focusMinutes);
    }

    _hydrated = true;
    notifyListeners();
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPomodoroFocusMinKey, _focusMinutes);
    await prefs.setInt(_kPomodoroBreakMinKey, _breakMinutes);
    await prefs.setInt(_kPomodoroLongBreakMinKey, _longBreakMinutes);
    await prefs.setInt(_kPomodoroLongBreakEveryKey, _longBreakEvery);
    await prefs.setBool(_kPomodoroAutoNextKey, _autoNext);
    await prefs.setBool(_kPomodoroSoundKey, _soundOn);
  }

  Future<void> _persistRunning() async {
    final prefs = await SharedPreferences.getInstance();
    if (_endAt != null) {
      await prefs.setString(_kPomodoroEndKey, _endAt!.toIso8601String());
    }
    await prefs.setString(_kPomodoroPhaseKey, _phase.storage);
    await prefs.setInt(_kPomodoroCompletedKey, _completedFocus);
    await _persistSettings();
  }

  Future<void> _persistIdle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPomodoroEndKey);
    await prefs.setString(_kPomodoroPhaseKey, PomodoroPhase.idle.storage);
    await prefs.setInt(_kPomodoroCompletedKey, _completedFocus);
    await _persistSettings();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    if (_endAt == null) return;
    final now = DateTime.now();
    final left = _endAt!.difference(now);
    if (left.inMilliseconds <= 0) {
      _remaining = Duration.zero;
      _onPhaseDone();
    } else {
      _remaining = left;
      notifyListeners();
    }
  }

  /// Computes the next phase + duration, persists, fires cue, and either
  /// starts the next ticker or goes idle. Always notifies.
  ///
  /// When [_soundOn] is true, the melody loops and we *gate* the next
  /// phase: the timer stays at its full duration, ticker is not started,
  /// and [_awaitingDismissal] flips to true. The UI is expected to show
  /// a blocking alert and call [acknowledgePhaseTransition] when the user
  /// dismisses it — that's when the next phase actually begins counting.
  void _onPhaseDone({bool silent = false}) {
    _ticker?.cancel();
    final wasFocus = _phase == PomodoroPhase.focus;
    final wasBreak = _phase == PomodoroPhase.breakTime ||
        _phase == PomodoroPhase.longBreak;
    _justCompleted = _phase;

    PomodoroPhase next;
    int dur;
    if (wasFocus) {
      _completedFocus += 1;
      final isLong = _completedFocus % _longBreakEvery == 0;
      next = isLong ? PomodoroPhase.longBreak : PomodoroPhase.breakTime;
      dur = isLong ? _longBreakMinutes : _breakMinutes;
    } else if (wasBreak) {
      next = _autoNext ? PomodoroPhase.focus : PomodoroPhase.idle;
      dur = _focusMinutes;
    } else {
      next = PomodoroPhase.idle;
      dur = _focusMinutes;
    }

    _phase = next;
    _remaining = Duration(minutes: dur);

    final wantsGate =
        _soundOn && !silent && next != PomodoroPhase.idle;

    if (wantsGate) {
      // Hold the timer at the next phase's full duration. The ticker is
      // intentionally not started — the user needs to acknowledge the
      // alert first.
      _endAt = null;
      _awaitingDismissal = true;
    } else {
      _endAt = next == PomodoroPhase.idle
          ? null
          : DateTime.now().add(_remaining);
    }

    if (!silent) {
      _firePhaseCue(
        wasFocus: wasFocus,
        wasBreak: wasBreak,
        loopMelody: wantsGate,
      );
    }

    if (!wantsGate &&
        _phase != PomodoroPhase.idle &&
        (wasFocus || (wasBreak && _autoNext))) {
      _startTicker();
      _scheduleEndOfPhaseNotification();
      unawaited(_persistRunning());
    } else if (!wantsGate) {
      unawaited(_persistIdle());
    }
    notifyListeners();
  }

  /// Called by the UI when the user dismisses the «фаза завершена»
  /// alert. Stops the looping melody and starts the next phase's
  /// ticker (or stays idle if there is no next phase). Safe to call
  /// when [_awaitingDismissal] is already false.
  Future<void> acknowledgePhaseTransition() async {
    if (!_awaitingDismissal) return;
    _awaitingDismissal = false;
    await _stopMelody();
    if (_phase != PomodoroPhase.idle) {
      _endAt = DateTime.now().add(_remaining);
      _startTicker();
      _scheduleEndOfPhaseNotification();
      await _persistRunning();
    } else {
      await _persistIdle();
    }
    notifyListeners();
  }

  void _firePhaseCue({
    required bool wasFocus,
    required bool wasBreak,
    bool loopMelody = false,
  }) {
    final title = wasFocus ? 'Фокус завершён' : 'Отдых завершён';
    final body = wasFocus
        ? (_phase == PomodoroPhase.longBreak
            ? 'Длинный отдых $_longBreakMinutes мин'
            : 'Короткий отдых $_breakMinutes мин')
        : (_autoNext
            ? 'Поехали — следующий фокус $_focusMinutes мин'
            : 'Запусти следующий фокус когда готов');

    // Always fire the OS notification — independent of "sound" toggle.
    // The toggle only affects in-app haptic / melody.
    unawaited(NotificationsService.instance.showImmediate(
      title: title,
      body: body,
    ));
    if (_soundOn) {
      unawaited(HapticFeedback.mediumImpact());
      if (loopMelody) {
        unawaited(_playMelodyLoop());
      } else {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
    }
  }

  Future<void> _playMelodyLoop() async {
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.stop();
      await _player!.play(AssetSource('sounds/chime.wav'));
    } catch (e) {
      debugPrint('PomodoroService._playMelodyLoop failed: $e');
      // Fall back to system tone so the user still gets a cue.
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  Future<void> _stopMelody() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  /// Schedules a backup OS notification at the precise moment the current
  /// phase ends. This way the user gets a cue even if the app is fully in
  /// the background and our in-process Timer is paused.
  void _scheduleEndOfPhaseNotification() {
    if (_endAt == null || _phase == PomodoroPhase.idle) return;
    final title = _phase == PomodoroPhase.focus
        ? 'Фокус завершён'
        : 'Отдых завершён';
    final body = _phase == PomodoroPhase.focus
        ? 'Время передохнуть'
        : (_autoNext ? 'Возвращаемся к фокусу' : 'Готов снова работать?');
    final delay = _endAt!.difference(DateTime.now());
    if (delay.inMilliseconds <= 0) return;
    unawaited(NotificationsService.instance.scheduleTest(
      delay: delay,
      title: title,
      body: body,
    ));
  }

  // ===== Public controls =====

  Future<void> startFocus() async {
    _phase = PomodoroPhase.focus;
    _remaining = Duration(minutes: _focusMinutes);
    _endAt = DateTime.now().add(_remaining);
    _startTicker();
    _scheduleEndOfPhaseNotification();
    notifyListeners();
    await _persistRunning();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _awaitingDismissal = false;
    await _stopMelody();
    _phase = PomodoroPhase.idle;
    _remaining = Duration(minutes: _focusMinutes);
    _endAt = null;
    notifyListeners();
    await _persistIdle();
  }

  Future<void> resetCounter() async {
    _completedFocus = 0;
    notifyListeners();
    await _persistRunning();
  }

  Future<void> updateSettings({
    int? focus,
    int? brk,
    int? longBrk,
    int? longEvery,
    bool? autoNext,
    bool? sound,
  }) async {
    if (focus != null) {
      _focusMinutes = focus;
      if (_phase == PomodoroPhase.idle) {
        _remaining = Duration(minutes: focus);
      }
    }
    if (brk != null) _breakMinutes = brk;
    if (longBrk != null) _longBreakMinutes = longBrk;
    if (longEvery != null) _longBreakEvery = longEvery;
    if (autoNext != null) _autoNext = autoNext;
    if (sound != null) _soundOn = sound;
    notifyListeners();
    await _persistSettings();
  }

  double get progress {
    if (_phase == PomodoroPhase.idle) return 0;
    final total = Duration(
        minutes: switch (_phase) {
      PomodoroPhase.focus => _focusMinutes,
      PomodoroPhase.breakTime => _breakMinutes,
      PomodoroPhase.longBreak => _longBreakMinutes,
      PomodoroPhase.idle => _focusMinutes,
    });
    if (total.inSeconds == 0) return 0;
    return (1 - (_remaining.inSeconds / total.inSeconds)).clamp(0.0, 1.0);
  }
}
