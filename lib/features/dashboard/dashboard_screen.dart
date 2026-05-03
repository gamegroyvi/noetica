import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
import '../../utils/plural.dart';
import '../../utils/time_utils.dart';
import '../../widgets/brand_glyph.dart';
import '../../services/weekly_reflection_service.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/day_detail_sheet.dart';
import '../entry/entry_editor_sheet.dart';
import '../home/home_shell.dart' show kFloatingTabBarReserve;
import '../knowledge/knowledge_graph_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../reflection/weekly_reflection_sheet.dart';
import '../roadmap/roadmap_screen.dart';
import '../self/self_screen.dart';
import '../tasks/tasks_screen.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/dashboard_stats.dart';
import 'widgets/mini_tree_card.dart';
import 'widgets/pulse_section.dart';

/// "Сейчас" tab — focused dashboard.
///
/// Tight visual hierarchy:
///   1. Greeting + today summary
///   2. «Сейчас» — the single task to act on right now
///   3. «Сегодня» — compact list of today's tasks
///   4. «Пульс» — week bars + streak in one horizontal strip
///   5. «Последнее» — last 3 entries, link to Журнал
class DashboardScreen extends ConsumerStatefulWidget {
  /// Optional tab-switching callbacks. When the dashboard is hosted inside
  /// `HomeShell`, these route taps on "Древо" / "Журнал" headers to the
  /// matching tab in the IndexedStack instead of pushing a new route
  /// (which would hide the sidebar/bottom-bar). When null, the dashboard
  /// falls back to `Navigator.push` so it still works standalone.
  const DashboardScreen({
    super.key,
    this.onOpenSelf,
    this.onOpenTasks,
    this.onOpenJournal,
    this.onOpenCalendar,
  });

  final VoidCallback? onOpenSelf;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenJournal;
  final VoidCallback? onOpenCalendar;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showWeeklyBanner = false;

  @override
  void initState() {
    super.initState();
    _checkWeeklyPrompt();
  }

  Future<void> _checkWeeklyPrompt() async {
    final should = await WeeklyReflectionService.instance.shouldPrompt();
    if (!mounted) return;
    if (should != _showWeeklyBanner) {
      setState(() => _showWeeklyBanner = should);
    }
  }

  Future<void> _openWeeklyReflection() async {
    await WeeklyReflectionSheet.show(context);
    if (!mounted) return;
    // Re-check (the user may have submitted, snoozed, or just dismissed).
    _checkWeeklyPrompt();
  }

  /// Open the "Я" tab. Prefers the host callback (in HomeShell — keeps
  /// sidebar/bottom-bar visible). Falls back to a plain push when the
  /// dashboard is hosted outside the shell.
  void _openSelf() {
    final cb = widget.onOpenSelf;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SelfScreen()),
      );
    }
  }

  /// Tasks live in the primary-tab rail (index 1 in HomeShell), so a tab
  /// switch works everywhere. We still fall back to a push when the
  /// dashboard is hosted outside the shell.
  void _openTasks() {
    final cb = widget.onOpenTasks;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
      );
    }
  }

  void _openCalendar() {
    final cb = widget.onOpenCalendar;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final profileAsync = ref.watch(profileProvider);

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
          final axesById = {for (final a in axes) a.id: a};

          if (entries.isEmpty) {
            return _OnboardingHints(
              palette: palette,
              profile: profileAsync.valueOrNull,
              onCreateEntry: () =>
                  showEntryEditor(context, ref).then((_) {
                if (!mounted) return;
                setState(() {});
              }),
              onOpenRoadmap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapScreen(),
                ),
              ),
              onOpenKnowledge: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KnowledgeGraphScreen(),
                ),
              ),
              onOpenSelf: _openSelf,
            );
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final endOfToday = today.add(const Duration(days: 1));

          final activeTasks =
              entries.where((e) => e.isTask && !e.isCompleted).toList()
                ..sort((a, b) {
                  final ad = a.dueAt;
                  final bd = b.dueAt;
                  if (ad == null && bd != null) return 1;
                  if (ad != null && bd == null) return -1;
                  if (ad != null && bd != null) return ad.compareTo(bd);
                  return b.createdAt.compareTo(a.createdAt);
                });

          final overdue =
              activeTasks.where((t) => t.dueAt != null && t.dueAt!.isBefore(now));
          final dueToday = activeTasks.where((t) =>
              t.dueAt != null &&
              !t.dueAt!.isBefore(today) &&
              t.dueAt!.isBefore(endOfToday));

          // Now-focus pick: first overdue → first due-today → first active.
          final focus = overdue.isNotEmpty
              ? overdue.first
              : (dueToday.isNotEmpty
                  ? dueToday.first
                  : (activeTasks.isNotEmpty ? activeTasks.first : null));

          // Today list (excludes the focus pick to avoid duplicate row).
          final todayList = [
            ...overdue.where((e) => e.id != focus?.id),
            ...dueToday.where((e) => e.id != focus?.id),
          ];

          final stats = DashboardStats.from(entries);
          final greeting = _greeting(now, profileAsync.valueOrNull?.name);

          return ListView(
            // Reserve space for the floating capsule + FAB hovering above it.
            padding: const
                EdgeInsets.fromLTRB(16, 8, 16, 24 + kFloatingTabBarReserve),
            children: [
              if (_showWeeklyBanner) ...[
                _WeeklyBanner(
                  palette: palette,
                  onOpen: _openWeeklyReflection,
                ),
                const SizedBox(height: 14),
              ],
              _Greeting(
                title: greeting,
                subtitle: _todaySubtitle(stats, overdue.length, dueToday.length),
                palette: palette,
              ),
              const SizedBox(height: 12),
              _ProductLoopStrip(
                palette: palette,
                onOpenRoadmap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapScreen(),
                  ),
                ),
                onOpenTasks: _openTasks,
                onCreateReflection: () =>
                    showEntryEditor(context, ref, initialKind: EntryKind.note),
                onOpenSelf: _openSelf,
              ),
              const SizedBox(height: 18),
              _SectionHeader(label: 'СЕЙЧАС', palette: palette),
              const SizedBox(height: 8),
              _NowFocusCard(
                task: focus,
                axesById: axesById,
                palette: palette,
              ),
              if (todayList.isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionHeader(
                  label: 'СЕГОДНЯ',
                  palette: palette,
                  trailing: '${todayList.length}',
                ),
                const SizedBox(height: 4),
                for (final t in todayList.take(6))
                  _CompactTaskRow(
                    task: t,
                    axesById: axesById,
                    palette: palette,
                  ),
                if (todayList.length > 6)
                  _AllTasksLink(
                    label: 'ещё ${todayList.length - 6} задач',
                    palette: palette,
                  ),
              ],
              const SizedBox(height: 22),
              _SectionHeader(label: 'ПУЛЬС', palette: palette),
              const SizedBox(height: 8),
              PulseSection(
                stats: stats,
                axesById: axesById,
                palette: palette,
                onTapDeadline: focus == null
                    ? null
                    : () => showEntryEditor(context, ref, existing: focus),
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                label: 'АКТИВНОСТЬ',
                palette: palette,
                trailing: 'календарь →',
                onTrailingTap: _openCalendar,
              ),
              const SizedBox(height: 8),
              // No width cap: the heatmap stretches to the card width on
              // desktop and becomes horizontally scrollable on narrow
              // viewports, matching GitHub's behaviour.
              ActivityHeatmap(
                entries: entries,
                palette: palette,
                onTapDay: (date) => showDayDetailSheet(
                  context,
                  date,
                  onOpenCalendar: _openCalendar,
                ),
              ),
              if (axes.length >= 3) ...[
                const SizedBox(height: 22),
                _SectionHeader(
                  label: 'ДРЕВО',
                  palette: palette,
                  trailing: 'все →',
                  onTrailingTap: _openSelf,
                ),
                const SizedBox(height: 8),
                MiniTreeCard(palette: palette, onTap: _openSelf),
              ],
              const SizedBox(height: 22),
              _SectionHeader(
                // Previously this block was labelled "ПОСЛЕДНЕЕ" and routed
                // to the journal, but the journal is for notes only —
                // jumping there from a list of mixed entries felt broken.
                // The dashboard's own "СЕГОДНЯ" block already covers tasks
                // due today; this tail strip now shows the last few
                // closed tasks and links to the full Tasks tab.
                label: 'НЕДАВНО ЗАКРЫТО',
                palette: palette,
                trailing: 'задачи →',
                onTrailingTap: _openTasks,
              ),
              const SizedBox(height: 4),
              // `entries` is ordered by createdAt DESC; sort the
              // completed-task subset by completion time before taking
              // the top 4 so the header's "НЕДАВНО ЗАКРЫТО" promise
              // actually holds (otherwise a task created long ago but
              // just closed would be hidden behind recent creations).
              for (final e in (entries
                      .where((e) => e.isTask && e.isCompleted)
                      .toList()
                    ..sort((a, b) => (b.completedAt ?? b.updatedAt)
                        .compareTo(a.completedAt ?? a.updatedAt)))
                  .take(4))
                _CompactEntryRow(
                  entry: e,
                  axesById: axesById,
                  palette: palette,
                  useCompletedAt: true,
                ),
            ],
          );
        },
      ),
    );
  }
}

String _greeting(DateTime now, String? name) {
  final h = now.hour;
  final base = h < 5
      ? 'Доброй ночи'
      : (h < 12 ? 'Доброе утро' : (h < 18 ? 'Добрый день' : 'Добрый вечер'));
  if (name == null || name.trim().isEmpty) return base;
  return '$base, ${name.trim().split(' ').first}';
}

String _todaySubtitle(DashboardStats stats, int overdue, int today) {
  final parts = <String>[];
  if (overdue > 0) {
    parts.add('$overdue ${plural(overdue, "просрочена", "просрочено", "просрочено")}');
  }
  if (today > 0) parts.add('$today на сегодня');
  if (parts.isEmpty) {
    if (stats.streak > 0) {
      return 'стрик ${stats.streak} ${plural(stats.streak, "день", "дня", "дней")}';
    }
    return 'свободный день';
  }
  return parts.join(' · ');
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _ProductLoopStrip extends StatelessWidget {
  const _ProductLoopStrip({
    required this.palette,
    required this.onOpenRoadmap,
    required this.onOpenTasks,
    required this.onCreateReflection,
    required this.onOpenSelf,
  });

  final NoeticaPalette palette;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onOpenTasks;
  final VoidCallback onCreateReflection;
  final VoidCallback onOpenSelf;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Петля роста',
            style: TextStyle(
              color: palette.fg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'План → действие → рефлексия → сильнее следующий план',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LoopChip(
                icon: Icons.route_outlined,
                label: 'План',
                onTap: onOpenRoadmap,
              ),
              _LoopChip(
                icon: Icons.check_circle_outline,
                label: 'Задача',
                onTap: onOpenTasks,
              ),
              _LoopChip(
                icon: Icons.psychology_alt_outlined,
                label: 'Рефлексия',
                onTap: onCreateReflection,
              ),
              _LoopChip(
                icon: Icons.radar_outlined,
                label: 'Пентаграмма',
                onTap: onOpenSelf,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopChip extends StatelessWidget {
  const _LoopChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      side: BorderSide(color: palette.line),
      backgroundColor: palette.bg,
      labelStyle: TextStyle(color: palette.fg, fontWeight: FontWeight.w700),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.palette,
    this.trailing,
    this.onTrailingTap,
  });

  final String label;
  final NoeticaPalette palette;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            onTap: onTrailingTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                trailing!,
                style: TextStyle(
                  color: onTrailingTap != null ? palette.fg : palette.muted,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NowFocusCard extends ConsumerWidget {
  const _NowFocusCard({
    required this.task,
    required this.axesById,
    required this.palette,
  });

  final Entry? task;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: palette.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Активных задач нет — отдохни или создай новую.',
                style: TextStyle(color: palette.fg, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    final t = task!;
    final overdue = t.dueAt != null && t.dueAt!.isBefore(DateTime.now());
    final firstAxis =
        t.axisIds.isNotEmpty ? axesById[t.axisIds.first] : null;

    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: t),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: overdue ? palette.fg : palette.line,
            width: overdue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.title.isEmpty ? '—' : t.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (firstAxis != null) ...[
                  const SizedBox(width: 8),
                  Text(firstAxis.symbol,
                      style: TextStyle(color: palette.fg, fontSize: 18)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.dueAt != null
                  ? (overdue
                      ? 'просрочена · ${formatTimestamp(t.dueAt!)}'
                      : 'до ${formatTimestamp(t.dueAt!)}')
                  : 'без дедлайна',
              style: TextStyle(
                color: overdue ? palette.fg : palette.muted,
                fontSize: 12,
                fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            // Primary: mark as done. Secondary: snooze the deadline in
            // case the user is acting on the task but not ready to
            // finish yet ("иду в качалку — дай ещё час"). Pomodoro /
            // focus timer is reachable from the AppBar icon; baking
            // it into the card as a primary CTA made no sense for the
            // majority of tasks (physical, chores, errands).
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        toggleTaskWithReflection(context, ref, t),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Готово'),
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: palette.fg,
                      foregroundColor: palette.bg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _snoozeTask(context, ref, t),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('Отложить'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: palette.fg,
                      side: BorderSide(color: palette.line),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Запустить таймер фокуса',
                  onPressed: () => PomodoroSheet.show(context),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  color: palette.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _snoozeTask(
    BuildContext context,
    WidgetRef ref,
    Entry t,
  ) async {
    final palette = this.palette;
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        Widget opt(String label, Duration d) {
          return ListTile(
            dense: true,
            title: Text(label, style: TextStyle(color: palette.fg)),
            onTap: () => Navigator.of(context).pop(d),
          );
        }
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ОТЛОЖИТЬ НА',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              opt('+15 мин', const Duration(minutes: 15)),
              opt('+1 час', const Duration(hours: 1)),
              opt('+1 день', const Duration(days: 1)),
              opt('+3 дня', const Duration(days: 3)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    final base = t.dueAt ?? DateTime.now();
    final next = t.copyWith(
      dueAt: base.add(choice),
      updatedAt: DateTime.now(),
    );
    final repo = await ref.read(repositoryProvider.future);
    await repo.upsertEntry(next);
  }
}

class _CompactTaskRow extends ConsumerWidget {
  const _CompactTaskRow({
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
    final firstAxis =
        task.axisIds.isNotEmpty ? axesById[task.axisIds.first] : null;

    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: task),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            InkWell(
              onTap: () => toggleTaskWithReflection(context, ref, task),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.fg, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title.isEmpty ? '—' : task.title,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.dueAt != null) ...[
              const SizedBox(width: 8),
              Text(
                _shortDue(task.dueAt!),
                style: TextStyle(
                  color: overdue ? palette.fg : palette.muted,
                  fontSize: 11,
                  fontWeight:
                      overdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
            if (firstAxis != null) ...[
              const SizedBox(width: 8),
              Text(firstAxis.symbol,
                  style: TextStyle(color: palette.fg, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactEntryRow extends ConsumerWidget {
  const _CompactEntryRow({
    required this.entry,
    required this.axesById,
    required this.palette,
    this.useCompletedAt = false,
  });

  final Entry entry;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  /// When true (e.g. in the "НЕДАВНО ЗАКРЫТО" strip) the row's subtitle
  /// shows the task's completion time instead of creation time, which
  /// is what the reader actually cares about in that context.
  final bool useCompletedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstAxis =
        entry.axisIds.isNotEmpty ? axesById[entry.axisIds.first] : null;
    final isTask = entry.isTask;
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: entry),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                isTask
                    ? (entry.isCompleted
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank)
                    : Icons.short_text,
                size: 14,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty
                        ? (entry.body.isEmpty ? '—' : bodyToPlainText(entry.body))
                        : entry.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formatTimestamp(useCompletedAt
                        ? (entry.completedAt ?? entry.createdAt)
                        : entry.createdAt),
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (firstAxis != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(firstAxis.symbol,
                    style: TextStyle(color: palette.muted, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

String _shortDue(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final delta = dueDay.difference(today).inDays;
  final hh = due.hour.toString().padLeft(2, '0');
  final mm = due.minute.toString().padLeft(2, '0');
  if (delta == 0) return '$hh:$mm';
  if (delta == 1) return 'завтра $hh:$mm';
  if (delta == -1) return 'вчера $hh:$mm';
  if (delta < 0) return '${-delta}д назад';
  if (delta < 7) return 'через $delta д';
  return '$dueDay'.substring(0, 10);
}

class _AllTasksLink extends StatelessWidget {
  const _AllTasksLink({required this.label, required this.palette});

  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 28),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
        ),
        child: Text(
          '$label →',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
      ),
    );
  }
}

class _WeeklyBanner extends StatelessWidget {
  const _WeeklyBanner({required this.palette, required this.onOpen});

  final NoeticaPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.fg, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, color: palette.fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Прошла неделя',
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Заглянем коротко на пройденное?',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: palette.fg, size: 18),
          ],
        ),
      ),
    );
  }
}

/// First-run dashboard. Replaces the old "Здесь пока пусто" stub which
/// left the user staring at an empty screen with no obvious next step.
/// We now show a personalised greeting + three CTA cards that map 1:1
/// to the most useful first actions: generate a task plan from the
/// onboarding aspiration, explore the pentagon, or jot a free-form
/// note. The cards self-dismiss as soon as the user creates their first
/// entry (this whole widget only renders when `entries.isEmpty`).
class _OnboardingHints extends StatelessWidget {
  const _OnboardingHints({
    required this.palette,
    required this.profile,
    required this.onCreateEntry,
    required this.onOpenRoadmap,
    required this.onOpenKnowledge,
    required this.onOpenSelf,
  });

  final NoeticaPalette palette;
  final UserProfile? profile;
  final VoidCallback onCreateEntry;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenSelf;

  @override
  Widget build(BuildContext context) {
    final aspiration = profile?.aspiration.trim() ?? '';
    final name = profile?.name.trim() ?? '';
    final greeting = name.isEmpty ? 'Привет' : 'Привет, $name';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24 + kFloatingTabBarReserve),
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          aspiration.isEmpty
              ? 'С чего начнём? Выбери действие ниже — это разово, потом дашборд оживёт твоими записями.'
              : 'Готовы помочь с целью «$aspiration». Выбери, с чего начать — карточки исчезнут, как только появятся первые записи.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 22),
        _HintCard(
          palette: palette,
          icon: Icons.auto_awesome,
          accent: const Color(0xFFA78BFA),
          title: 'Сгенерируй план задач',
          subtitle: aspiration.isEmpty
              ? 'AI разложит цель на конкретные задачи, ты выполнишь одну и вечером добавишь рефлексию.'
              : 'AI разложит «$aspiration» на задачи. После выполнения Noetica учтёт рефлексию в следующем плане.',
          ctaLabel: 'Сгенерировать',
          onPressed: onOpenRoadmap,
        ),
        const SizedBox(height: 12),
        _HintCard(
          palette: palette,
          icon: Icons.account_tree_outlined,
          accent: const Color(0xFF60A5FA),
          title: 'Заглянь в базу знаний',
          subtitle:
              'Граф второго мозга: цели, ограничения, рефлексии и заметки. Тапни ветку — отредактируй.',
          ctaLabel: 'Открыть граф',
          onPressed: onOpenKnowledge,
        ),
        const SizedBox(height: 12),
        _HintCard(
          palette: palette,
          icon: Icons.edit_note_outlined,
          accent: const Color(0xFF34D399),
          title: 'Запиши первую заметку',
          subtitle:
              'Лёгкий старт: пара мыслей, наблюдение или идея. Заметку можно потом превратить в задачу.',
          ctaLabel: 'Создать',
          onPressed: onCreateEntry,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onOpenSelf,
            icon: const Icon(Icons.radar_outlined, size: 16),
            label: const Text('Посмотреть свою пентаграмму'),
            style: TextButton.styleFrom(
              foregroundColor: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.palette,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onPressed,
  });

  final NoeticaPalette palette;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.muted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(ctaLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
