import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Persisted across app restarts so the timer resumes if the user closes
/// and reopens the sheet (or the whole app).
const _kPomodoroEndKey = 'noetica.pomodoro.end_at.v1';
const _kPomodoroPhaseKey = 'noetica.pomodoro.phase.v1';
const _kPomodoroFocusMinKey = 'noetica.pomodoro.focus_min.v1';
const _kPomodoroBreakMinKey = 'noetica.pomodoro.break_min.v1';

enum _Phase { idle, focus, breakTime }

extension on _Phase {
  String get storage => switch (this) {
        _Phase.idle => 'idle',
        _Phase.focus => 'focus',
        _Phase.breakTime => 'break',
      };
}

_Phase _parsePhase(String? raw) => switch (raw) {
      'focus' => _Phase.focus,
      'break' => _Phase.breakTime,
      _ => _Phase.idle,
    };

/// Floating Pomodoro controller. Opened as a draggable bottom sheet from
/// the dashboard's AppBar so it stays out of the way but is one tap from
/// any tab.
class PomodoroSheet extends StatefulWidget {
  const PomodoroSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  bool _hydrating = true;

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
    final focusMin = prefs.getInt(_kPomodoroFocusMinKey) ?? 25;
    final breakMin = prefs.getInt(_kPomodoroBreakMinKey) ?? 5;

    DateTime? end;
    if (endRaw != null) end = DateTime.tryParse(endRaw);

    if (!mounted) return;
    setState(() {
      _focusMinutes = focusMin;
      _breakMinutes = breakMin;
      if (phase != _Phase.idle && end != null && end.isAfter(DateTime.now())) {
        _phase = phase;
        _remaining = end.difference(DateTime.now());
        _startTicker();
      } else {
        _phase = _Phase.idle;
        _remaining = Duration(minutes: focusMin);
      }
      _hydrating = false;
    });
  }

  Future<void> _persistRunning() async {
    final prefs = await SharedPreferences.getInstance();
    final end = DateTime.now().add(_remaining);
    await prefs.setString(_kPomodoroEndKey, end.toIso8601String());
    await prefs.setString(_kPomodoroPhaseKey, _phase.storage);
    await prefs.setInt(_kPomodoroFocusMinKey, _focusMinutes);
    await prefs.setInt(_kPomodoroBreakMinKey, _breakMinutes);
  }

  Future<void> _persistIdle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPomodoroEndKey);
    await prefs.setString(_kPomodoroPhaseKey, _Phase.idle.storage);
    await prefs.setInt(_kPomodoroFocusMinKey, _focusMinutes);
    await prefs.setInt(_kPomodoroBreakMinKey, _breakMinutes);
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
    if (wasFocus) {
      _phase = _Phase.breakTime;
      _remaining = Duration(minutes: _breakMinutes);
    } else {
      _phase = _Phase.idle;
      _remaining = Duration(minutes: _focusMinutes);
    }
    _persistRunning();
    if (_phase == _Phase.idle) _persistIdle();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFocus
                ? 'Сессия завершена — отдых $_breakMinutes мин'
                : 'Отдых закончился — давай ещё фокус',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (_phase == _Phase.breakTime) _startTicker();
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_phase == _Phase.idle) return 0;
    final total =
        Duration(minutes: _phase == _Phase.focus ? _focusMinutes : _breakMinutes);
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
            Text(
              switch (_phase) {
                _Phase.idle => 'Pomodoro',
                _Phase.focus => 'Фокус',
                _Phase.breakTime => 'Отдых',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: palette.muted,
                fontWeight: FontWeight.w600,
              ),
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
            if (_phase == _Phase.idle) ...[
              _Stepper(
                label: 'Фокус, мин',
                value: _focusMinutes,
                onChanged: (v) {
                  setState(() {
                    _focusMinutes = v;
                    _remaining = Duration(minutes: v);
                  });
                },
                min: 5,
                max: 90,
                step: 5,
                palette: palette,
              ),
              const SizedBox(height: 8),
              _Stepper(
                label: 'Отдых, мин',
                value: _breakMinutes,
                onChanged: (v) => setState(() => _breakMinutes = v),
                min: 1,
                max: 30,
                step: 1,
                palette: palette,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _startFocus,
                child: const Text('Начать фокус'),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: _stop,
                child: const Text('Стоп'),
              ),
            ],
          ],
        ),
      ),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove),
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
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + step) : null,
        ),
      ],
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
