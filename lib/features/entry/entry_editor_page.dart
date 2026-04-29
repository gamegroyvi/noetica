import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';

/// Opens the entry editor as a full-screen page (push route).
Future<void> openEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _EntryEditorPage(
        existing: existing,
        initialDueAt: initialDueAt,
        initialKind: initialKind,
      ),
    ),
  );
}

class _EntryEditorPage extends ConsumerStatefulWidget {
  const _EntryEditorPage({
    this.existing,
    this.initialDueAt,
    this.initialKind,
  });
  final Entry? existing;
  final DateTime? initialDueAt;
  final EntryKind? initialKind;

  @override
  ConsumerState<_EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends ConsumerState<_EntryEditorPage> {
  late final TextEditingController _title;
  late final QuillController _quill;
  late EntryKind _kind;
  late Set<String> _selectedAxes;
  DateTime? _due;
  int _xp = 10;
  bool _saving = false;
  bool _showTaskPanel = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _quill = QuillController(
      document: _bodyToDocument(e?.body ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _kind = e?.kind ?? widget.initialKind ?? EntryKind.note;
    _selectedAxes = Set<String>.from(e?.axisIds ?? const <String>[]);
    _due = e?.dueAt ?? widget.initialDueAt;
    _xp = e?.xp ?? 10;
    _showTaskPanel = _kind == EntryKind.task;
  }

  @override
  void dispose() {
    _title.dispose();
    _quill.dispose();
    super.dispose();
  }

  /// Convert a body string to a Quill Document. Handles both legacy
  /// plain text and Quill Delta JSON (starts with '[').
  Document _bodyToDocument(String body) {
    if (body.isEmpty) return Document()..insert(0, '');
    if (body.startsWith('[')) {
      try {
        final json = jsonDecode(body) as List;
        return Document.fromJson(json);
      } catch (_) {
        // Fallback to plain text if JSON is invalid.
      }
    }
    // Legacy plain text → simple document.
    final doc = Document();
    doc.insert(0, body);
    return doc;
  }

  /// Serialize the Quill document back to a storable string.
  /// Stores as Delta JSON so rich formatting is preserved.
  String _documentToBody() {
    final delta = _quill.document.toDelta();
    final plainText = _quill.document.toPlainText().trim();
    if (plainText.isEmpty) return '';
    return jsonEncode(delta.toJson());
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
      _kind = EntryKind.task;
      _showTaskPanel = true;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      final body = _documentToBody();
      final existing = widget.existing;
      if (existing == null) {
        await repo.createEntry(
          title: _title.text.trim(),
          body: body,
          kind: _kind,
          dueAt: _due,
          xp: _xp,
          axisIds: _selectedAxes.toList(),
        );
      } else {
        final demotedFromTask =
            _kind == EntryKind.note && existing.isCompleted;
        final baseXpChanged = _xp != existing.baseXp;
        await repo.upsertEntry(existing.copyWith(
          title: _title.text.trim(),
          body: body,
          kind: _kind,
          dueAt: _due,
          clearDue: _due == null,
          clearCompleted: demotedFromTask,
          xp: _xp,
          baseXp: baseXpChanged ? _xp : null,
          axisIds: _selectedAxes.toList(),
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
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
    final isNew = widget.existing == null;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isNew ? 'Новая запись' : 'Редактирование',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: palette.muted,
          ),
        ),
        actions: [
          if (!isNew)
            IconButton(
              icon: Icon(Icons.delete_outline, color: palette.muted),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : 'Готово',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _saving ? palette.muted : palette.fg,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Title field — large, clean, Notion-style.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _title,
              autofocus: isNew,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: palette.fg,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: _kind == EntryKind.task
                    ? 'Что нужно сделать?'
                    : 'Без названия',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: palette.muted.withOpacity(0.4),
                  height: 1.3,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // Quill toolbar — compact, minimal.
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: palette.line, width: 0.5),
                bottom: BorderSide(color: palette.line, width: 0.5),
              ),
            ),
            child: QuillSimpleToolbar(
              controller: _quill,
              configurations: const QuillSimpleToolbarConfigurations(
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: true,
                showHeaderStyle: true,
                showCodeBlock: false,
                showInlineCode: true,
                showLink: true,
                showQuote: true,
                showDividers: false,
                showFontFamily: false,
                showFontSize: false,
                showBackgroundColorButton: false,
                showColorButton: false,
                showIndent: false,
                showAlignmentButtons: false,
                showDirection: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showClipboardCut: false,
                showClipboardCopy: false,
                showClipboardPaste: false,
                showUndo: false,
                showRedo: false,
                showClearFormat: false,
                multiRowsDisplay: false,
                buttonOptions: QuillSimpleToolbarButtonOptions(
                  base: QuillToolbarBaseButtonOptions(
                    iconSize: 18,
                    iconButtonFactor: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // Body editor — rich text, WYSIWYG.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: QuillEditor.basic(
                controller: _quill,
                configurations: const QuillEditorConfigurations(
                  placeholder: 'Начни писать...',
                  padding: EdgeInsets.symmetric(vertical: 16),
                  autoFocus: false,
                  expands: true,
                  scrollable: true,
                ),
              ),
            ),
          ),

          // Bottom panel — axes + task controls, collapsible.
          _BottomPanel(
            palette: palette,
            kind: _kind,
            showTaskPanel: _showTaskPanel,
            selectedAxes: _selectedAxes,
            due: _due,
            xp: _xp,
            axesAsync: axesAsync,
            onToggleKind: () => setState(() {
              if (_kind == EntryKind.task) {
                _kind = EntryKind.note;
                _due = null;
                _showTaskPanel = false;
              } else {
                _kind = EntryKind.task;
                _showTaskPanel = true;
              }
            }),
            onTogglePanel: () =>
                setState(() => _showTaskPanel = !_showTaskPanel),
            onPickDue: _pickDue,
            onClearDue: () => setState(() => _due = null),
            onXpChanged: (v) => setState(() => _xp = v),
            onToggleAxis: (id) => setState(() {
              if (_selectedAxes.contains(id)) {
                _selectedAxes.remove(id);
              } else {
                _selectedAxes.add(id);
              }
            }),
          ),
        ],
      ),
    );
  }
}

/// Collapsible bottom panel for task controls + axes.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.palette,
    required this.kind,
    required this.showTaskPanel,
    required this.selectedAxes,
    required this.due,
    required this.xp,
    required this.axesAsync,
    required this.onToggleKind,
    required this.onTogglePanel,
    required this.onPickDue,
    required this.onClearDue,
    required this.onXpChanged,
    required this.onToggleAxis,
  });

  final NoeticaPalette palette;
  final EntryKind kind;
  final bool showTaskPanel;
  final Set<String> selectedAxes;
  final DateTime? due;
  final int xp;
  final AsyncValue<List<LifeAxis>> axesAsync;
  final VoidCallback onToggleKind;
  final VoidCallback onTogglePanel;
  final VoidCallback onPickDue;
  final VoidCallback onClearDue;
  final ValueChanged<int> onXpChanged;
  final ValueChanged<String> onToggleAxis;

  @override
  Widget build(BuildContext context) {
    final isTask = kind == EntryKind.task;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick-action bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  _PanelChip(
                    icon: isTask
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    label: isTask ? 'Задача' : 'Заметка',
                    active: isTask,
                    palette: palette,
                    onTap: onToggleKind,
                  ),
                  const SizedBox(width: 8),
                  if (isTask)
                    _PanelChip(
                      icon: Icons.calendar_today_outlined,
                      label: due == null ? 'Дедлайн' : formatTimestamp(due!),
                      active: due != null,
                      palette: palette,
                      onTap: onPickDue,
                      onLongPress: due != null ? onClearDue : null,
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      showTaskPanel
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: palette.muted,
                      size: 20,
                    ),
                    onPressed: onTogglePanel,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Expandable detail panel.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: showTaskPanel
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isTask) ...[
                            Row(
                              children: [
                                Text(
                                  'XP',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$xp',
                                  style: TextStyle(
                                    color: palette.fg,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                trackHeight: 2,
                                activeTrackColor: palette.fg,
                                inactiveTrackColor: palette.line,
                                thumbColor: palette.fg,
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                              ),
                              child: Slider(
                                min: 1,
                                max: 100,
                                divisions: 99,
                                value: xp.toDouble(),
                                onChanged: (v) => onXpChanged(v.round()),
                              ),
                            ),
                          ],
                          Text(
                            'Оси',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          axesAsync.when(
                            loading: () => const SizedBox(
                              height: 28,
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                            error: (e, _) =>
                                Text('$e', style: TextStyle(color: palette.muted)),
                            data: (axes) {
                              if (axes.isEmpty) {
                                return Text(
                                  'Нет осей',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 13,
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final a in axes)
                                    _AxisChip(
                                      axis: a,
                                      selected: selectedAxes.contains(a.id),
                                      palette: palette,
                                      onTap: () => onToggleAxis(a.id),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final bool active;
  final NoeticaPalette palette;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? palette.fg : palette.bg,
          border: Border.all(color: active ? palette.fg : palette.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? palette.bg : palette.muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? palette.bg : palette.fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisChip extends StatelessWidget {
  const _AxisChip({
    required this.axis,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final LifeAxis axis;
  final bool selected;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                fontSize: 12,
                color: selected ? palette.bg : palette.fg,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              axis.name,
              style: TextStyle(
                fontSize: 11,
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
