import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/brand_glyph.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/entry_editor_sheet.dart';
import '../knowledge/knowledge_graph_screen.dart';
import '../notes/notes_screen.dart';
import '../pomodoro/pomodoro_sheet.dart';
import '../self/self_screen.dart';
import '../tasks/tasks_screen.dart';

/// Layout breakpoints. Below `_kRailMin`: bottom navigation bar. Between
/// `_kRailMin` and `_kRailExtended`: compact NavigationRail (icons only).
/// At/above `_kRailExtended`: extended NavigationRail with text labels.
const double _kRailMin = 900;
const double _kRailExtended = 1200;

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // Page indices for "secondary" desktop-only sidebar entries — the
  // mobile NavigationBar still only shows the primary 3, but desktop
  // can navigate to these as proper tabs (no push, sidebar stays).
  static const _selfIndex = 2;
  static const _journalIndex = 3;
  static const _knowledgeIndex = 4;
  static const _calendarIndex = 5;

  // Pages must be built lazily so the dashboard can receive callbacks
  // bound to *this* state instance (`setState`).
  //
  // `onOpenSelf` always switches to the "Я" tab — it's available in both
  // desktop sidebar and mobile bottom-nav, so a tab switch is always the
  // right behaviour (sidebar/bottom-bar stays visible).
  //
  // `onOpenJournal` switches to the journal tab on desktop (where the
  // sidebar shows it). On mobile, where the bottom-nav has no journal
  // entry, it pushes a route so the user gets a proper back button.
  late final List<Widget> _pages = [
    DashboardScreen(
      onOpenSelf: () => setState(() => _index = _selfIndex),
      onOpenJournal: _openJournal,
      onOpenCalendar: _openCalendar,
    ),
    const TasksScreen(),
    const SelfScreen(),
    const NotesScreen(),
    const KnowledgeGraphScreen(),
    const CalendarScreen(),
  ];

  void _openJournal() {
    final wide = MediaQuery.of(context).size.width >= _kRailMin;
    if (wide) {
      setState(() => _index = _journalIndex);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotesScreen()),
      );
    }
  }

  void _openCalendar() {
    final wide = MediaQuery.of(context).size.width >= _kRailMin;
    if (wide) {
      setState(() => _index = _calendarIndex);
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
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Задачи',
    ),
    _Destination(
      icon: Icons.auto_graph_outlined,
      selectedIcon: Icons.auto_graph,
      label: 'Я',
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
      final mobileSelected = _index < _destinations.length ? _index : 0;
      return Scaffold(
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: () => showEntryEditor(context, ref),
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: NavigationBar(
            selectedIndex: mobileSelected,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
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
            onDestinationSelected: (i) => setState(() => _index = i),
            onAdd: () => showEntryEditor(context, ref),
            journalSelected: _index == _journalIndex,
            onJournal: () => setState(() => _index = _journalIndex),
            knowledgeSelected: _index == _knowledgeIndex,
            calendarSelected: _index == _calendarIndex,
            onCalendar: () => setState(() => _index = _calendarIndex),
            // Knowledge graph used to push a new route, which hid the
            // sidebar and trapped the user (no back button on the
            // graph screen). It's now a proper sidebar tab — selects
            // page index 4 in the IndexedStack, sidebar stays visible.
            onKnowledge: () => setState(() => _index = _knowledgeIndex),
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
                      !calendarSelected,
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
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer,
                label: 'Pomodoro',
                selected: false,
                extended: extended,
                palette: palette,
                onTap: onPomodoro,
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
