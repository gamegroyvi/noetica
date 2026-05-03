import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/plural.dart';
import '../../self/pentagon_painter.dart';
import '../../self/self_screen.dart';

class MiniTreeCard extends ConsumerWidget {
  const MiniTreeCard({super.key, required this.palette, this.onTap});

  final NoeticaPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(scoresProvider);
    final levelStatsAsync = ref.watch(axisLevelStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final radarSize = isDesktop ? 220.0 : 180.0;
    return InkWell(
      onTap: onTap ??
          () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SelfScreen()),
              ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: scoresAsync.when(
          loading: () => SizedBox(height: radarSize + 40),
          error: (_, __) => const SizedBox.shrink(),
          data: (scores) {
            if (scores.isEmpty) {
              return Text(
                'Древо появится после первой ветви',
                style: TextStyle(color: palette.muted, fontSize: 12),
              );
            }
            final levels = levelStatsAsync.valueOrNull ?? const {};
            final topAxis = scores.reduce(
              (a, b) => a.value >= b.value ? a : b,
            );
            final topLevel = levels[topAxis.axis.id]?.level ?? 1;
            final totalXp =
                levels.values.fold<int>(0, (acc, s) => acc + s.totalXp);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${scores.length} '
                      '${plural(scores.length, "ветвь", "ветви", "ветвей")}',
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '  ·  лучшая: ${topAxis.axis.symbol} '
                      '${topAxis.axis.name.toLowerCase()} · L$topLevel',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: radarSize,
                    height: radarSize,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: 1),
                      builder: (_, t, __) => CustomPaint(
                        painter: PentagonPainter(
                          scores: scores,
                          fg: palette.fg,
                          muted: palette.muted,
                          line: palette.line,
                          bg: palette.bg,
                          progress: t,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in scores)
                      _AxisChip(
                        axis: s.axis,
                        level: levels[s.axis.id]?.level ?? 1,
                        palette: palette,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'всего $totalXp XP · тап — древо целиком',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AxisChip extends StatelessWidget {
  const _AxisChip({
    required this.axis,
    required this.level,
    required this.palette,
  });

  final LifeAxis axis;
  final int level;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            axis.symbol,
            style: TextStyle(
              color: palette.fg,
              fontSize: 13,
              fontFamily: 'IBMPlexMono',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            axis.name,
            style: TextStyle(
              color: palette.fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'L$level',
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
