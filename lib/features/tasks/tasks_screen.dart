import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/subtask_utils.dart';
import '../../utils/time_utils.dart';
import '../../widgets/brand_glyph.dart';
import '../entry/entry_editor_sheet.dart';
import '../reflection/reflection_sheet.dart';
import '../settings/settings_screen.dart';

/// Status filter applied to the visible task list.
enum _StatusFilter { all, open, overdue, done }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.all => 'Все',
        _StatusFilter.open => 'Открытые',
        _StatusFilter.overdue => 'Просрочены',
        _StatusFilter.done => 'Готово',
      };

  bool matches(Entry e) {
    switch (this) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.open:
        return !e.isCompleted;
      case _StatusFilter.done:
        return e.isCompleted;
      case _StatusFilter.overdue:
        return !e.isCompleted &&
            e.dueAt != null &&
            e.dueAt!.isBefore(DateTime.now());
    }
  }
}

/// Sort order applied after filtering.
enum _SortMode { smart, dueAsc, createdDesc, xpDesc }

extension on _SortMode {
  String get label => switch (this) {
        _SortMode.smart => 'Умная',
        _SortMode.dueAsc => 'Срок ↑',
        _SortMode.createdDesc => 'Свежие',
        _SortMode.xpDesc => 'Тяжёлые сверху',
      };
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _StatusFilter _status = _StatusFilter.open;
  _SortMode _sort = _SortMode.smart;
  String? _axisFilterId; // null = all axes

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: BrandGlyph(size: 24),
        ),
        leadingWidth: 48,
        title: const Text('Задачи'),
        actions: [
          PopupMenuButton<_SortMode>(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => [
              for (final m in _SortMode.values)
                CheckedPopupMenuItem(
                  value: m,
                  checked: m == _sort,
                  child: Text(m.label),
                ),
            ],
          ),
          if (isMobile)
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          final axes = axesAsync.valueOrNull ?? const [];
          final axesById = {for (final a in axes) a.id: a};
          // Drop the axis filter if the chosen axis was deleted.
          if (_axisFilterId != null && !axesById.containsKey(_axisFilterId)) {
            _axisFilterId = null;
          }

          final filtered = entries.where((e) => e.isTask).where((e) {
            if (!_status.matches(e)) return false;
            if (_axisFilterId != null && !e.axisIds.contains(_axisFilterId)) {
              return false;
            }
            return true;
          }).toList();

          filtered.sort(_compareTasks);

          return Column(
            children: [
              _FilterBar(
                status: _status,
                onStatus: (s) => setState(() => _status = s),
                axes: axes,
                axisId: _axisFilterId,
                onAxis: (id) => setState(() => _axisFilterId = id),
                palette: palette,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        hasAnyTasks:
                            entries.where((e) => e.isTask).isNotEmpty,
                        palette: palette,
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _TaskTile(task: filtered[i], axesById: axesById),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _compareTasks(Entry a, Entry b) {
    switch (_sort) {
      case _SortMode.smart:
        // Active first (by due asc, then subtask-bearing, then created
        // desc), then completed. Subtask-bearing tasks are lifted above
        // plain ones: they've usually been planned explicitly by the
        // roadmap LLM and are more actionable.
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (!a.isCompleted) {
          final ad = a.dueAt;
          final bd = b.dueAt;
          if (ad == null && bd != null) return 1;
          if (ad != null && bd == null) return -1;
          if (ad != null && bd != null) {
            final c = ad.compareTo(bd);
            if (c != 0) return c;
          }
          final aHas = hasSubtasks(a.body);
          final bHas = hasSubtasks(b.body);
          if (aHas != bHas) return aHas ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        }
        return (b.completedAt ?? b.updatedAt)
            .compareTo(a.completedAt ?? a.updatedAt);
      case _SortMode.dueAsc:
        final ad = a.dueAt;
        final bd = b.dueAt;
        if (ad == null && bd == null) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      case _SortMode.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case _SortMode.xpDesc:
        final cmp = b.xp.compareTo(a.xp);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.onStatus,
    required this.axes,
    required this.axisId,
    required this.onAxis,
    required this.palette,
  });

  final _StatusFilter status;
  final ValueChanged<_StatusFilter> onStatus;
  final List<LifeAxis> axes;
  final String? axisId;
  final ValueChanged<String?> onAxis;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final s in _StatusFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: s == status,
                  onSelected: (_) => onStatus(s),
                ),
              ),
            if (axes.isNotEmpty) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: palette.line,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Все оси'),
                  selected: axisId == null,
                  onSelected: (_) => onAxis(null),
                ),
              ),
              for (final a in axes)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${a.symbol}  ${a.name}'),
                    selected: axisId == a.id,
                    onSelected: (_) => onAxis(a.id),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyTasks, required this.palette});
  final bool hasAnyTasks;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final title = hasAnyTasks ? 'Под фильтр ничего не попало' : 'Задач нет';
    final body = hasAnyTasks
        ? 'Сбрось фильтры или поменяй сортировку, чтобы увидеть остальные задачи.'
        : 'Создай задачу через «+». Привяжи её к осям — выполнение начислит очки в пентаграмму.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
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

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.axesById});

  final Entry task;
  final Map<String, LifeAxis> axesById;

  Future<void> _toggleSubtask(WidgetRef ref, int index) async {
    final repo = await ref.read(repositoryProvider.future);
    final next = toggleSubtask(task.body, index);
    if (next == task.body) return;
    await repo.upsertEntry(
      task.copyWith(body: next, updatedAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final overdue = !task.isCompleted &&
        task.dueAt != null &&
        task.dueAt!.isBefore(DateTime.now());
    final subtasks = parseSubtasks(task.body);
    final prose = stripSubtasks(task.body);
    final prog = subtaskProgress(task.body);
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: task),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(
              checked: task.isCompleted,
              onTap: () => toggleTaskWithReflection(context, ref, task),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isEmpty ? '—' : task.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? palette.muted
                              : palette.fg,
                        ),
                  ),
                  if (prose.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      prose,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: palette.muted),
                    ),
                  ],
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < subtasks.length; i++)
                      _SubtaskRow(
                        subtask: subtasks[i],
                        palette: palette,
                        onToggle: () => _toggleSubtask(ref, i),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pill(
                        text: '+${task.xp} XP',
                        palette: palette,
                        emphasised: true,
                      ),
                      if (subtasks.isNotEmpty)
                        _Pill(
                          text: '☑ ${prog.done}/${prog.total}',
                          palette: palette,
                          emphasised: prog.done == prog.total,
                        ),
                      for (final id in task.axisIds)
                        if (axesById[id] != null)
                          _Pill(
                            text:
                                '${axesById[id]!.symbol}  ${axesById[id]!.name}',
                            palette: palette,
                          ),
                      if (task.dueAt != null)
                        _Pill(
                          text: 'до ${formatTimestamp(task.dueAt!)}',
                          palette: palette,
                          warning: overdue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.palette,
    required this.onToggle,
  });

  final Subtask subtask;
  final NoeticaPalette palette;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact checkbox — slightly smaller than the main task
            // checkbox so hierarchy is visually obvious.
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: palette.line, width: 1.2),
                borderRadius: BorderRadius.circular(4),
                color: subtask.checked ? palette.fg : Colors.transparent,
              ),
              child: subtask.checked
                  ? Icon(Icons.check, size: 11, color: palette.bg)
                  : null,
            ),
            Expanded(
              child: Text(
                subtask.text.isEmpty ? '—' : subtask.text,
                style: TextStyle(
                  fontSize: 13,
                  color: subtask.checked ? palette.muted : palette.fg,
                  decoration: subtask.checked
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          border: Border.all(color: palette.line, width: 1.5),
          borderRadius: BorderRadius.circular(6),
          color: checked ? palette.fg : Colors.transparent,
        ),
        child: checked
            ? Icon(Icons.check, size: 14, color: palette.bg)
            : null,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.palette,
    this.emphasised = false,
    this.warning = false,
  });

  final String text;
  final NoeticaPalette palette;
  final bool emphasised;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning
        ? palette.fg
        : (emphasised ? palette.fg : palette.muted);
    final border = warning ? palette.fg : palette.line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
