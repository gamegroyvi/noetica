import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/levels.dart';
import '../../theme/app_theme.dart';
import '../roadmap/roadmap_screen.dart';
import '../settings/settings_screen.dart';
import 'axes_editor_screen.dart';
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
    final hasName = profile != null && profile.name.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
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
                  child: CustomPaint(
                    painter: PentagonPainter(
                      scores: scores,
                      fg: palette.fg,
                      muted: palette.muted,
                      line: palette.line,
                      bg: palette.bg,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ТЕКУЩЕЕ СОСТОЯНИЕ',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final s in scores) _AxisTile(score: s),
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
            'Чтобы увидеть пентаграмму, нужно хотя бы 3 оси.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({required this.score});
  final AxisScore score;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = score.value.clamp(0.0, 100.0) / 100.0;
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
                  children: [
                    Text(
                      score.axis.name,
                      style: Theme.of(context).textTheme.bodyLarge,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
