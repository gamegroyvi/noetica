import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/generator_manifest.dart';
import '../../theme/app_theme.dart';
import '../home/home_shell.dart' show kFloatingTabBarReserve;

/// "Ассистент" — каталог AI-инструментов, которые умеют генерировать
/// готовые планы (меню, тренировки, учебные курсы, привычки) и
/// импортировать их в обычные Entry-и пользователя.
///
/// Каталог рендерится из `generatorRegistryProvider`: today builtins
/// only, future phases will compose user / marketplace sources without
/// touching this widget.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  /// Set to `false` to hide "Скоро" placeholder cards from the UI.
  /// The underlying manifests and code stay intact — flip back to
  /// `true` when the feature is ready to be surfaced.
  static const _showComingSoon = false;

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
    final soon = _showComingSoon
        ? registry
            .list()
            .where((m) => m.status == GeneratorStatus.soon)
            .toList(growable: false)
        : const <GeneratorManifest>[];
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
                          const SizedBox(height: 28),
                          _SectionLabel(
                            'Доступно',
                            theme: theme,
                            palette: palette,
                          ),
                          const SizedBox(height: 12),
                          _ToolCarousel(
                            tools: available,
                            palette: palette,
                            theme: theme,
                          ),
                        ],
                        if (soon.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _SectionLabel(
                            'Скоро',
                            theme: theme,
                            palette: palette,
                          ),
                          const SizedBox(height: 12),
                          _ToolCarousel(
                            tools: soon,
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

/// Horizontal carousel of tool cards with a page-snap feel.
/// Each card takes ~80 % of the viewport width on phones and a fixed
/// 320 px on wider screens so the user can always peek at the next card.
class _ToolCarousel extends StatefulWidget {
  const _ToolCarousel({
    required this.tools,
    required this.palette,
    required this.theme,
  });

  final List<GeneratorManifest> tools;
  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  State<_ToolCarousel> createState() => _ToolCarouselState();
}

class _ToolCarouselState extends State<_ToolCarousel> {
  late final PageController _ctrl;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = widget.tools;
    if (tools.isEmpty) return const SizedBox.shrink();

    if (tools.length == 1) {
      return _ToolCard(
        tool: tools.first,
        palette: widget.palette,
        theme: widget.theme,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: tools.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              return AnimatedScale(
                scale: i == _current ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _ToolCard(
                    tool: tools[i],
                    palette: widget.palette,
                    theme: widget.theme,
                  ),
                ),
              );
            },
          ),
        ),
        if (tools.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < tools.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _current ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? widget.palette.fg
                        : widget.palette.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
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


