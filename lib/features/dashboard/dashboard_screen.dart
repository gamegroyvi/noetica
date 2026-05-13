import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_glyph.dart';
import '../../services/weekly_reflection_service.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/day_detail_sheet.dart';
import '../entry/entry_editor_sheet.dart';
import '../home/home_shell.dart';
import '../knowledge/knowledge_graph_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../reflection/weekly_reflection_sheet.dart';
import '../roadmap/roadmap_screen.dart';
import '../self/self_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/dashboard_stats.dart';
import 'widgets/mini_tree_card.dart';
import 'widgets/dashboard_cards.dart';
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

  // ignore: unused_element
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

  // ignore: unused_element
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
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
    final tr = S.of(context)!;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final profileAsync = ref.watch(profileProvider);
    // ignore: unused_local_variable
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: Text(tr.tabDashboard),
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
            return OnboardingHints(
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
          final greeting = _greeting(now, profileAsync.valueOrNull?.name, tr);

          return ListView(
            // Reserve space for the floating capsule + FAB hovering above it.
            padding: const
                EdgeInsets.fromLTRB(16, 8, 16, 24 + kFloatingTabBarReserve),
            children: [
              if (_showWeeklyBanner) ...[
                WeeklyBanner(
                  palette: palette,
                  onOpen: _openWeeklyReflection,
                ),
                const SizedBox(height: 14),
              ],
              DashGreeting(
                title: greeting,
                subtitle: _todaySubtitle(stats, overdue.length, dueToday.length, tr),
                palette: palette,
              ),
              const SizedBox(height: 18),
              DashSectionHeader(label: tr.sectionNow, palette: palette),
              const SizedBox(height: 8),
              NowFocusCard(
                task: focus,
                axesById: axesById,
                palette: palette,
              ),
              if (todayList.isNotEmpty) ...[
                const SizedBox(height: 22),
                DashSectionHeader(
                  label: tr.sectionToday,
                  palette: palette,
                  trailing: '${todayList.length}',
                ),
                const SizedBox(height: 4),
                for (final t in todayList.take(6))
                  CompactTaskRow(
                    task: t,
                    axesById: axesById,
                    palette: palette,
                  ),
                if (todayList.length > 6)
                  AllTasksLink(
                    label: '+${todayList.length - 6}',
                    palette: palette,
                  ),
              ],
              const SizedBox(height: 22),
              DashSectionHeader(label: tr.sectionPulse, palette: palette),
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
              DashSectionHeader(
                label: tr.sectionHeatmap,
                palette: palette,
                trailing: tr.linkCalendar,
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
                DashSectionHeader(
                  label: tr.sectionTree,
                  palette: palette,
                  trailing: tr.linkAll,
                  onTrailingTap: _openSelf,
                ),
                const SizedBox(height: 8),
                MiniTreeCard(palette: palette, onTap: _openSelf),
              ],
              const SizedBox(height: 22),
              DashSectionHeader(
                // Previously this block was labelled "ПОСЛЕДНЕЕ" and routed
                // to the journal, but the journal is for notes only —
                // jumping there from a list of mixed entries felt broken.
                // The dashboard's own "СЕГОДНЯ" block already covers tasks
                // due today; this tail strip now shows the last few
                // closed tasks and links to the full Tasks tab.
                label: tr.sectionRecentlyClosed,
                palette: palette,
                trailing: tr.linkTasks,
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
                CompactEntryRow(
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

String _greeting(DateTime now, String? name, S tr) {
  final h = now.hour;
  final base = h < 5
      ? tr.greetingNight
      : (h < 12 ? tr.greetingMorning : (h < 18 ? tr.greetingDay : tr.greetingEvening));
  if (name == null || name.trim().isEmpty) return base;
  return '$base, ${name.trim().split(' ').first}';
}

String _todaySubtitle(DashboardStats stats, int overdue, int today, S tr) {
  final parts = <String>[];
  if (overdue > 0) {
    parts.add(tr.dashboardOverdueCount(overdue));
  }
  if (today > 0) parts.add(tr.dashboardTodayCount(today));
  if (parts.isEmpty) {
    if (stats.streak > 0) {
      return tr.daysTotalStreak(stats.streak);
    }
    return tr.freeDay;
  }
  return parts.join(' · ');
}

