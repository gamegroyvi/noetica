import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/entry_editor_sheet.dart';
import '../notes/notes_screen.dart';
import '../self/self_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const pages = [
      DashboardScreen(),
      SelfScreen(),
      NotesScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Сейчас',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_graph_outlined),
              selectedIcon: Icon(Icons.auto_graph),
              label: 'Я',
            ),
            NavigationDestination(
              icon: Icon(Icons.notes_outlined),
              selectedIcon: Icon(Icons.notes),
              label: 'Заметки',
            ),
          ],
        ),
      ),
    );
  }
}
