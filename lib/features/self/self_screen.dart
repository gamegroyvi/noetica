import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/levels.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_glyph.dart';
import '../roadmap/roadmap_screen.dart';
import '../settings/settings_screen.dart';
import 'axes_editor_screen.dart';
import 'axis_detail_sheet.dart';
import 'pentagon_painter.dart';

class SelfScreen extends ConsumerWidget {
  const SelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scoresAsync = ref.watch(scoresProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final streakAsync = ref.watch(streakProvider);
    final levelAsync = ref.watch(levelStatsProvider);
    final axisLevelsAsync = ref.watch(axisLevelStatsProvider);
    final hasName = profile != null && profile.name.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: Text(hasName ? profile.name : 'Я'),
        actions: [
          IconButton(
            tooltip: 'Оси',
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AxesEditorScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: scoresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (scores) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _ProfileHeader(
                level: levelAsync.valueOrNull,
                streak: streakAsync.valueOrNull ?? 0,
                aspiration: profile?.aspiration ?? '',
              ),
              const SizedBox(height: 24),
              if (scores.length < 3)
                _EmptyAxes()
              else ...[
                SizedBox(
                  height: 320,
                  child: _DrevoCanvas(scores: scores),
                ),
                const SizedBox(height: 24),
                Text(
                  'ДРЕВО · ВЕТКИ',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in scores)
                  _AxisTile(
                    score: s,
                    levelStats: axisLevelsAsync.valueOrNull?[s.axis.id],
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RoadmapScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Сгенерировать план'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Очки начисляются за выполнение задач, привязанных к осям. Со временем затухают — пентаграмма отражает тебя за последний месяц.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.muted),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.level,
    required this.streak,
    required this.aspiration,
  });

  final LevelStats? level;
  final int streak;
  final String aspiration;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = level;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BigNumber(
                label: 'УРОВЕНЬ',
                value: l == null ? '—' : 'L${l.level}',
              ),
              const SizedBox(width: 24),
              _BigNumber(
                label: 'XP',
                value: l == null ? '—' : '${l.totalXp}',
              ),
              const SizedBox(width: 24),
              _BigNumber(
                label: 'СТРИК',
                value: streak == 0 ? '—' : '$streak д.',
              ),
            ],
          ),
          if (l != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: l.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'до L${l.level + 1}: ${l.xpForLevel - l.xpIntoLevel} xp',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
          if (aspiration.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '«$aspiration»',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted, fontStyle: FontStyle.italic),
            ),
          ],
          if (streak == 0 && l != null && l.totalXp > 0) ...[
            const SizedBox(height: 12),
            _StreakBreakBanner(),
          ],
        ],
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: palette.fg,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _StreakBreakBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.refresh, size: 18, color: palette.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Стрик прервался. Закрой одну задачу сегодня — начнём заново.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAxes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.workspaces_outline, size: 32, color: palette.muted),
          const SizedBox(height: 12),
          Text(
            'Древо вырастает от 3 ветвей. Добавь хотя бы 3 оси, чтобы '
            'увидеть его.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({required this.score, this.levelStats});
  final AxisScore score;
  final LevelStats? levelStats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = score.value.clamp(0.0, 100.0) / 100.0;
    final ls = levelStats;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score.axis.symbol,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              score.axis.name,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ls != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: palette.line),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'L${ls.level}',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      score.value.round().toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.muted,
                            fontFeatures: const [],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: v),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: palette.line,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
                    ),
                  ),
                ),
                if (ls != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${ls.totalXp} XP · до L${ls.level + 1}: '
                    '${ls.xpAtNextLevel - ls.totalXp}',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Древо: every time `scores` changes (new task completed,
/// reflection submitted, etc.) the polygon tweens out from 0 → its new
/// size, giving the user a visceral "ветка выросла" cue. Tap on a
/// branch label to open the per-axis detail sheet.
class _DrevoCanvas extends ConsumerStatefulWidget {
  const _DrevoCanvas({required this.scores});
  final List<AxisScore> scores;

  @override
  ConsumerState<_DrevoCanvas> createState() => _DrevoCanvasState();
}

class _DrevoCanvasState extends ConsumerState<_DrevoCanvas>
    with TickerProviderStateMixin {
  // One-shot grow animation, replayed when scores change. We use
  // easeOutBack for a slight spring overshoot so the polygon visibly
  // springs into place instead of merely settling.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  // Continuous idle "breathing" — slow oscillation in radius (~±2%) so the
  // tree never feels frozen. Loops indefinitely.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Short reaction pulse fired every time a score increases. Drives a
  // small overshoot that overlays on top of the steady-state shape.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  int? _highlight;

  @override
  void didUpdateWidget(covariant _DrevoCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay the grow animation only when the actual axis values changed
    // — not on every parent rebuild — so casual scrolling doesn't jitter
    // the canvas.
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
            // Build a one-shot painter to reuse its hit-test math.
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
