import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../entry/entry_editor_sheet.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Задачи')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          final tasks =
              entries.where((e) => e.isTask).toList()
                ..sort((a, b) {
                  // Active first (by due asc, then created desc), then completed.
                  if (a.isCompleted != b.isCompleted) {
                    return a.isCompleted ? 1 : -1;
                  }
                  if (!a.isCompleted) {
                    final ad = a.dueAt;
                    final bd = b.dueAt;
                    if (ad == null && bd != null) return 1;
                    if (ad != null && bd == null) return -1;
                    if (ad != null && bd != null) {
                      return ad.compareTo(bd);
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  }
                  return (b.completedAt ?? b.updatedAt)
                      .compareTo(a.completedAt ?? a.updatedAt);
                });
          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Задач нет',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Создай задачу через «+». Привяжи её к осям — выполнение начислит очки в пентаграмму.',
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
          final axes = axesAsync.valueOrNull ?? const [];
          final axesById = {for (final a in axes) a.id: a};
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) =>
                _TaskTile(task: tasks[i], axesById: axesById),
          );
        },
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.axesById});

  final Entry task;
  final Map<String, LifeAxis> axesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final overdue = !task.isCompleted &&
        task.dueAt != null &&
        task.dueAt!.isBefore(DateTime.now());
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
              onTap: () async {
                final repo =
                    await ref.read(repositoryProvider.future);
                await repo.toggleTaskComplete(task);
              },
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
                  if (task.dueAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'до ${formatTimestamp(task.dueAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: overdue ? palette.fg : palette.muted,
                        fontWeight:
                            overdue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                  if (task.axisIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final aid in task.axisIds)
                          if (axesById[aid] != null)
                            _MiniAxisChip(axis: axesById[aid]!),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: palette.line),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+${task.xp} XP',
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAxisChip extends StatelessWidget {
  const _MiniAxisChip({required this.axis});
  final LifeAxis axis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(axis.symbol, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            axis.name,
            style: TextStyle(fontSize: 10, color: palette.fg),
          ),
        ],
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: checked ? palette.fg : palette.bg,
          border: Border.all(color: checked ? palette.fg : palette.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: checked
            ? Icon(Icons.check, color: palette.bg, size: 16)
            : null,
      ),
    );
  }
}
