import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../widgets/brand_glyph.dart';
import '../entry/entry_card.dart';
import '../entry/entry_editor_sheet.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../self/pentagon_painter.dart';
import '../tasks/tasks_screen.dart';

/// "Сейчас" tab — at-a-glance dashboard:
/// streak / week activity / top axes / nearest task / timeline.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final scoresAsync = ref.watch(scoresProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: const Text('Сейчас'),
        actions: [
          IconButton(
            tooltip: 'Журнал',
            icon: const Icon(Icons.bookmark_border_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotesScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Pomodoro',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => PomodoroSheet.show(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          final axes = axesAsync.valueOrNull ?? const <LifeAxis>[];
          final scores = scoresAsync.valueOrNull ?? const <AxisScore>[];
          final axesById = {for (final a in axes) a.id: a};

          if (entries.isEmpty) {
            return _Empty(palette: palette);
          }

          // Active tasks sorted by due-asc / created-desc.
          final activeTasks = entries.where((e) => e.isTask && !e.isCompleted).toList()
            ..sort((a, b) {
              final ad = a.dueAt;
              final bd = b.dueAt;
              if (ad == null && bd != null) return 1;
              if (ad != null && bd == null) return -1;
              if (ad != null && bd != null) return ad.compareTo(bd);
              return b.createdAt.compareTo(a.createdAt);
            });

          // Timeline: full reverse-chrono list with gap dividers.
          final timelineWidgets = <Widget>[];
          for (var i = 0; i < entries.length; i++) {
            final e = entries[i];
            if (i > 0) {
              final prev = entries[i - 1];
              timelineWidgets.add(GapDivider(
                from: e.createdAt,
                to: prev.createdAt,
              ));
            }
            timelineWidgets.add(EntryCard(entry: e, axesById: axesById));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _StatsHero(
                entries: entries,
                palette: palette,
              ),
              const SizedBox(height: 14),
              if (scores.length >= 3)
                _PentagonCard(scores: scores, palette: palette),
              if (scores.length >= 3) const SizedBox(height: 14),
              _NearestTasksCard(
                tasks: activeTasks.take(3).toList(),
                axesById: axesById,
                palette: palette,
                hasMore: activeTasks.length > 3,
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'ЛЕНТА',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.muted,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              for (final w in timelineWidgets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: w,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.entries, required this.palette});

  final List<Entry> entries;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final stats = _DashboardStats.from(entries);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Metric(
                value: stats.streak.toString(),
                label: stats.streak == 0
                    ? 'нет стрика'
                    : _plural(stats.streak, 'день', 'дня', 'дней'),
                palette: palette,
              ),
              const SizedBox(width: 24),
              _Metric(
                value: stats.todayCompleted.toString(),
                label: 'выполнено сегодня',
                palette: palette,
              ),
              const SizedBox(width: 24),
              _Metric(
                value: stats.weekCompleted.toString(),
                label: 'за неделю',
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WeekBars(perDay: stats.perDay, palette: palette),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _weekdayLabel(stats.firstDay),
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
              Text(
                'сегодня',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.palette,
  });

  final String value;
  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: palette.fg,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.perDay, required this.palette});

  /// Last-7-days completion counts, oldest first.
  final List<int> perDay;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final maxV = perDay.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 44,
      child: Row(
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
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _PentagonCard extends StatelessWidget {
  const _PentagonCard({required this.scores, required this.palette});

  final List<AxisScore> scores;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final sorted = [...scores]..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'РОСТ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.muted,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                for (final s in sorted.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(s.axis.symbol,
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.fg,
                            )),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.axis.name,
                            style: TextStyle(
                              color: palette.fg,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          s.value.round().toString(),
                          style: TextStyle(color: palette.muted),
                        ),
                      ],
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

class _NearestTasksCard extends ConsumerWidget {
  const _NearestTasksCard({
    required this.tasks,
    required this.axesById,
    required this.palette,
    required this.hasMore,
  });

  final List<Entry> tasks;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;
  final bool hasMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'БЛИЖАЙШИЕ ЗАДАЧИ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.muted,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (hasMore)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasksScreen()),
                  ),
                  child: Text(
                    'Все →',
                    style: TextStyle(color: palette.fg),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Активных задач нет.',
                style: TextStyle(color: palette.muted),
              ),
            )
          else
            for (final t in tasks)
              _NearestTaskRow(task: t, axesById: axesById, palette: palette),
        ],
      ),
    );
  }
}

class _NearestTaskRow extends ConsumerWidget {
  const _NearestTaskRow({
    required this.task,
    required this.axesById,
    required this.palette,
  });

  final Entry task;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue =
        task.dueAt != null && task.dueAt!.isBefore(DateTime.now());
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: task),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final repo = await ref.read(repositoryProvider.future);
                await repo.toggleTaskComplete(task);
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.fg, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isEmpty ? '—' : task.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.dueAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'до ${formatTimestamp(task.dueAt!)}',
                        style: TextStyle(
                          color: overdue ? palette.fg : palette.muted,
                          fontSize: 11,
                          fontWeight:
                              overdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (task.axisIds.isNotEmpty &&
                axesById[task.axisIds.first] != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  axesById[task.axisIds.first]!.symbol,
                  style: TextStyle(color: palette.fg, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette});
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Здесь пока пусто',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Создай первую запись через «+». Можно начать с заметки или сразу с задачи.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight aggregations for the dashboard hero. All time math is calendar
/// based to stay stable across DST transitions.
class _DashboardStats {
  _DashboardStats({
    required this.streak,
    required this.todayCompleted,
    required this.weekCompleted,
    required this.perDay,
    required this.firstDay,
  });

  final int streak;
  final int todayCompleted;
  final int weekCompleted;

  /// Last-7-days completion counts, oldest first.
  final List<int> perDay;

  /// First (oldest) day in [perDay].
  final DateTime firstDay;

  factory _DashboardStats.from(List<Entry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(today.year, today.month, today.day - 6);

    // Streak: consecutive days (back from today) with at least one entry.
    final activeDays = <DateTime>{};
    for (final e in entries) {
      activeDays.add(DateTime(
        e.createdAt.year,
        e.createdAt.month,
        e.createdAt.day,
      ));
    }
    var streak = 0;
    var cursor = today;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    // Daily completion histogram for the last 7 days (oldest -> today).
    final perDay = List<int>.filled(7, 0);
    for (final e in entries) {
      final completedAt = e.completedAt;
      if (completedAt == null) continue;
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      final diff = today.difference(day).inDays;
      if (diff >= 0 && diff < 7) {
        perDay[6 - diff] += 1;
      }
    }

    return _DashboardStats(
      streak: streak,
      todayCompleted: perDay[6],
      weekCompleted: perDay.fold(0, (a, b) => a + b),
      perDay: perDay,
      firstDay: firstDay,
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

const _ruWeekdays = [
  'пн',
  'вт',
  'ср',
  'чт',
  'пт',
  'сб',
  'вс',
];

String _weekdayLabel(DateTime d) {
  // Dart: Monday=1..Sunday=7
  return _ruWeekdays[d.weekday - 1];
}
