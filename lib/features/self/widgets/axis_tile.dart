import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../services/levels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// A single axis row showing symbol, name, level/epoch badges,
/// a progress bar, and XP stats.
class AxisTile extends StatelessWidget {
  const AxisTile({
    super.key,
    required this.score,
    this.levelStats,
    this.readOnly = false,
  });
  final AxisScore score;
  final LevelStats? levelStats;

  /// Suppresses the level/XP badges + footer when rendering an
  /// archived эпоха (we don't have those numbers for the past).
  final bool readOnly;

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
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.fg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                S.of(context)!.axisEpochPrefix('${epochFromXp(ls.totalXp)}'),
                                style: TextStyle(
                                  color: palette.bg,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
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
