import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/pomodoro_service.dart';
import '../../theme/app_theme.dart';

/// Floating Pomodoro controller. The actual timer / phase logic lives in
/// `PomodoroService` (singleton, process-wide) so it keeps ticking even
/// when this sheet is closed.
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
  final _service = PomodoroService.instance;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    // Make sure we're hydrated even if init() hasn't finished yet (e.g.
    // the user opens the sheet on a cold start before main() finished).
    _service.init();
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        if (!_service.hydrated) {
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
                  phase: _service.phase,
                  palette: palette,
                  completedFocus: _service.completedFocus,
                  onResetCounter: _service.completedFocus > 0
                      ? _service.resetCounter
                      : null,
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
                          progress: _service.progress,
                          ringColor: palette.fg,
                          bgColor: palette.line,
                        ),
                        child: Center(
                          child: Text(
                            _fmt(_service.remaining),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: palette.fg,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_service.phase == PomodoroPhase.idle)
                  FilledButton(
                    onPressed: _service.startFocus,
                    child: const Text('Начать фокус'),
                  )
                else
                  OutlinedButton(
                    onPressed: _service.stop,
                    child: const Text('Стоп'),
                  ),
                const SizedBox(height: 8),
                _SettingsPanel(
                  expanded: _settingsOpen,
                  onToggle: () =>
                      setState(() => _settingsOpen = !_settingsOpen),
                  palette: palette,
                  focusMinutes: _service.focusMinutes,
                  breakMinutes: _service.breakMinutes,
                  longBreakMinutes: _service.longBreakMinutes,
                  longBreakEvery: _service.longBreakEvery,
                  autoNext: _service.autoNext,
                  soundOn: _service.soundOn,
                  onChange: ({
                    int? focus,
                    int? brk,
                    int? longBrk,
                    int? longEvery,
                    bool? autoNext,
                    bool? sound,
                  }) {
                    _service.updateSettings(
                      focus: focus,
                      brk: brk,
                      longBrk: longBrk,
                      longEvery: longEvery,
                      autoNext: autoNext,
                      sound: sound,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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

  final PomodoroPhase phase;
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
            title: const Text('Звук + вибрация'),
            subtitle: Text(
              'Системный «дзынь» и хаптик при смене фазы '
              '(уведомление приходит в любом случае)',
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
