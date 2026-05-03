import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../services/pomodoro_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_glyph.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/entry_editor_sheet.dart';
import '../knowledge/knowledge_graph_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../self/self_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import '../tools/tools_screen.dart';
import '../tools/menu/menu_generator_screen.dart';
import '../roadmap/roadmap_screen.dart';

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

/// Geometry of the floating capsule tab bar — exported so screens can
/// add the reserve to their own scroll paddings (so the last items
/// don't end up hidden under the partially-transparent bar).
const double kFloatingTabBarHeight = 52;
const double kFloatingTabBarMargin = 10;
const double kFloatingTabBarHorizontalInset = 16;
/// Side length of the pentagon FAB that sits inline-right of the
/// floating tabbar capsule.
const double kFloatingFabSize = 52;
const double kFloatingFabGap = 10;
/// Total vertical room the bar visually occupies above the system safe
/// area (capsule height + top + bottom margin). Used by screens that
/// build their own ListView padding.
const double kFloatingTabBarReserve =
    kFloatingTabBarHeight + kFloatingTabBarMargin * 2;

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
    final title = wasFocus ? 'Фокус завершён' : 'Отдых завершён';
    final body = wasFocus
        ? (svc.phase == PomodoroPhase.longBreak
            ? 'Время длинного отдыха ${svc.longBreakMinutes} мин — '
                'нажми «Поехали», когда готов.'
            : 'Короткий отдых ${svc.breakMinutes} мин — '
                'нажми «Поехали», когда готов.')
        : 'Следующий фокус ${svc.focusMinutes} мин — '
            'нажми «Поехали», когда готов.';
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
            child: const Text('Стоп'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              PomodoroService.instance.acknowledgePhaseTransition();
            },
            child: const Text('Поехали'),
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
                    _MoreGridItem(
                      icon: Icons.bookmark_border_outlined,
                      label: 'Журнал',
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openJournal();
                      },
                    ),
                    _MoreGridItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Календарь',
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCalendar();
                      },
                    ),
                    _MoreGridItem(
                      icon: Icons.account_tree_outlined,
                      label: 'База',
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
                    _MoreGridItem(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Ассистент',
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
                    _MoreGridItem(
                      icon: Icons.rocket_launch_outlined,
                      label: 'Роадмап',
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
                    _MoreGridItem(
                      icon: Icons.restaurant_menu_outlined,
                      label: 'Меню',
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MenuGeneratorScreen(),
                          ),
                        );
                      },
                    ),
                    _MoreGridItem(
                      icon: Icons.timer_outlined,
                      label: 'Pomodoro',
                      palette: palette,
                      onTap: () {
                        Navigator.pop(ctx);
                        PomodoroSheet.show(context);
                      },
                    ),
                    _MoreGridItem(
                      icon: Icons.settings_outlined,
                      label: 'Настройки',
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

  static const _destinations = <_Destination>[
    _Destination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Сейчас',
    ),
    _Destination(
      icon: Icons.auto_graph_outlined,
      selectedIcon: Icons.auto_graph,
      label: 'Я',
    ),
    _Destination(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Задачи',
    ),
    _Destination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: 'Ещё',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= _kRailMin;

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
                      child: _FloatingTabBar(
                        palette: palette,
                        selectedIndex: mobileSelected,
                        destinations: _destinations,
                        onDestinationSelected: _onMobileTabTap,
                      ),
                    ),
                    const SizedBox(width: kFloatingFabGap),
                    _PentagonFab(
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
          _DesktopSidebar(
            extended: extended,
            destinations: _destinations,
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
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Custom sidebar — `NavigationRail` doesn't support a "secondary" group of
/// non-selectable shortcuts, so we hand-build the layout instead.
class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.extended,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.journalSelected,
    required this.onJournal,
    required this.knowledgeSelected,
    required this.onKnowledge,
    required this.calendarSelected,
    required this.onCalendar,
    required this.toolsSelected,
    required this.onTools,
    required this.settingsSelected,
    required this.onSettings,
    required this.onPomodoro,
    required this.palette,
  });

  final bool extended;
  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAdd;
  final bool journalSelected;
  final VoidCallback onJournal;
  final bool knowledgeSelected;
  final VoidCallback onKnowledge;
  final bool calendarSelected;
  final VoidCallback onCalendar;
  final bool toolsSelected;
  final VoidCallback onTools;
  final bool settingsSelected;
  final VoidCallback onSettings;
  final VoidCallback onPomodoro;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 220.0 : 76.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 0),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const BrandGlyph(size: 28),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Text(
                        'NOETICA',
                        style: TextStyle(
                          color: palette.fg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < destinations.length; i++)
                _SidebarTile(
                  icon: destinations[i].icon,
                  selectedIcon: destinations[i].selectedIcon,
                  label: destinations[i].label,
                  selected: selectedIndex == i &&
                      !journalSelected &&
                      !knowledgeSelected &&
                      !calendarSelected &&
                      !toolsSelected &&
                      !settingsSelected,
                  extended: extended,
                  palette: palette,
                  onTap: () => onDestinationSelected(i),
                ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 0,
                  vertical: 4,
                ),
                child: Divider(color: palette.line, height: 1),
              ),
              _SidebarTile(
                icon: Icons.calendar_month_outlined,
                selectedIcon: Icons.calendar_month,
                label: 'Календарь',
                selected: calendarSelected,
                extended: extended,
                palette: palette,
                onTap: onCalendar,
              ),
              _SidebarTile(
                icon: Icons.bookmark_border_outlined,
                selectedIcon: Icons.bookmark,
                label: 'Журнал',
                selected: journalSelected,
                extended: extended,
                palette: palette,
                onTap: onJournal,
              ),
              _SidebarTile(
                icon: Icons.account_tree_outlined,
                selectedIcon: Icons.account_tree,
                label: 'База знаний',
                selected: knowledgeSelected,
                extended: extended,
                palette: palette,
                onTap: onKnowledge,
              ),
              _SidebarTile(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                label: 'Ассистент',
                selected: toolsSelected,
                extended: extended,
                palette: palette,
                onTap: onTools,
              ),
              _SidebarTile(
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer,
                label: 'Pomodoro',
                selected: false,
                extended: extended,
                palette: palette,
                onTap: onPomodoro,
              ),
              _SidebarTile(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Настройки',
                selected: settingsSelected,
                extended: extended,
                palette: palette,
                onTap: onSettings,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 12,
                  vertical: 12,
                ),
                child: extended
                    ? FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Новая запись'),
                      )
                    : Center(
                        child: FloatingActionButton.small(
                          onPressed: onAdd,
                          child: const Icon(Icons.add),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? palette.fg : palette.muted;
    final bg = selected ? palette.surface : Colors.transparent;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 2),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: selected
              ? BorderSide(color: palette.line)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 12 : 0,
              vertical: extended ? 10 : 12,
            ),
            child: extended
                ? Row(
                    children: [
                      Icon(selected ? selectedIcon : icon, color: fg, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Tooltip(
                      message: label,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        color: fg,
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Telegram-style floating mobile tab bar — capsule shape, fully rounded
/// on both sides, hovers over content with a soft shadow. Outer
/// margins are applied by the parent layout (a Row that places the
/// pentagon FAB inline to the right) — this widget only renders the
/// capsule itself.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.palette,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final NoeticaPalette palette;
  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return PhysicalModel(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
      // Backdrop blur + 72 % opaque surface lets content moving
      // underneath the capsule subtly show through, which is what
      // makes the bar read as "floating" on top instead of "stuck
      // to the bottom".
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: kFloatingTabBarHeight,
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(0.72),
              borderRadius: BorderRadius.circular(kFloatingTabBarHeight / 2),
              border: Border.all(
                color: palette.line.withOpacity(0.55),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _FloatingTabItem(
                      palette: palette,
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-tab item: icon + label. Uses the same Material icons as the
/// desktop sidebar. No InkWell / ripple / hover — the user explicitly
/// asked for a flat hit area, only the active tab is highlighted
/// (via colour + bold label).
class _FloatingTabItem extends StatelessWidget {
  const _FloatingTabItem({
    required this.palette,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NoeticaPalette palette;
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.fg : palette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 1),
            Text(
              destination.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                height: 1.05,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pentagon-shaped FAB that mirrors the Noetica logo glyph. Sits
/// inline to the right of the floating tab bar capsule. No
/// InkWell / ripple — flat tap surface, just an explicit press
/// scale-down for tactile feedback.
class _PentagonFab extends StatefulWidget {
  const _PentagonFab({required this.palette, required this.onTap});

  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  State<_PentagonFab> createState() => _PentagonFabState();
}

class _PentagonFabState extends State<_PentagonFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: kFloatingFabSize,
          height: kFloatingFabSize,
          child: CustomPaint(
            painter: _PentagonPainter(
              fill: widget.palette.fg,
              stroke: widget.palette.line.withOpacity(0.6),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: widget.palette.bg,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a regular pentagon (point-up) with rounded vertices and a
/// soft drop shadow underneath, matching the Noetica brand glyph.
class _PentagonPainter extends CustomPainter {
  _PentagonPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Slightly inset radius so the stroke stays inside the canvas.
    final r = math.min(size.width, size.height) / 2 - 1;
    final path = _pentagonPath(cx, cy, r, cornerRadius: 6);

    // Shadow.
    canvas.drawShadow(path, Colors.black.withOpacity(0.6), 6, false);

    // Fill.
    canvas.drawPath(path, Paint()..color = fill);

    // Subtle border to match the capsule's 1 px line.
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Build a regular pentagon path (one vertex at the top) with
  /// rounded corners. We construct the polygon, then approximate
  /// rounded vertices by inserting two anchor points per corner and
  /// quadratic curves between them.
  Path _pentagonPath(
    double cx,
    double cy,
    double r, {
    double cornerRadius = 0,
  }) {
    final pts = <Offset>[
      for (var i = 0; i < 5; i++)
        Offset(
          cx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / 5),
          cy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / 5),
        ),
    ];

    final path = Path();
    if (cornerRadius <= 0) {
      path.moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      return path;
    }

    for (var i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1 + pts.length) % pts.length];
      final curr = pts[i];
      final next = pts[(i + 1) % pts.length];

      final v1 = curr - prev;
      final v2 = next - curr;
      final l1 = v1.distance;
      final l2 = v2.distance;
      final d1 = math.min(cornerRadius, l1 / 2);
      final d2 = math.min(cornerRadius, l2 / 2);

      final p1 = curr - v1 * (d1 / l1); // entry anchor
      final p2 = curr + v2 * (d2 / l2); // exit anchor

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

class _MoreGridItem extends StatelessWidget {
  const _MoreGridItem({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.fg.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: palette.fg, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
