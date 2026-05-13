import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../services/pomodoro_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/body_utils.dart';
import '../../../utils/subtask_utils.dart';
import '../../../utils/time_utils.dart';
import '../../entry/entry_editor_sheet.dart';
import '../../entry/markdown_body_editor.dart';
import '../../pomodoro/pomodoro_sheet.dart';
import '../../reflection/reflection_sheet.dart';

/// A single task card with checkbox, title, subtasks, XP badge,
/// axis pills, due date, and pomodoro button.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, required this.axesById});

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
    final markdownBody = stripDisplayMetadata(bodyToMarkdown(task.body));
    final subtasks = parseSubtasks(markdownBody);
    final prose = stripSubtasks(markdownBody).trim();
    final prog = subtaskProgress(markdownBody);
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
            TaskCheckbox(
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
                    MarkdownPreview(
                      body: prose,
                      maxLines: 2,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: palette.muted),
                    ),
                  ],
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < subtasks.length; i++)
                      SubtaskRow(
                        subtask: subtasks[i],
                        palette: palette,
                        onToggle: () => _toggleSubtask(ref, i),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            TaskPill(
                              text: '+${task.xp} XP',
                              palette: palette,
                              emphasised: true,
                            ),
                            if (subtasks.isNotEmpty)
                              TaskPill(
                                text: '☑ ${prog.done}/${prog.total}',
                                palette: palette,
                                emphasised: prog.done == prog.total,
                              ),
                            for (final id in task.axisIds)
                              if (axesById[id] != null)
                                TaskPill(
                                  text:
                                      '${axesById[id]!.symbol}  ${axesById[id]!.name}',
                                  palette: palette,
                                ),
                            if (task.dueAt != null)
                              TaskPill(
                                text: S.of(context)!.dashboardDueBy(formatTimestamp(task.dueAt!)),
                                palette: palette,
                                warning: overdue,
                              ),
                          ],
                        ),
                      ),
                      if (!task.isCompleted)
                        PomodoroButton(
                          task: task,
                          palette: palette,
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

class SubtaskRow extends StatelessWidget {
  const SubtaskRow({
    super.key,
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
              child: subtask.text.isEmpty
                  ? Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    )
                  : MarkdownPreview(
                      body: subtask.text,
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

class TaskCheckbox extends StatelessWidget {
  const TaskCheckbox({super.key, required this.checked, required this.onTap});
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

class PomodoroButton extends StatelessWidget {
  const PomodoroButton({super.key, required this.task, required this.palette});

  final Entry task;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final svc = PomodoroService.instance;
    final isLinked = svc.linkedTaskId == task.id &&
        svc.phase != PomodoroPhase.idle;
    return IconButton(
      icon: Icon(
        isLinked ? Icons.timer : Icons.timer_outlined,
        size: 18,
        color: isLinked ? palette.fg : palette.muted,
      ),
      tooltip: isLinked ? S.of(context)!.pomodoroRunning : 'Pomodoro',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () async {
        if (svc.phase == PomodoroPhase.idle) {
          await svc.startFocus(
            taskId: task.id,
            taskTitle: task.title,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    S.of(context)!.pomodoroFocusStarted(svc.focusMinutes, task.title),
                  ),
                ),
              );
          }
        } else {
          if (context.mounted) PomodoroSheet.show(context);
        }
      },
    );
  }
}

class TaskPill extends StatelessWidget {
  const TaskPill({
    super.key,
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
