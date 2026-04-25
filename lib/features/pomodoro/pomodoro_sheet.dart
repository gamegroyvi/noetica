import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notifications.dart';
import '../../theme/app_theme.dart';

/// Persisted across app restarts so the timer resumes if the user closes
/// and reopens the sheet (or the whole app).
const _kPomodoroEndKey = 'noetica.pomodoro.end_at.v1';
const _kPomodoroPhaseKey = 'noetica.pomodoro.phase.v1';
const _kPomodoroFocusMinKey = 'noetica.pomodoro.focus_min.v1';
const _kPomodoroBreakMinKey = 'noetica.pomodoro.break_min.v1';
const _kPomodoroLongBreakMinKey = 'noetica.pomodoro.long_break_min.v1';
const _kPomodoroLongBreakEveryKey = 'noetica.pomodoro.long_break_every.v1';
const _kPomodoroAutoNextKey = 'noetica.pomodoro.auto_next.v1';
const _kPomodoroSoundKey = 'noetica.pomodoro.sound.v1';
const _kPomodoroCompletedKey = 'noetica.pomodoro.completed_focus.v1';

enum _Phase { idle, focus, breakTime, longBreak }

extension on _Phase {
  String get storage => switch (this) {
        _Phase.idle => 'idle',
        _Phase.focus => 'focus',
        _Phase.breakTime => 'break',
        _Phase.longBreak => 'long_break',
      };

  String get label => switch (this) {
        _Phase.idle => 'Pomodoro',
        _Phase.focus => 'Фокус',
        _Phase.breakTime => 'Короткий отдых',
        _Phase.longBreak => 'Длинный отдых',
      };
}

_Phase _parsePhase(String? raw) => switch (raw) {
      'focus' => _Phase.focus,
      'break' => _Phase.breakTime,
      'long_break' => _Phase.longBreak,
      _ => _Phase.idle,
    };

/// Floating Pomodoro controller. Opened as a draggable bottom sheet from
/// the dashboard's AppBar / sidebar so it stays out of the way but is one
/// tap from any tab.
class PomodoroSheet extends StatefulWidget {
  const PomodoroSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => const PomodoroSheet(),
    );
  }

  @override
  State<PomodoroSheet> createState() => _PomodoroSheetState();
}

class _PomodoroSheetState extends State<PomodoroSheet> {
  Timer? _ticker;
  _Phase _phase = _Phase.idle;
  Duration _remaining = Duration.zero;

  // Settings (all persisted).
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  int _longBreakMinutes = 15;
  int _longBreakEvery = 4; // every Nth focus session
  bool _autoNext = true;
  bool _soundOn = false;

  int _completedFocus = 0;
  bool _hydrating = true;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final phase = _parsePhase(prefs.getString(_kPomodoroPhaseKey));
    final endRaw = prefs.getString(_kPomodoroEndKey);

    DateTime? end;
    if (endRaw != null) end = DateTime.tryParse(endRaw);

    if (!mounted) return;
    setState(() {
      _focusMinutes = prefs.getInt(_kPomodoroFocusMinKey) ?? 25;
      _breakMinutes = prefs.getInt(_kPomodoroBreakMinKey) ?? 5;
      _longBreakMinutes = prefs.getInt(_kPomodoroLongBreakMinKey) ?? 15;
      _longBreakEvery = prefs.getInt(_kPomodoroLongBreakEveryKey) ?? 4;
      _autoNext = prefs.getBool(_kPomodoroAutoNextKey) ?? true;
      _soundOn = prefs.getBool(_kPomodoroSoundKey) ?? false;
      _completedFocus = prefs.getInt(_kPomodoroCompletedKey) ?? 0;

      if (phase != _Phase.idle && end != null && end.isAfter(DateTime.now())) {
        _phase = phase;
        _remaining = end.difference(DateTime.now());
        _startTicker();
      } else {
        _phase = _Phase.idle;
        _remaining = Duration(minutes: _focusMinutes);
      }
      _hydrating = false;
    });
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
    final end = DateTime.now().add(_remaining);
    await prefs.setString(_kPomodoroEndKey, end.toIso8601String());
    await prefs.setString(_kPomodoroPhaseKey, _phase.storage);
    await prefs.setInt(_kPomodoroCompletedKey, _completedFocus);
    await _persistSettings();
  }

  Future<void> _persistIdle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPomodoroEndKey);
    await prefs.setString(_kPomodoroPhaseKey, _Phase.idle.storage);
    await prefs.setInt(_kPomodoroCompletedKey, _completedFocus);
    await _persistSettings();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
        if (_remaining.isNegative || _remaining == Duration.zero) {
          _onPhaseDone();
        }
      });
    });
  }

  void _onPhaseDone() {
    _ticker?.cancel();
    final wasFocus = _phase == _Phase.focus;
    final wasBreak =
        _phase == _Phase.breakTime || _phase == _Phase.longBreak;

    if (wasFocus) {
      _completedFocus += 1;
      // Long break every Nth completed focus.
      final isLong = _completedFocus % _longBreakEvery == 0;
      _phase = isLong ? _Phase.longBreak : _Phase.breakTime;
      _remaining =
          Duration(minutes: isLong ? _longBreakMinutes : _breakMinutes);
    } else {
      // Came out of a break — back to focus (or idle, if auto-next off).
      _phase = _autoNext ? _Phase.focus : _Phase.idle;
      _remaining = Duration(minutes: _focusMinutes);
    }

    if (_phase == _Phase.idle) {
      _persistIdle();
    } else {
      _persistRunning();
    }

    final transitionTitle = wasFocus
        ? (_phase == _Phase.longBreak
            ? 'Сессия завершена — длинный отдых $_longBreakMinutes мин'
            : 'Сессия завершена — отдых $_breakMinutes мин')
        : (_autoNext
            ? 'Отдых закончился — давай ещё фокус'
            : 'Отдых закончился. Запусти следующий фокус когда готов.');

    // Audible / OS-level cue. SystemSound.alert plays on Android/iOS;
    // on desktop we fire a real toast through NotificationsService —
    // Windows toasts come with a default ding, which is exactly what the
    // user expects when the timer hits zero.
    if (_soundOn) {
      // Best-effort short tone on mobile.
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
      // Real toast (desktop fires a Windows toast with sound, mobile shows
      // a high-importance notification).
      NotificationsService.instance.showImmediate(
        title: wasFocus ? 'Фокус завершён' : 'Отдых завершён',
        body: transitionTitle,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(transitionTitle),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (_phase != _Phase.idle && (wasFocus || (wasBreak && _autoNext))) {
      _startTicker();
    }
  }

  void _startFocus() {
    setState(() {
      _phase = _Phase.focus;
      _remaining = Duration(minutes: _focusMinutes);
    });
    _startTicker();
    _persistRunning();
  }

  void _stop() {
    setState(() {
      _phase = _Phase.idle;
      _remaining = Duration(minutes: _focusMinutes);
    });
    _ticker?.cancel();
    _persistIdle();
  }

  void _resetCounter() {
    setState(() => _completedFocus = 0);
    _persistRunning();
  }

  String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  double get _progress {
    if (_phase == _Phase.idle) return 0;
    final total = Duration(
        minutes: switch (_phase) {
      _Phase.focus => _focusMinutes,
      _Phase.breakTime => _breakMinutes,
      _Phase.longBreak => _longBreakMinutes,
      _Phase.idle => _focusMinutes,
    });
    if (total.inSeconds == 0) return 0;
    return 1 - (_remaining.inSeconds / total.inSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_hydrating) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhaseHeader(
              phase: _phase,
              palette: palette,
              completedFocus: _completedFocus,
              onResetCounter: _completedFocus > 0 ? _resetCounter : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: _progress,
                      ringColor: palette.fg,
                      bgColor: palette.line,
                    ),
                    child: Center(
                      child: Text(
                        _fmt(_remaining),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: palette.fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Primary action.
            if (_phase == _Phase.idle)
              FilledButton(
                onPressed: _startFocus,
                child: const Text('Начать фокус'),
              )
            else
              OutlinedButton(
                onPressed: _stop,
                child: const Text('Стоп'),
              ),
            const SizedBox(height: 8),
            // Settings — collapsed by default to keep the sheet clean.
            _SettingsPanel(
              expanded: _settingsOpen,
              onToggle: () =>
                  setState(() => _settingsOpen = !_settingsOpen),
              palette: palette,
              focusMinutes: _focusMinutes,
              breakMinutes: _breakMinutes,
              longBreakMinutes: _longBreakMinutes,
              longBreakEvery: _longBreakEvery,
              autoNext: _autoNext,
              soundOn: _soundOn,
              onChange: ({
                int? focus,
                int? brk,
                int? longBrk,
                int? longEvery,
                bool? autoNext,
                bool? sound,
              }) {
                setState(() {
                  if (focus != null) {
                    _focusMinutes = focus;
                    if (_phase == _Phase.idle) {
                      _remaining = Duration(minutes: focus);
                    }
                  }
                  if (brk != null) _breakMinutes = brk;
                  if (longBrk != null) _longBreakMinutes = longBrk;
                  if (longEvery != null) _longBreakEvery = longEvery;
                  if (autoNext != null) _autoNext = autoNext;
                  if (sound != null) _soundOn = sound;
                });
                _persistSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.phase,
    required this.palette,
    required this.completedFocus,
    required this.onResetCounter,
  });

  final _Phase phase;
  final NoeticaPalette palette;
  final int completedFocus;
  final VoidCallback? onResetCounter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(
          child: Text(
            phase.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: onResetCounter,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Tooltip(
              message: onResetCounter == null
                  ? 'Серия фокус-сессий'
                  : 'Серия фокус-сессий — нажми чтобы сбросить',
              child: Text(
                '✦ $completedFocus',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.expanded,
    required this.onToggle,
    required this.palette,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.longBreakMinutes,
    required this.longBreakEvery,
    required this.autoNext,
    required this.soundOn,
    required this.onChange,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final NoeticaPalette palette;
  final int focusMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int longBreakEvery;
  final bool autoNext;
  final bool soundOn;
  final void Function({
    int? focus,
    int? brk,
    int? longBrk,
    int? longEvery,
    bool? autoNext,
    bool? sound,
  }) onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: palette.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Настройки',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          _Stepper(
            label: 'Фокус, мин',
            value: focusMinutes,
            onChanged: (v) => onChange(focus: v),
            min: 1,
            max: 180,
            step: 1,
            palette: palette,
          ),
          _Stepper(
            label: 'Короткий отдых, мин',
            value: breakMinutes,
            onChanged: (v) => onChange(brk: v),
            min: 1,
            max: 30,
            step: 1,
            palette: palette,
          ),
          _Stepper(
            label: 'Длинный отдых, мин',
            value: longBreakMinutes,
            onChanged: (v) => onChange(longBrk: v),
            min: 1,
            max: 60,
            step: 1,
            palette: palette,
          ),
          _Stepper(
            label: 'Длинный отдых каждые N фокусов',
            value: longBreakEvery,
            onChanged: (v) => onChange(longEvery: v),
            min: 2,
            max: 8,
            step: 1,
            palette: palette,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Авто-старт следующей фазы'),
            subtitle: Text(
              'После окончания фокуса/отдыха таймер продолжается сам',
              style: TextStyle(color: palette.muted, fontSize: 11),
            ),
            value: autoNext,
            onChanged: (v) => onChange(autoNext: v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Звук уведомления'),
            subtitle: Text(
              'Системный звук при смене фазы (требует системных уведомлений)',
              style: TextStyle(color: palette.muted, fontSize: 11),
            ),
            value: soundOn,
            onChanged: (v) => onChange(sound: v),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
    required this.palette,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.bgColor,
  });

  final double progress;
  final Color ringColor;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress.clamp(0, 1) * 2 * math.pi,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.bgColor != bgColor;
}
