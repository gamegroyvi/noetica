import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/plural.dart';
import '../../../utils/time_utils.dart';
import 'dashboard_stats.dart';

class PulseSection extends StatelessWidget {
  const PulseSection({
    super.key,
    required this.stats,
    required this.axesById,
    required this.palette,
    this.onTapDeadline,
  });

  final DashboardStats stats;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;
  final VoidCallback? onTapDeadline;

  static const _kBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    final dl = stats.nextDeadline;
    final dlValue = dl == null
        ? '—'
        : (dl.difference(DateTime.now()).inHours < 24
            ? '${dl.difference(DateTime.now()).inHours}ч'
            : '${dl.difference(DateTime.now()).inDays}д');
    final dlHint = dl == null
        ? 'нет дедлайнов'
        : 'до ${formatTimestamp(dl)}';
    final bestAxis =
        stats.bestAxis != null ? axesById[stats.bestAxis!] : null;
    final xpWeekHint = stats.totalXpWeek > 0
        ? '${stats.totalXpWeek} за неделю'
        : 'пока тихо';

    final streak = _StatCard(
      palette: palette,
      value: stats.streak.toString(),
      label: 'СТРИК',
      hint: stats.streak == 0
          ? 'начни сегодня'
          : plural(stats.streak, 'день', 'дня', 'дней'),
      footer: SizedBox(
        height: 24,
        child: _WeekBars(perDay: stats.perDay, palette: palette),
      ),
    );
    final xpToday = _StatCard(
      palette: palette,
      value: stats.totalXpToday.toString(),
      label: 'XP СЕГОДНЯ',
      hint: xpWeekHint,
    );
    final bestAxisCard = _StatCard(
      palette: palette,
      value: bestAxis?.symbol ?? '—',
      label: 'ЛУЧШАЯ ОСЬ',
      hint: bestAxis == null
          ? 'нет данных'
          : '${bestAxis.name} · +${stats.bestAxisXp} XP',
    );
    final deadlineCard = _StatCard(
      palette: palette,
      value: dlValue,
      label: 'БЛИЖАЙШИЙ',
      hint: dlHint,
      onTap: onTapDeadline,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kBreakpoint;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: streak),
                const SizedBox(width: 10),
                Expanded(child: xpToday),
                const SizedBox(width: 10),
                Expanded(child: bestAxisCard),
                const SizedBox(width: 10),
                Expanded(child: deadlineCard),
              ],
            ),
          );
        }
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: streak),
                  const SizedBox(width: 10),
                  Expanded(child: xpToday),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: bestAxisCard),
                  const SizedBox(width: 10),
                  Expanded(child: deadlineCard),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.palette,
    required this.value,
    required this.label,
    required this.hint,
    this.footer,
    this.onTap,
  });

  final NoeticaPalette palette;
  final String value;
  final String label;
  final String hint;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: palette.fg,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(color: palette.muted, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: card,
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.perDay, required this.palette});

  final List<int> perDay;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final maxV = perDay.fold<int>(1, (a, b) => b > a ? b : a);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final v in perDay) ...[
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: v / maxV),
              builder: (_, frac, __) {
                return FractionallySizedBox(
                  heightFactor: frac.clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: v == 0 ? palette.line : palette.fg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }
}
