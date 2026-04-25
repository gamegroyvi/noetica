import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/entry_editor_sheet.dart';
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

  static const _pages = <Widget>[
    DashboardScreen(),
    TasksScreen(),
    SelfScreen(),
  ];

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
            selectedIndex: _index,
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
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: palette.line)),
            ),
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 200,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: extended
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'NOETICA',
                          style: TextStyle(
                            color: palette.fg,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      )
                    : Icon(Icons.change_history, color: palette.fg),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton.small(
                      onPressed: () => showEntryEditor(context, ref),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
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
