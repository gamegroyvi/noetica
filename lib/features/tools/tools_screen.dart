import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/generator_manifest.dart';
import '../../theme/app_theme.dart';
import '../home/home_shell.dart' show kFloatingTabBarReserve;
import 'runtime/generator_run_screen.dart';

/// "Ассистент" — каталог AI-инструментов, которые умеют генерировать
/// готовые планы (меню, тренировки, учебные курсы, привычки) и
/// импортировать их в обычные Entry-и пользователя.
///
/// Каталог рендерится из `generatorRegistryProvider`: today builtins
/// only, future phases will compose user / marketplace sources without
/// touching this widget.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final registry = ref.watch(generatorRegistryProvider);
    final available = registry
        .list()
        .where((m) => m.status != GeneratorStatus.soon)
        .toList(growable: false);
    final soon = registry
        .list()
        .where((m) => m.status == GeneratorStatus.soon)
        .toList(growable: false);
    // Match HomeShell's `_kRailMin` (720): at/above this the sidebar is
    // visible and the floating tabbar is gone, so we don't need to
    // reserve room for it. Below 720 the capsule overlays the bottom
    // of the viewport and the last card would otherwise hide under it.
    final hasSidebar = width >= 720;
    final bottomReserve = hasSidebar ? 32.0 : kFloatingTabBarReserve + 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ассистент'),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Centered "page" column — on phones it just fills the
            // viewport, on tablets/desktop we cap at 920px so cards
            // don't stretch into something unreadable.
            final maxColumn = constraints.maxWidth.clamp(0, 920).toDouble();
            final horizontal = hasSidebar ? 32.0 : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                16,
                horizontal,
                bottomReserve,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxColumn),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(palette: palette, theme: theme),
                        if (available.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _SectionLabel(
                            'Доступно',
                            theme: theme,
                            palette: palette,
                          ),
                          const SizedBox(height: 12),
                          _ToolGrid(
                            tools: available,
                            isWide: width >= 720,
                            palette: palette,
                            theme: theme,
                          ),
                        ],
                        if (soon.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _SectionLabel(
                            'Скоро',
                            theme: theme,
                            palette: palette,
                          ),
                          const SizedBox(height: 12),
                          _ToolGrid(
                            tools: soon,
                            isWide: width >= 720,
                            palette: palette,
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.theme});

  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: palette.fg,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ассистент',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI собирает готовые планы и раскладывает их по твоим дням, '
            'осям и тегам. Меню на неделю, программа тренировок, учебный '
            'курс — всё попадает в Календарь и Задачи как обычные записи.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.theme, required this.palette});

  final String text;
  final ThemeData theme;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.muted,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.tools,
    required this.isWide,
    required this.palette,
    required this.theme,
  });

  static const double _gap = 12;

  final List<GeneratorManifest> tools;
  final bool isWide;
  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide column count from available width. We don't use the
        // outer screen width because the parent already centers + caps
        // the column at 920px, so the constraint is the truth.
        final columns = _columnsFor(constraints.maxWidth);
        // Group tools into rows of [columns] entries each. The last row
        // gets padded with empty placeholders so card widths stay equal
        // (otherwise a lone card on a half-row would stretch to 100%).
        final rows = <List<GeneratorManifest?>>[];
        for (var i = 0; i < tools.length; i += columns) {
          final row = <GeneratorManifest?>[];
          for (var j = 0; j < columns; j++) {
            row.add(i + j < tools.length ? tools[i + j] : null);
          }
          rows.add(row);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) ...[
              if (rowIdx > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var colIdx = 0; colIdx < columns; colIdx++) ...[
                      if (colIdx > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: rows[rowIdx][colIdx] == null
                            ? const SizedBox.shrink()
                            : _ToolCard(
                                tool: rows[rowIdx][colIdx]!,
                                palette: palette,
                                theme: theme,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  int _columnsFor(double width) {
    // Phones (no sidebar visible) — always single column even if width
    // happens to exceed the breakpoint (e.g. landscape phone).
    if (!isWide) return 1;
    // Tablet/desktop. We could go to 3 columns at very wide layouts but
    // 920px max-column from the parent caps useful width, so 2 is the
    // ceiling here.
    return width >= 560 ? 2 : 1;
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.palette,
    required this.theme,
  });

  final GeneratorManifest tool;
  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final interactable = tool.isInteractable;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: InkWell(
        onTap: () => _onTap(context, interactable),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.line),
                    ),
                    child: Icon(tool.icon, color: palette.fg, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tool.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(status: tool.status, palette: palette),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tool.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                  height: 1.4,
                ),
              ),
              if (tool.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final b in tool.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: palette.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            b,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, bool interactable) {
    if (interactable && tool.builder != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: tool.builder!),
      );
      return;
    }
    if (interactable && tool.hasUniversalRuntime) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GeneratorRunScreen(manifest: tool),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(
          interactable
              ? 'Открываю «${tool.title}»…'
              : 'Скоро: «${tool.title}»',
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.palette});

  final GeneratorStatus status;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      GeneratorStatus.available => (
        'Доступно',
        palette.bg,
        palette.fg,
      ),
      GeneratorStatus.beta => (
        'Beta',
        palette.fg,
        palette.surface,
      ),
      GeneratorStatus.soon => (
        'Скоро',
        palette.muted,
        palette.bg,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}


