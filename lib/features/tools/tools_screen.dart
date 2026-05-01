import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../home/home_shell.dart' show kFloatingTabBarReserve;
import 'menu/menu_generator_screen.dart';

/// "Ассистент" — каталог AI-инструментов, которые умеют генерировать
/// готовые планы (меню, тренировки, учебные курсы, привычки) и
/// импортировать их в обычные Entry-и пользователя.
///
/// PR-1 кладёт сюда только UI-каркас: каждая карточка — `_ToolDescriptor`
/// со статусом «В разработке». Когда соответствующий бэкенд-эндпоинт
/// готов, статус карточки меняется на `available` и тап открывает
/// генератор. Это даёт юзеру видимый "магазин" будущих фич без
/// преждевременного кода для самих генераций.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
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
                        const SizedBox(height: 24),
                        _SectionLabel(
                          'Доступно',
                          theme: theme,
                          palette: palette,
                        ),
                        const SizedBox(height: 12),
                        _ToolGrid(
                          tools: _tools.where((t) => t.status != _ToolStatus.soon).toList(),
                          isWide: width >= 720,
                          palette: palette,
                          theme: theme,
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel(
                          'Скоро',
                          theme: theme,
                          palette: palette,
                        ),
                        const SizedBox(height: 12),
                        _ToolGrid(
                          tools: _tools.where((t) => t.status == _ToolStatus.soon).toList(),
                          isWide: width >= 720,
                          palette: palette,
                          theme: theme,
                        ),
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

  final List<_ToolDescriptor> tools;
  final bool isWide;
  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      // Phone: single column, cards stack vertically.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tools) ...[
            _ToolCard(tool: t, palette: palette, theme: theme),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    // Tablet/desktop: 2 columns. We wrap so cards reflow at narrow
    // widths (e.g. 720–800px) and grow to fill 50% otherwise.
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final t in tools)
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 280,
              maxWidth: 440,
            ),
            child: SizedBox(
              width: 440,
              child: _ToolCard(tool: t, palette: palette, theme: theme),
            ),
          ),
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

  final _ToolDescriptor tool;
  final NoeticaPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final available = tool.status == _ToolStatus.available;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: InkWell(
        onTap: () => _onTap(context, available),
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

  void _onTap(BuildContext context, bool available) {
    if (available && tool.builder != null) {
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
          available
              ? 'Открываю «${tool.title}»…'
              : 'Скоро: «${tool.title}»',
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.palette});

  final _ToolStatus status;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      _ToolStatus.available => (
        'Доступно',
        palette.bg,
        palette.fg,
      ),
      _ToolStatus.beta => (
        'Beta',
        palette.fg,
        palette.surface,
      ),
      _ToolStatus.soon => (
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

enum _ToolStatus { available, beta, soon }

class _ToolDescriptor {
  const _ToolDescriptor({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.bullets = const [],
    this.builder,
  });

  final IconData icon;
  final String title;
  final String description;
  final _ToolStatus status;
  final List<String> bullets;

  /// When [status] is [_ToolStatus.available], this is the builder
  /// pushed onto the navigator on tap. `null` for tools that are
  /// available but routed elsewhere; `null` for `soon` cards.
  final WidgetBuilder? builder;
}

Widget _menuBuilder(BuildContext _) => const MenuGeneratorScreen();

final List<_ToolDescriptor> _tools = [
  const _ToolDescriptor(
    icon: Icons.restaurant_menu_outlined,
    title: 'Меню недели',
    description:
        '7 дней × завтрак / обед / ужин с КБЖУ под твою цель питания.',
    status: _ToolStatus.available,
    bullets: [
      '21 задача на оси «Тело» с дедлайнами',
      'Список покупок отдельной заметкой-чеклистом',
      'Полные рецепты подгружаются по тапу',
    ],
    builder: _menuBuilder,
  ),
  const _ToolDescriptor(
    icon: Icons.fitness_center_outlined,
    title: 'План тренировок',
    description:
        'Программа на 4 недели под цель: сила, выносливость, рекомпозиция.',
    status: _ToolStatus.soon,
    bullets: [
      'Учитывает доступное оборудование',
      'Каждое занятие — задача с подходами в подзадачах',
    ],
  ),
  const _ToolDescriptor(
    icon: Icons.menu_book_outlined,
    title: 'Учебный план',
    description:
        'Декомпозиция «выучить X» на занятия с заметками-конспектами.',
    status: _ToolStatus.soon,
    bullets: [
      'Уроки = задачи на оси «Разум»',
      'Конспекты — заметки, связанные [[wiki-ссылками]]',
    ],
  ),
  const _ToolDescriptor(
    icon: Icons.eco_outlined,
    title: 'Микро-привычки',
    description:
        '7-дневный челлендж из коротких ежедневных задач.',
    status: _ToolStatus.soon,
    bullets: [
      'Подбираем под выбранную ось',
      'Серии и стрик-счётчик из коробки',
    ],
  ),
];
