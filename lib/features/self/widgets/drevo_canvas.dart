import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../theme/app_theme.dart';
import '../axis_detail_sheet.dart';
import '../epoch_ceremony.dart';
import '../pentagon_painter.dart';

/// Animated Древо: every time `scores` changes (new task completed,
/// reflection submitted, etc.) the polygon tweens out from 0 → its new
/// size, giving the user a visceral "ветка выросла" cue. Tap on a
/// branch label to open the per-axis detail sheet.
class DrevoCanvas extends ConsumerStatefulWidget {
  const DrevoCanvas({super.key, required this.scores});
  final List<AxisScore> scores;

  @override
  ConsumerState<DrevoCanvas> createState() => _DrevoCanvasState();
}

class _DrevoCanvasState extends ConsumerState<DrevoCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  int? _highlight;

  @override
  void didUpdateWidget(covariant DrevoCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = oldWidget.scores.length != widget.scores.length;
    var increased = false;
    if (!changed) {
      for (var i = 0; i < oldWidget.scores.length; i++) {
        final delta = widget.scores[i].value - oldWidget.scores[i].value;
        if (delta.abs() > 0.01) changed = true;
        if (delta > 0.01) increased = true;
      }
    }
    if (changed) {
      _grow
        ..reset()
        ..forward();
    }
    if (increased) {
      _pulse
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _breath.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final probe = PentagonPainter(
              scores: widget.scores,
              fg: palette.fg,
              muted: palette.muted,
              line: palette.line,
              bg: palette.bg,
            );
            final hit = probe.hitTestAxis(d.localPosition, size);
            if (hit == null) return;
            setState(() => _highlight = hit);
            showAxisDetailSheet(
              context,
              ref,
              score: widget.scores[hit],
            ).whenComplete(() {
              if (mounted) setState(() => _highlight = null);
            });
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_grow, _breath, _pulse]),
            builder: (_, __) {
              final grow = Curves.easeOutBack.transform(_grow.value).clamp(0.0, 1.05);
              final breath = 1 + 0.018 *
                  math.sin(_breath.value * 2 * math.pi);
              final pulse = _pulse.isAnimating
                  ? 1 +
                      0.06 *
                          math.sin(_pulse.value * math.pi) *
                          (1 - _pulse.value)
                  : 1.0;
              final progress = grow * breath * pulse;
              return CustomPaint(
                painter: PentagonPainter(
                  scores: widget.scores,
                  fg: palette.fg,
                  muted: palette.muted,
                  line: palette.line,
                  bg: palette.bg,
                  progress: progress.toDouble(),
                  highlightedAxisIndex: _highlight,
                  bloomedAxes:
                      EpochCeremony.bloomedAxes(widget.scores),
                  bloomPulse: _breath.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        );
      },
    );
  }
}
