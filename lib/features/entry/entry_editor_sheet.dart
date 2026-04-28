import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/subtask_utils.dart';
import '../../utils/time_utils.dart';

Future<void> showEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _EntryEditor(
        existing: existing,
        initialDueAt: initialDueAt,
        initialKind: initialKind,
      ),
    ),
  );
}

class _EntryEditor extends ConsumerStatefulWidget {
  const _EntryEditor({this.existing, this.initialDueAt, this.initialKind});
  final Entry? existing;
  final DateTime? initialDueAt;
  final EntryKind? initialKind;

  @override
  ConsumerState<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<_EntryEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late EntryKind _kind;
  late Set<String> _selectedAxes;
  DateTime? _due;
  int _xp = 10;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    // Editing an existing entry keeps its kind. Creating a new entry
    // prefers the caller's hint (e.g. Calendar's "schedule task" CTA)
    // otherwise defaults to a free-form note.
    _kind = e?.kind ?? widget.initialKind ?? EntryKind.note;
    _selectedAxes = Set<String>.from(e?.axisIds ?? const <String>[]);
    // Same idea for the due date: if the caller pre-populated one (e.g.
    // we're scheduling a task for a given calendar day) we honour it.
    _due = e?.dueAt ?? widget.initialDueAt;
    _xp = e?.xp ?? 10;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _due ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    setState(() {
      _due = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
      // Auto-promote to task when a due date is set.
      _kind = EntryKind.task;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      final existing = widget.existing;
      if (existing == null) {
        await repo.createEntry(
          title: _title.text.trim(),
          body: _body.text.trim(),
          kind: _kind,
          dueAt: _due,
          xp: _xp,
          axisIds: _selectedAxes.toList(),
        );
      } else {
        await repo.upsertEntry(existing.copyWith(
          title: _title.text.trim(),
          body: _body.text.trim(),
          kind: _kind,
          dueAt: _due,
          clearDue: _due == null,
          xp: _xp,
          axisIds: _selectedAxes.toList(),
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить запись: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.deleteEntry(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final axesAsync = ref.watch(axesProvider);
    final isTask = _kind == EntryKind.task;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                widget.existing == null ? 'Новая запись' : 'Запись',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (widget.existing != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: palette.fg),
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: isTask ? 'Что нужно сделать?' : 'Заголовок',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Что у тебя на уме?',
            ),
            onChanged: (_) => setState(() {}),
          ),
          // Subtask preview: when the body has `- [ ] …` markdown the
          // user can tick them right here and we'll rewrite the body
          // transparently. Keeps the subtasks canonical (still markdown
          // in the body field so they sync with the rest of the entry).
          _SubtaskEditor(
            body: _body.text,
            onChanged: (next) {
              setState(() {
                _body.text = next;
                _body.selection =
                    TextSelection.collapsed(offset: next.length);
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Оси',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: palette.muted, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          axesAsync.when(
            loading: () => const SizedBox(
                height: 32, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e'),
            data: (axes) {
              if (axes.isEmpty) {
                return Text(
                  'Сначала добавь оси в онбординге.',
                  style: TextStyle(color: palette.muted),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in axes)
                    _AxisToggleChip(
                      axis: a,
                      selected: _selectedAxes.contains(a.id),
                      onTap: () => setState(() {
                        if (_selectedAxes.contains(a.id)) {
                          _selectedAxes.remove(a.id);
                        } else {
                          _selectedAxes.add(a.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    if (isTask) {
                      _kind = EntryKind.note;
                      _due = null;
                    } else {
                      _kind = EntryKind.task;
                    }
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Row(
                      children: [
                        Icon(
                          isTask
                              ? Icons.check_circle_outline
                              : Icons.notes_outlined,
                          size: 18,
                          color: palette.fg,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Сделать задачей',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isTask
                                    ? 'Дедлайн и XP при выполнении'
                                    : 'По умолчанию рассматривается как заметка',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isTask,
                          activeColor: palette.bg,
                          activeTrackColor: palette.fg,
                          inactiveThumbColor: palette.muted,
                          inactiveTrackColor: palette.surface,
                          onChanged: (v) => setState(() {
                            _kind = v ? EntryKind.task : EntryKind.note;
                            if (!v) _due = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !isTask
                      ? const SizedBox.shrink()
                      : Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(color: palette.line, height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickDue,
                                      icon: const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 16),
                                      label: Text(
                                        _due == null
                                            ? 'Без дедлайна'
                                            : formatTimestamp(_due!),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (_due != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () =>
                                          setState(() => _due = null),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    'XP при выполнении',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                            color: palette.muted,
                                            letterSpacing: 1.4),
                                  ),
                                  const Spacer(),
                                  Text('$_xp',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              Slider(
                                min: 1,
                                max: 100,
                                divisions: 99,
                                value: _xp.toDouble(),
                                activeColor: palette.fg,
                                inactiveColor: palette.line,
                                onChanged: (v) =>
                                    setState(() => _xp = v.round()),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '...' : 'Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisToggleChip extends StatelessWidget {
  const _AxisToggleChip({
    required this.axis,
    required this.selected,
    required this.onTap,
  });

  final LifeAxis axis;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.bg,
          border: Border.all(color: selected ? palette.fg : palette.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              axis.symbol,
              style: TextStyle(
                fontSize: 13,
                color: selected ? palette.bg : palette.fg,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              axis.name,
              style: TextStyle(
                fontSize: 12,
                color: selected ? palette.bg : palette.fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the body's `- [ ] …` lines as real tickable checkboxes. The
/// source of truth is still the markdown text — we just edit it in place
/// when the user taps a box. Hidden when the body has no checkboxes.
class _SubtaskEditor extends StatelessWidget {
  const _SubtaskEditor({required this.body, required this.onChanged});

  final String body;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final subs = parseSubtasks(body);
    if (subs.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final prog = subtaskProgress(body);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Подзадачи — ${prog.done}/${prog.total}',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < subs.length; i++)
              InkWell(
                onTap: () => onChanged(toggleSubtask(body, i)),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: palette.line, width: 1.3),
                          borderRadius: BorderRadius.circular(4),
                          color: subs[i].checked
                              ? palette.fg
                              : Colors.transparent,
                        ),
                        child: subs[i].checked
                            ? Icon(Icons.check,
                                size: 12, color: palette.bg)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          subs[i].text.isEmpty ? '—' : subs[i].text,
                          style: TextStyle(
                            fontSize: 13,
                            color: subs[i].checked
                                ? palette.muted
                                : palette.fg,
                            decoration: subs[i].checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
