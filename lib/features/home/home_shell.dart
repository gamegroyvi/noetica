import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/notifications.dart';
import '../../services/pomodoro_service.dart';
import '../../services/weekly_reflection_service.dart';
import '../../theme/app_theme.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/entry_editor_sheet.dart';
import '../knowledge/knowledge_graph_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../self/self_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import '../coach/coach_screen.dart';
import '../tools/tools_screen.dart';
import '../roadmap/roadmap_screen.dart';
import 'widgets/shell_widgets.dart';
export 'widgets/shell_widgets.dart' show
    kFloatingTabBarHeight,
    kFloatingTabBarMargin,
    kFloatingTabBarHorizontalInset,
    kFloatingFabSize,
    kFloatingFabGap,
    kFloatingTabBarReserve;

/// Layout breakpoints. Below `_kRailMin`: bottom navigation bar. Between
/// `_kRailMin` and `_kRailExtended`: compact NavigationRail (icons only).
/// At/above `_kRailExtended`: extended NavigationRail with text labels.
///
/// `_kRailMin` was bumped from 900 → 720 so tablets and the smaller
/// foldable form factors get a real sidebar instead of the cramped
/// floating tab bar (which collides with our wider editor sheet at
/// those widths).
const double _kRailMin = 720;
const double _kRailExtended = 1100;


class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    PomodoroService.instance.addListener(_onPomodoroChanged);
  }

  @override
  void dispose() {
    PomodoroService.instance.removeListener(_onPomodoroChanged);
    super.dispose();
  }

  void _onPomodoroChanged() {
    final svc = PomodoroService.instance;
    if (!mounted) return;
    if (svc.awaitingDismissal && !_alertOpen) {
      _alertOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPomodoroDismissDialog();
      });
    }
  }

  Future<void> _showPomodoroDismissDialog() async {
    final svc = PomodoroService.instance;
    final justDone = svc.justCompleted;
    final wasFocus = justDone == PomodoroPhase.focus;
    final tr = S.of(context)!;
    final title = wasFocus ? tr.pomodoroFocusDone : tr.pomodoroBreakDone;
    final body = wasFocus
        ? (svc.phase == PomodoroPhase.longBreak
            ? tr.pomodoroLongBreakBody(svc.longBreakMinutes)
            : tr.pomodoroShortBreakBody(svc.breakMinutes))
        : tr.pomodoroNextFocusBody(svc.focusMinutes);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PomodoroService.instance.stop();
            },
            child: Text(S.of(ctx)!.pomodoroStopAction),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PomodoroService.instance.acknowledgePhaseTransition();
            },
            child: Text(S.of(ctx)!.pomodoroGoAction),
          ),
        ],
      ),
    );
    _alertOpen = false;
  }

  // Page indices. The first three are primary tabs (visible in the
  // mobile bottom bar). The rest are "secondary" desktop-only entries
  // reached from the sidebar; on mobile they push onto the navigator.
  //
  // Mobile tab order: Dashboard → Я → Задачи. The Себя sits between
  // dashboard and tasks because the user wants quick access to their
  // Древо from the home screen.
  static const _selfIndex = 1;
  static const _tasksIndex = 2;
  static const _journalIndex = 3;
  static const _knowledgeIndex = 4;
  static const _calendarIndex = 5;
  static const _toolsIndex = 6;
  static const _settingsIndex = 7;
  static const _moreTabIndex = 3; // "Ещё" tab in the floating bar

  static const _screenNames = [
    'dashboard', 'self', 'tasks', 'journal',
    'knowledge', 'calendar', 'tools', 'settings',
  ];

  void _switchTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    AnalyticsService.instance.track(AnalyticsEvents.screenViewed, {
      'screen': _screenNames[i],
    });
  }

  void _onMobileTabTap(int i) {
    if (i == _moreTabIndex) {
      _showMoreSheet();
      return;
    }
    _switchTab(i);
  }

  void _showMoreSheet() {
    final palette = context.palette;
    final tr = S.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: palette.muted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    MoreGridItem(
                      icon: Icons.psychology_outlined,
                      label: tr.navCoach,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CoachScreen(),
                          ),
                        );
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.bookmark_border_outlined,
                      label: tr.navJournal,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openJournal();
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.calendar_today_outlined,
                      label: tr.navCalendar,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCalendar();
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.account_tree_outlined,
                      label: tr.navKnowledge,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const KnowledgeGraphScreen(),
                          ),
                        );
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.auto_awesome_outlined,
                      label: tr.navAssistant,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ToolsScreen(),
                          ),
                        );
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.rocket_launch_outlined,
                      label: tr.navRoadmap,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RoadmapScreen(),
                          ),
                        );
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.timer_outlined,
                      label: tr.pomodoroTitle,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        PomodoroSheet.show(context);
                      },
                    ),
                    MoreGridItem(
                      icon: Icons.settings_outlined,
                      label: tr.navSettings,
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pages must be built lazily so the dashboard can receive callbacks
  // bound to *this* state instance (`setState`).
  //
  // `onOpenSelf` / `onOpenTasks` always switch tabs — they exist in
  // both desktop sidebar and mobile bottom-nav, so a tab switch is the
  // correct behaviour everywhere (nav stays visible).
  //
  // `onOpenJournal` / `onOpenCalendar` switch the desktop tab when the
  // sidebar is present; on mobile (where the bottom-nav has no journal
  // or calendar entry) they push a route with a real back button.
  late final List<Widget> _pages = [
    DashboardScreen(
      onOpenSelf: () => _switchTab(_selfIndex),
      onOpenTasks: () => _switchTab(_tasksIndex),
      onOpenJournal: _openJournal,
      onOpenCalendar: _openCalendar,
    ),
    const SelfScreen(),
    const TasksScreen(),
    const NotesScreen(),
    const KnowledgeGraphScreen(),
    const CalendarScreen(),
    const ToolsScreen(),
    const SettingsScreen(),
  ];

  void _openJournal() {
    final wide = MediaQuery.of(context).size.width >= _kRailMin;
    if (wide) {
      _switchTab(_journalIndex);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotesScreen()),
      );
    }
  }

  void _openCalendar() {
    final wide = MediaQuery.of(context).size.width >= _kRailMin;
    if (wide) {
      _switchTab(_calendarIndex);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
      );
    }
  }

  static List<ShellDestination> _destinations(S tr) => <ShellDestination>[
    ShellDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: tr.tabDashboard,
    ),
    ShellDestination(
      icon: Icons.auto_graph_outlined,
      selectedIcon: Icons.auto_graph,
      label: tr.tabSelf,
    ),
    ShellDestination(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: tr.tabTasks,
    ),
    ShellDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: tr.tabMore,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tr = S.of(context)!;
    PomodoroService.instance.updateLocale(tr);
    NotificationsService.instance.updateLocale(tr);
    WeeklyReflectionService.instance.updateLocale(tr);
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= _kRailMin;
    final destinations = _destinations(tr);

    final body = IndexedStack(index: _index, children: _pages);

    if (!useRail) {
      // On mobile the bottom bar shows only the first 3 destinations;
      // Journal stays accessible via the AppBar bookmark icon. We clamp
      // the bar's selectedIndex so it doesn't break when index = 3 (would
      // happen if user navigated to journal then resized to mobile).
      // Clamp to the first 3 real tabs; "Ещё" (index 3) is a menu trigger,
      // not a real page — never show it as selected.
      final mobileSelected = _index < _moreTabIndex ? _index : 0;
      final bottomSafe = MediaQuery.of(context).padding.bottom;
      // Telegram-style truly-floating capsule: drop the bottomNavigationBar
      // slot (which forced Scaffold to reserve a strip and made the bar
      // sit *inside* a non-floating box) and instead overlay it via a
      // Stack at the screen level. The body fills the entire screen,
      // but we inject MediaQuery.padding.bottom += reserve so SafeArea
      // and other padding-aware widgets in pages know to leave room
      // under the capsule. The FAB is also Stack-positioned so it
      // sits a comfortable margin *above* the capsule and never lands
      // on top of page content like «Сгенерировать план».
      final body3 = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.of(context).padding.copyWith(
                bottom:
                    MediaQuery.of(context).padding.bottom + kFloatingTabBarReserve,
              ),
        ),
        child: body,
      );
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: body3),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  kFloatingTabBarHorizontalInset,
                  kFloatingTabBarMargin,
                  kFloatingTabBarHorizontalInset,
                  kFloatingTabBarMargin + bottomSafe,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FloatingTabBar(
                        palette: palette,
                        selectedIndex: mobileSelected,
                        destinations: destinations,
                        onDestinationSelected: _onMobileTabTap,
                      ),
                    ),
                    const SizedBox(width: kFloatingFabGap),
                    PentagonFab(
                      palette: palette,
                      onTap: () => showEntryEditor(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final extended = width >= _kRailExtended;
    return Scaffold(
      body: Row(
        children: [
          DesktopSidebar(
            extended: extended,
            destinations: destinations,
            selectedIndex: _index,
            onDestinationSelected: _switchTab,
            onAdd: () => showEntryEditor(context, ref),
            journalSelected: _index == _journalIndex,
            onJournal: () => _switchTab(_journalIndex),
            knowledgeSelected: _index == _knowledgeIndex,
            calendarSelected: _index == _calendarIndex,
            onCalendar: () => _switchTab(_calendarIndex),
            toolsSelected: _index == _toolsIndex,
            onTools: () => _switchTab(_toolsIndex),
            onKnowledge: () => _switchTab(_knowledgeIndex),
            settingsSelected: _index == _settingsIndex,
            onSettings: () => _switchTab(_settingsIndex),
            onPomodoro: () => PomodoroSheet.show(context),
            palette: palette,
            moreTabIndex: _moreTabIndex,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

