import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../widgets/brand_glyph.dart';
import '../../services/weekly_reflection_service.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/day_detail_sheet.dart';
import '../entry/entry_editor_sheet.dart';
import '../knowledge/knowledge_graph_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../reflection/reflection_sheet.dart';
import '../reflection/weekly_reflection_sheet.dart';
import '../self/pentagon_painter.dart';
import '../self/self_screen.dart';
import '../tasks/tasks_screen.dart';

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
    this.onOpenJournal,
    this.onOpenCalendar,
  });

  final VoidCallback? onOpenSelf;
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

  void _openJournal() {
    final cb = widget.onOpenJournal;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotesScreen()),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: const Text('Сейчас'),
        actions: [
          if (!isDesktop)
            IconButton(
              tooltip: 'Журнал',
              icon: const Icon(Icons.bookmark_border_outlined),
              onPressed: _openJournal,
            ),
          if (!isDesktop)
            IconButton(
              tooltip: 'База знаний',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KnowledgeGraphScreen(),
                ),
              ),
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
          final axesById = {for (final a in axes) a.id: a};

          if (entries.isEmpty) {
            return _Empty(palette: palette);
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

          final stats = _DashboardStats.from(entries);
          final greeting = _greeting(now, profileAsync.valueOrNull?.name);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
              _PulseSection(
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
              const SizedBox(height: 4),
              Text(
                '${stats.heatmap.fold(0, (a, b) => a + b)} закрыто за 90 дней · тапни день',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _ActivityHeatmap(
                  values: stats.heatmap,
                  palette: palette,
                  onTapDay: (date) => showDayDetailSheet(
                    context,
                    date,
                    onOpenCalendar: _openCalendar,
                  ),
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
                _MiniTreeCard(palette: palette, onTap: _openSelf),
              ],
              const SizedBox(height: 22),
              _SectionHeader(
                label: 'ПОСЛЕДНЕЕ',
                palette: palette,
                trailing: 'журнал →',
                onTrailingTap: _openJournal,
              ),
              const SizedBox(height: 4),
              for (final e in entries.take(4))
                _CompactEntryRow(
                  entry: e,
                  axesById: axesById,
                  palette: palette,
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

String _todaySubtitle(_DashboardStats stats, int overdue, int today) {
  final parts = <String>[];
  if (overdue > 0) {
    parts.add('$overdue ${_plural(overdue, "просрочена", "просрочено", "просрочено")}');
  }
  if (today > 0) parts.add('$today на сегодня');
  if (parts.isEmpty) {
    if (stats.streak > 0) {
      return 'стрик ${stats.streak} ${_plural(stats.streak, "день", "дня", "дней")}';
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => PomodoroSheet.show(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Фокус'),
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
                    onPressed: () =>
                        toggleTaskWithReflection(context, ref, t),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Готово'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: palette.fg,
                      side: BorderSide(color: palette.line),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  });

  final Entry entry;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

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
                        ? (entry.body.isEmpty ? '—' : entry.body)
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
                    formatTimestamp(entry.createdAt),
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

/// "Пульс" block — 4 stat cards summarising key signals. On narrow
/// (mobile) viewports they wrap into a 2×2 grid; on wide (desktop) they
/// span a single 1×4 row. Equal-height tiles via IntrinsicHeight inside
/// each row, so the cards align cleanly regardless of content height.
class _PulseSection extends StatelessWidget {
  const _PulseSection({
    required this.stats,
    required this.axesById,
    required this.palette,
    this.onTapDeadline,
  });

  final _DashboardStats stats;
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
          : _plural(stats.streak, 'день', 'дня', 'дней'),
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
          // Single 1×4 row — all four cards equal height.
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
        // 2×2 grid for mobile/narrow.
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

/// Compact stat card with a big value, an uppercase label, a single
/// hint line, and an optional footer slot. Replaces the old wide
/// `_HeroCard`-with-mismatched-children layout that looked awkward
/// when one card had a sparkline and the other had two-line text.
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
    required this.heatmap,
    required this.totalXpToday,
    required this.totalXpWeek,
    required this.bestAxis,
    required this.bestAxisXp,
    required this.nextDeadline,
  });

  final int streak;
  final int todayCompleted;
  final int weekCompleted;

  /// Last 7 days of completed-task counts (oldest → today).
  final List<int> perDay;

  /// Last 91 days (13 weeks) of completed-task counts, oldest → today.
  /// Used by the GitHub-style activity heatmap.
  final List<int> heatmap;

  final int totalXpToday;
  final int totalXpWeek;

  /// Axis ID with the highest XP earned in the past 7 days, or null when
  /// nothing was completed.
  final String? bestAxis;
  final int bestAxisXp;

  /// Earliest future due date among non-completed tasks, or null.
  final DateTime? nextDeadline;

  factory _DashboardStats.from(List<Entry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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

    const heatmapDays = 91;
    final perDay = List<int>.filled(7, 0);
    final heatmap = List<int>.filled(heatmapDays, 0);
    var totalXpToday = 0;
    var totalXpWeek = 0;
    final perAxisXpWeek = <String, int>{};
    DateTime? nextDeadline;

    for (final e in entries) {
      // Track upcoming deadline among open tasks.
      if (e.isTask && !e.isCompleted && e.dueAt != null && e.dueAt!.isAfter(now)) {
        if (nextDeadline == null || e.dueAt!.isBefore(nextDeadline)) {
          nextDeadline = e.dueAt;
        }
      }
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
      if (diff >= 0 && diff < heatmapDays) {
        heatmap[heatmapDays - 1 - diff] += 1;
      }
      if (diff == 0) totalXpToday += e.xp;
      if (diff >= 0 && diff < 7) {
        totalXpWeek += e.xp;
        // Naive even-split per axis for "best axis this week" display.
        final ids = e.axisIds;
        if (ids.isNotEmpty) {
          final share = e.xp / ids.length;
          for (final id in ids) {
            perAxisXpWeek[id] =
                (perAxisXpWeek[id] ?? 0) + share.round();
          }
        }
      }
    }

    String? bestAxis;
    var bestAxisXp = 0;
    perAxisXpWeek.forEach((k, v) {
      if (v > bestAxisXp) {
        bestAxis = k;
        bestAxisXp = v;
      }
    });

    return _DashboardStats(
      streak: streak,
      todayCompleted: perDay[6],
      weekCompleted: perDay.fold(0, (a, b) => a + b),
      perDay: perDay,
      heatmap: heatmap,
      totalXpToday: totalXpToday,
      totalXpWeek: totalXpWeek,
      bestAxis: bestAxis,
      bestAxisXp: bestAxisXp,
      nextDeadline: nextDeadline,
    );
  }
}

/// GitHub-style activity heatmap.
///
/// Layout matches GitHub closely: weekday labels on the left (Пн, Ср, Пт),
/// month labels on top, columns are weeks, rows are days. Cell size caps
/// at 14 px so on desktop the grid doesn't sprawl across the whole width.
/// Bottom legend shows colour scale "меньше → больше" with 5 buckets.
class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({
    required this.values,
    required this.palette,
    this.onTapDay,
  });

  /// Day-of-completion counts, oldest first, length = 91 (13 weeks × 7).
  final List<int> values;
  final NoeticaPalette palette;

  /// Tapped-day callback (date is midnight-aligned). Also receives hover
  /// events via the cell's Tooltip on desktop. When null, cells are
  /// non-interactive.
  final ValueChanged<DateTime>? onTapDay;

  static const _weekdayLabels = ['Пн', '', 'Ср', '', 'Пт', '', ''];
  static const _monthLabels = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, (a, b) => b > a ? b : a);
    const rows = 7;
    const spacing = 3.0;
    const labelGutter = 28.0;

    // We want a true GitHub-style layout where row 0 = Monday and the
    // rightmost column = the current calendar week, with today landing
    // in its actual weekday row. Anchor everything to a Monday so the
    // weekday label rail is correct.
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    // weekday: 1=Mon..7=Sun → 0..6 offset from Monday-of-this-week.
    final mondayThisWeek = todayD.subtract(Duration(days: todayD.weekday - 1));
    final cols = (values.length / rows).ceil();
    final mondayFirstCol =
        mondayThisWeek.subtract(Duration(days: (cols - 1) * 7));
    // Window of dates we actually have data for (last 91 days, today
    // inclusive). Cells outside this window are rendered blank.
    final windowStart = todayD.subtract(Duration(days: values.length - 1));

    // Map column → first month label visible for that column. Now keyed
    // off `mondayFirstCol`, so labels actually line up with the calendar.
    final monthMarkers = <int, String>{};
    int? lastMonth;
    for (var c = 0; c < cols; c++) {
      final colStart = mondayFirstCol.add(Duration(days: c * 7));
      if (lastMonth != colStart.month) {
        monthMarkers[c] = _monthLabels[colStart.month - 1];
        lastMonth = colStart.month;
      }
    }

    // For a given (col, row) compute (a) the date that cell represents
    // and (b) the count, indexing into `values` chronologically. Cells
    // before the data window or after today are rendered blank.
    ({DateTime date, int? value}) cellInfo(int c, int r) {
      final date = mondayFirstCol.add(Duration(days: c * 7 + r));
      if (date.isBefore(windowStart) || date.isAfter(todayD)) {
        return (date: date, value: null);
      }
      final idx = date.difference(windowStart).inDays;
      if (idx < 0 || idx >= values.length) return (date: date, value: null);
      return (date: date, value: values[idx]);
    }

    String monthName(int m) => _monthLabels[m - 1];

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - labelGutter;
        final raw = (available - (cols - 1) * spacing) / cols;
        final cell = raw.clamp(8.0, 14.0).toDouble();
        final gridWidth = cols * cell + (cols - 1) * spacing;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month labels row.
            SizedBox(
              height: 14,
              child: Row(
                children: [
                  const SizedBox(width: labelGutter),
                  SizedBox(
                    width: gridWidth,
                    child: Stack(
                      children: [
                        for (final entry in monthMarkers.entries)
                          Positioned(
                            left: entry.key * (cell + spacing),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day-of-week labels.
                SizedBox(
                  width: labelGutter,
                  child: Column(
                    children: [
                      for (var r = 0; r < rows; r++) ...[
                        SizedBox(
                          height: cell,
                          child: Text(
                            _weekdayLabels[r],
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (r < rows - 1) const SizedBox(height: spacing),
                      ],
                    ],
                  ),
                ),
                // The grid itself.
                SizedBox(
                  width: gridWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        Column(
                          children: [
                            for (var r = 0; r < rows; r++) ...[
                              _buildCell(
                                cellInfo(c, r),
                                cell,
                                maxV,
                                monthName,
                              ),
                              if (r < rows - 1)
                                const SizedBox(height: spacing),
                            ],
                          ],
                        ),
                        if (c < cols - 1) const SizedBox(width: spacing),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bottom legend.
            Padding(
              padding: const EdgeInsets.only(left: labelGutter),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('меньше',
                      style: TextStyle(color: palette.muted, fontSize: 10)),
                  const SizedBox(width: 6),
                  for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _bucketColor(t),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  const SizedBox(width: 3),
                  Text('больше',
                      style: TextStyle(color: palette.muted, fontSize: 10)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCell(
    ({DateTime date, int? value}) info,
    double size,
    int maxV,
    String Function(int) monthName,
  ) {
    final value = info.value;
    if (value == null) {
      // Out-of-window cell — completely transparent so the grid keeps
      // its rectangular shape but the user sees we have no data there.
      return SizedBox(width: size, height: size);
    }
    final t = maxV == 0 ? 0.0 : (value / maxV);
    final color =
        value == 0 ? palette.line.withOpacity(0.35) : _bucketColor(t);
    final label = value == 0
        ? '${info.date.day} ${monthName(info.date.month)} · ничего'
        : '${info.date.day} ${monthName(info.date.month)} · '
            '$value ${_plural(value, "задача", "задачи", "задач")}';
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    final tooltipped = Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 250),
      child: cell,
    );
    if (onTapDay == null) return tooltipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapDay!(info.date),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: tooltipped,
      ),
    );
  }

  Color _bucketColor(double t) {
    if (t <= 0.001) return palette.line.withOpacity(0.35);
    if (t < 0.34) return palette.fg.withOpacity(0.28);
    if (t < 0.67) return palette.fg.withOpacity(0.55);
    if (t < 0.99) return palette.fg.withOpacity(0.80);
    return palette.fg;
  }
}

/// Compact tappable Древо preview — small radar polygon plus axis-symbol
/// strip and a hint. Animates entrance like the full one and routes to
/// SelfScreen on tap.
class _MiniTreeCard extends ConsumerWidget {
  const _MiniTreeCard({required this.palette, this.onTap});

  final NoeticaPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(scoresProvider);
    final levelStatsAsync = ref.watch(axisLevelStatsProvider);
    return InkWell(
      onTap: onTap ??
          () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SelfScreen()),
              ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: scoresAsync.when(
          loading: () => const SizedBox(height: 90),
          error: (_, __) => const SizedBox(height: 0),
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
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${scores.length} ветвей · L$topLevel ${topAxis.axis.name.toLowerCase()}',
                        style: TextStyle(
                          color: palette.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scores
                            .map((s) =>
                                '${s.axis.symbol} ${s.value.round()}')
                            .join('  '),
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontFamily: 'IBMPlexMono',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'тап — посмотреть полностью',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
