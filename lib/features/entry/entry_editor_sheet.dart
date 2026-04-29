import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/subtask_utils.dart';
import '../../utils/time_utils.dart';
import 'markdown_body_editor.dart';

/// Marker the editor sheet returns when the user taps one of the
/// quick-create affordances inside the reader view. The top-level
/// `showEntryEditor` closure sees it, dismisses the current sheet, and
/// reopens a fresh editor of the right kind so the user keeps flowing
/// through their notes without back-tracking through the dashboard.
class _QuickCreateIntent {
  const _QuickCreateIntent(this.kind);
  final EntryKind kind;
}

Future<void> showEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  // The editor pops with:
  //  - `Entry` → user tapped a [[wiki link]]; open that target next;
  //  - `_QuickCreateIntent` → user tapped "+ Заметка" / "+ Задача" in
  //    reader mode; open a fresh editor for that kind;
  //  - `null` → plain close.
  final result = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      // On wide layouts we let the sheet take more vertical space so
      // the WYSIWYG split-view has room to breathe.
      final maxH = size.width >= 1100 ? size.height * 0.92 : size.height * 0.85;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: _EntryEditor(
            existing: existing,
            initialDueAt: initialDueAt,
            initialKind: initialKind,
          ),
        ),
      );
    },
  );
  if (result == null || !context.mounted) return;
  // Allow the previous sheet to fully dismiss before pushing the next
  // one so animations don't overlap.
  await Future<void>.delayed(const Duration(milliseconds: 120));
  if (!context.mounted) return;
  if (result is Entry) {
    await showEntryEditor(context, ref, existing: result);
  } else if (result is _QuickCreateIntent) {
    await showEntryEditor(context, ref, initialKind: result.kind);
  }
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
  late final LiveMarkdownController _body;
  late final TextEditingController _tagInput;
  late EntryKind _kind;
  late Set<String> _selectedAxes;
  late List<String> _tags;
  DateTime? _due;
  int _xp = 10;
  bool _saving = false;
  // When opening an existing entry we land in *read* mode first — a
  // clean Markdown-rendered view with only the entry contents — and
  // require the user to tap "Редактировать" before any editor chrome
  // (toolbar, axis chips, tag input, due-date picker, …) is shown.
  // Creating a new entry skips this and goes straight to edit mode.
  late bool _editing;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _editing = e == null;
    _title = TextEditingController(text: e?.title ?? '');
    // `LiveMarkdownController` renders bold / italic / headings / wiki
    // links / tags inline while the user is still typing raw markdown,
    // so notes feel WYSIWYG without us changing the storage format.
    // We seed it with a placeholder palette; the real palette is
    // injected from `didChangeDependencies` once the theme is known.
    _body = LiveMarkdownController(
      text: e?.body ?? '',
      palette: const NoeticaPalette(
        fg: Color(0xFF000000),
        bg: Color(0xFFFFFFFF),
        surface: Color(0xFFF2F2F2),
        muted: Color(0xFF757575),
        line: Color(0xFFCCCCCC),
      ),
    );
    _tagInput = TextEditingController();
    // Editing an existing entry keeps its kind. Creating a new entry
    // prefers the caller's hint (e.g. Calendar's "schedule task" CTA)
    // otherwise defaults to a free-form note.
    _kind = e?.kind ?? widget.initialKind ?? EntryKind.note;
    _selectedAxes = Set<String>.from(e?.axisIds ?? const <String>[]);
    _tags = List<String>.from(e?.tags ?? const <String>[]);
    // Same idea for the due date: if the caller pre-populated one (e.g.
    // we're scheduling a task for a given calendar day) we honour it.
    _due = e?.dueAt ?? widget.initialDueAt;
    _xp = e?.xp ?? 10;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the live-markdown controller's dim color in sync with the
    // active theme so light/dark modes both render tastefully.
    _body.setPalette(context.palette);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _commitTagInput() {
    final raw = _tagInput.text.trim();
    if (raw.isEmpty) return;
    // Allow comma-separated input as a shortcut.
    for (final part in raw.split(RegExp(r'[,\s]+'))) {
      final clean = part.replaceAll('#', '').trim().toLowerCase();
      if (clean.isEmpty) continue;
      if (_tags.contains(clean)) continue;
      _tags.add(clean);
    }
    _tagInput.clear();
    setState(() {});
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
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
    // Make sure any half-typed tag in the input field is committed before
    // we serialise.
    _commitTagInput();
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      final existing = widget.existing;
      Entry saved;
      if (existing == null) {
        saved = await repo.createEntry(
          title: _title.text.trim(),
          body: _body.text.trim(),
          kind: _kind,
          dueAt: _due,
          xp: _xp,
          axisIds: _selectedAxes.toList(),
          tags: _tags,
        );
      } else {
        final demotedFromTask =
            _kind == EntryKind.note && existing.isCompleted;
        final baseXpChanged = _xp != existing.baseXp;
        saved = existing.copyWith(
          title: _title.text.trim(),
          body: _body.text.trim(),
          kind: _kind,
          dueAt: _due,
          clearDue: _due == null,
          clearCompleted: demotedFromTask,
          xp: _xp,
          baseXp: baseXpChanged ? _xp : null,
          axisIds: _selectedAxes.toList(),
          tags: _tags,
          updatedAt: DateTime.now(),
        );
        await repo.upsertEntry(saved);
      }
      // Auto-resolve [[wiki links]] in the body — creates stub entries
      // for any unknown title and inserts bidirectional rows in
      // entry_links so the knowledge graph picks them up.
      try {
        await repo.syncBodyLinks(saved);
      } catch (_) {/* best effort */}
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
      child: _editing
          ? _buildEditorBody(context, palette, axesAsync, isTask)
          : _buildReaderBody(context, palette),
    );
  }

  Widget _buildReaderBody(BuildContext context, NoeticaPalette palette) {
    final e = widget.existing!;
    final title = e.title.trim().isEmpty ? 'Без названия' : e.title;
    final hasBody = e.body.trim().isNotEmpty;
    return Column(
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
        // Header: title + delete; tap title also flips to edit mode.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: Icon(Icons.delete_outline, color: palette.muted),
              onPressed: _delete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Meta row: kind + due
        Row(
          children: [
            _ReaderChip(
              icon: e.kind == EntryKind.task
                  ? Icons.check_circle_outline
                  : Icons.notes_outlined,
              label: e.kind == EntryKind.task ? 'Задача' : 'Заметка',
              palette: palette,
            ),
            if (_due != null) ...[
              const SizedBox(width: 8),
              _ReaderChip(
                icon: Icons.event_outlined,
                label: formatTimestamp(_due!),
                palette: palette,
              ),
            ],
            const Spacer(),
            if (e.bookmarked)
              Icon(Icons.bookmark, color: palette.fg, size: 18),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$t',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Body — fully rendered Markdown with no editor chrome. Tapping
        // the empty area or the dedicated "Редактировать" button below
        // flips to edit mode.
        GestureDetector(
          onTap: hasBody ? null : () => setState(() => _editing = true),
          behavior: HitTestBehavior.opaque,
          child: hasBody
              ? MarkdownBody(
                  data: e.body,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context),
                  ).copyWith(
                    p: TextStyle(
                      color: palette.fg,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  child: Text(
                    'Запись пуста — нажми чтобы написать.',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        // Primary CTA — open the actual editor.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Редактировать'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.fg,
              foregroundColor: palette.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => setState(() => _editing = true),
          ),
        ),
        const SizedBox(height: 16),
        // Backlinks under the reader so the user can hop to related
        // notes without entering edit mode at all.
        _BacklinksPanel(
          palette: palette,
          entryId: e.id,
          onTapEntry: (entry) => Navigator.of(context).pop(entry),
        ),
        const SizedBox(height: 12),
        // Quick-create row: while reading, the user can launch a new
        // note / task in one tap without back-tracking through the
        // dashboard. Pop with a `_QuickCreateIntent` — `showEntryEditor`
        // replaces the current sheet with a fresh editor for that kind.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('Заметка'),
                onPressed: () => Navigator.of(context).pop(
                  const _QuickCreateIntent(EntryKind.note),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.fg,
                  side: BorderSide(color: palette.line),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_box_outlined, size: 18),
                label: const Text('Задача'),
                onPressed: () => Navigator.of(context).pop(
                  const _QuickCreateIntent(EntryKind.task),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.fg,
                  side: BorderSide(color: palette.line),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditorBody(BuildContext context, NoeticaPalette palette,
      AsyncValue<List<LifeAxis>> axesAsync, bool isTask) {
    return Column(
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
          MarkdownBodyEditor(
            controller: _body,
            entryId: widget.existing?.id,
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
          _TagsField(
            palette: palette,
            tags: _tags,
            controller: _tagInput,
            onCommit: _commitTagInput,
            onRemove: _removeTag,
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            _BacklinksPanel(
              palette: palette,
              entryId: widget.existing!.id,
              onTapEntry: (entry) =>
                  Navigator.of(context).pop(entry),
            ),
          ],
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

/// Compact chip-input used for the entry's tags. The tag list is the
/// source of truth — the backing TextField only holds the half-typed
/// next tag. Comma / space / Enter all commit.
class _TagsField extends StatelessWidget {
  const _TagsField({
    required this.palette,
    required this.tags,
    required this.controller,
    required this.onCommit,
    required this.onRemove,
  });

  final NoeticaPalette palette;
  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onCommit;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Теги',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: palette.muted, letterSpacing: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in tags)
                InkWell(
                  onTap: () => onRemove(tag),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#', style: TextStyle(color: palette.muted, fontSize: 11)),
                        Text(
                          tag,
                          style: TextStyle(color: palette.fg, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 11, color: palette.muted),
                      ],
                    ),
                  ),
                ),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(color: palette.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: tags.isEmpty ? 'добавить тег…' : '+',
                      hintStyle: TextStyle(color: palette.muted, fontSize: 12),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                    ),
                    onSubmitted: (_) => onCommit(),
                    onChanged: (v) {
                      if (v.endsWith(' ') || v.endsWith(',')) onCommit();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Read-only list of entries that link _to_ this entry via `[[…]]`.
/// Lets the user pivot from a note to its referrers without leaving
/// the editor sheet.
class _BacklinksPanel extends ConsumerWidget {
  const _BacklinksPanel({
    required this.palette,
    required this.entryId,
    required this.onTapEntry,
  });

  final NoeticaPalette palette;
  final String entryId;
  final ValueChanged<Entry> onTapEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(repositoryProvider);
    return repoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (repo) => FutureBuilder<List<Entry>>(
        future: repo.listBacklinks(entryId),
        builder: (context, snap) {
          final items = snap.data ?? const <Entry>[];
          if (items.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_left,
                        size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Сюда ссылаются (${items.length})',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in items)
                  InkWell(
                    onTap: () => onTapEntry(e),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            e.kind == EntryKind.task
                                ? Icons.check_circle_outline
                                : Icons.note_outlined,
                            size: 14,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.title.isEmpty ? '(без названия)' : e.title,
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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

class _ReaderChip extends StatelessWidget {
  const _ReaderChip({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
