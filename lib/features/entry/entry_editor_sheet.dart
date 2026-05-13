import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
import '../../utils/subtask_utils.dart';
import '../../utils/time_utils.dart';
import 'markdown_body_editor.dart';
import 'widgets/editor_fields.dart';

/// Sentinel popped from the bottom sheet when the user taps "expand".
class _ExpandIntent {
  _ExpandIntent({
    required this.title,
    required this.body,
    required this.kind,
    required this.due,
    required this.xp,
    required this.selectedAxes,
    required this.tags,
    required this.existing,
    required this.initialDueAt,
    required this.initialKind,
  });

  final String title;
  final String body;
  final EntryKind kind;
  final DateTime? due;
  final int xp;
  final Set<String> selectedAxes;
  final List<String> tags;
  final Entry? existing;
  final DateTime? initialDueAt;
  final EntryKind? initialKind;
}

Future<void> showEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  final result = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      final maxH =
          size.width >= 1100 ? size.height * 0.92 : size.height * 0.85;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: _EntryEditorForm(
            existing: existing,
            initialDueAt: initialDueAt,
            initialKind: initialKind,
            isFullScreen: false,
          ),
        ),
      );
    },
  );

  if (!context.mounted) return;

  if (result is Entry) {
    // Wiki-link navigation — open linked entry
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!context.mounted) return;
    await showEntryEditor(context, ref, existing: result);
  } else if (result is _ExpandIntent) {
    // Expand to full screen
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FullScreenEditorPage(intent: result),
      ),
    );
  }
}

/// Full-screen editor page (pushed when user taps expand). The form
/// itself owns the [Scaffold] / [AppBar] in document mode so it can
/// switch between a wide-screen side rail and a narrow-screen end
/// drawer; we deliberately do NOT wrap it in another Scaffold here.
class _FullScreenEditorPage extends StatelessWidget {
  const _FullScreenEditorPage({required this.intent});
  final _ExpandIntent intent;

  @override
  Widget build(BuildContext context) {
    return _EntryEditorForm(
      existing: intent.existing,
      initialDueAt: intent.initialDueAt,
      initialKind: intent.initialKind,
      isFullScreen: true,
      restoredTitle: intent.title,
      restoredBody: intent.body,
      restoredKind: intent.kind,
      restoredDue: intent.due,
      restoredXp: intent.xp,
      restoredAxes: intent.selectedAxes,
      restoredTags: intent.tags,
    );
  }
}

// -------------------------------------------------------------------
// Shared editor form used by both bottom-sheet and full-screen modes.
// -------------------------------------------------------------------

class _EntryEditorForm extends ConsumerStatefulWidget {
  const _EntryEditorForm({
    this.existing,
    this.initialDueAt,
    this.initialKind,
    required this.isFullScreen,
    this.restoredTitle,
    this.restoredBody,
    this.restoredKind,
    this.restoredDue,
    this.restoredXp,
    this.restoredAxes,
    this.restoredTags,
  });

  final Entry? existing;
  final DateTime? initialDueAt;
  final EntryKind? initialKind;
  final bool isFullScreen;

  // State restored from bottom-sheet when expanding to full screen.
  final String? restoredTitle;
  final String? restoredBody;
  final EntryKind? restoredKind;
  final DateTime? restoredDue;
  final int? restoredXp;
  final Set<String>? restoredAxes;
  final List<String>? restoredTags;

  @override
  ConsumerState<_EntryEditorForm> createState() => _EntryEditorFormState();
}

class _EntryEditorFormState extends ConsumerState<_EntryEditorForm> {
  late final TextEditingController _title;
  late final LiveMarkdownController _body;
  late final TextEditingController _tagInput;
  late EntryKind _kind;
  late Set<String> _selectedAxes;
  late List<String> _tags;
  DateTime? _due;
  int _xp = 10;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    // Use restored state if coming from expand, otherwise from entry.
    _title = TextEditingController(
      text: widget.restoredTitle ?? e?.title ?? '',
    );
    _body = LiveMarkdownController(
      text: widget.restoredBody ?? _migrateDeltaBody(e?.body ?? ''),
      palette: const NoeticaPalette(
        fg: Color(0xFF000000),
        bg: Color(0xFFFFFFFF),
        surface: Color(0xFFF2F2F2),
        muted: Color(0xFF757575),
        line: Color(0xFFCCCCCC),
      ),
    );
    _tagInput = TextEditingController();
    _kind = widget.restoredKind ??
        e?.kind ??
        widget.initialKind ??
        EntryKind.note;
    _selectedAxes = widget.restoredAxes != null
        ? Set<String>.from(widget.restoredAxes!)
        : Set<String>.from(e?.axisIds ?? const <String>[]);
    _tags = widget.restoredTags != null
        ? List<String>.from(widget.restoredTags!)
        : List<String>.from(e?.tags ?? const <String>[]);
    _due = widget.restoredDue ?? e?.dueAt ?? widget.initialDueAt;
    _xp = widget.restoredXp ?? e?.xp ?? 10;
  }

  String _migrateDeltaBody(String body) {
    if (body.isEmpty) return '';
    if (body.startsWith('[')) return bodyToPlainText(body);
    return body;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      _kind = EntryKind.task;
    });
  }

  Future<void> _save() async {
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
      try {
        await repo.syncBodyLinks(saved);
      } catch (_) {}
      AnalyticsService.instance.track(
        existing == null
            ? (_kind == EntryKind.task
                ? AnalyticsEvents.taskCreated
                : AnalyticsEvents.noteCreated)
            : 'entry_updated',
        {'kind': _kind.name, 'axes': _selectedAxes.length},
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.editorSaveError('$e'))),
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
    AnalyticsService.instance.track(AnalyticsEvents.entryDeleted, {
      'kind': existing.kind.name,
    });
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.editorDeletedMsg(existing.title)),
          action: SnackBarAction(
            label: S.of(context)!.actionUndo,
            onPressed: () async {
              await repo.restoreEntry(existing.id);
            },
          ),
        ),
      );
  }

  void _expand() {
    Navigator.of(context).pop(
      _ExpandIntent(
        title: _title.text,
        body: _body.text,
        kind: _kind,
        due: _due,
        xp: _xp,
        selectedAxes: Set<String>.from(_selectedAxes),
        tags: List<String>.from(_tags),
        existing: widget.existing,
        initialDueAt: widget.initialDueAt,
        initialKind: widget.initialKind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullScreen) return _buildFullScreen(context);
    return _buildSheet(context);
  }

  // ------------------------------------------------------------------
  // Shared section builders. Each returns a self-contained Column so
  // both the bottom-sheet layout and the document layout can compose
  // them differently without duplicating widget trees.
  // ------------------------------------------------------------------

  Widget _buildTitleField(BuildContext context, {bool large = false}) {
    final isTask = _kind == EntryKind.task;
    final theme = Theme.of(context);
    final palette = context.palette;
    return TextField(
      controller: _title,
      autofocus: widget.existing == null && !widget.isFullScreen,
      style: large
          ? theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.15)
          : theme.textTheme.titleMedium,
      cursorColor: palette.fg,
      decoration: InputDecoration(
        hintText: isTask ? S.of(context)!.editorHintTask : S.of(context)!.editorTitle,
        // Document mode: borderless, no fill — the title reads like a
        // headline at the top of a Word page, not like another input.
        filled: large ? false : null,
        fillColor: large ? Colors.transparent : null,
        border: large ? InputBorder.none : null,
        enabledBorder: large ? InputBorder.none : null,
        focusedBorder: large ? InputBorder.none : null,
        hintStyle: large
            ? theme.textTheme.headlineMedium?.copyWith(
                color: palette.muted.withOpacity(0.55),
                fontWeight: FontWeight.w600,
                height: 1.15,
              )
            : null,
        contentPadding:
            large ? const EdgeInsets.symmetric(vertical: 4) : null,
      ),
    );
  }

  Widget _buildSubtaskSection() {
    return SubtaskEditor(
      body: _body.text,
      onChanged: (next) {
        setState(() {
          _body.text = next;
          _body.selection =
              TextSelection.collapsed(offset: next.length);
        });
      },
    );
  }

  Widget _buildTagsSection(NoeticaPalette palette) {
    return TagsField(
      palette: palette,
      tags: _tags,
      controller: _tagInput,
      onCommit: _commitTagInput,
      onRemove: _removeTag,
    );
  }

  Widget _buildBacklinksSection(NoeticaPalette palette) {
    if (widget.existing == null) return const SizedBox.shrink();
    return BacklinksPanel(
      palette: palette,
      entryId: widget.existing!.id,
      onTapEntry: (entry) => Navigator.of(context).pop(entry),
    );
  }

  Widget _buildAxesSection(BuildContext context, NoeticaPalette palette) {
    final axesAsync = ref.watch(axesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.editorAxes,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: palette.muted, letterSpacing: 1.4),
        ),
        const SizedBox(height: 8),
        axesAsync.when(
          loading: () => const SizedBox(
              height: 32,
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (axes) {
            if (axes.isEmpty) {
              return Text(
                S.of(context)!.editorAddAxesHint,
                style: TextStyle(color: palette.muted),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in axes)
                  AxisToggleChip(
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
      ],
    );
  }

  // ------------------------------------------------------------------
  // Bottom-sheet layout (compact, vertical scroll, draggable handle).
  // ------------------------------------------------------------------

  Widget _buildSheet(BuildContext context) {
    final palette = context.palette;
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
                widget.existing == null ? S.of(context)!.editorNewEntry : S.of(context)!.editorEntry,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.open_in_full, color: palette.fg, size: 20),
                tooltip: S.of(context)!.editorExpand,
                onPressed: _expand,
              ),
              if (widget.existing != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: palette.fg),
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTitleField(context),
          const SizedBox(height: 12),
          MarkdownBodyEditor(
            controller: _body,
            entryId: widget.existing?.id,
            minLines: 6,
            maxLines: 14,
          ),
          _buildSubtaskSection(),
          const SizedBox(height: 16),
          _buildTagsSection(palette),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            _buildBacklinksSection(palette),
          ],
          const SizedBox(height: 16),
          _buildAxesSection(context, palette),
          const SizedBox(height: 16),
          _buildKindAndDuePanel(context, palette),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '...' : S.of(context)!.actionSave),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindAndDuePanel(
      BuildContext context, NoeticaPalette palette) {
    final isTask = _kind == EntryKind.task;
    return Container(
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
                          S.of(context)!.editorMakeTask,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTask
                              ? S.of(context)!.editorTaskModeHint
                              : S.of(context)!.editorNoteModeHint,
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                                      ? S.of(context)!.editorNoDeadline
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
                              S.of(context)!.editorXpOnComplete,
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
    );
  }

  // ------------------------------------------------------------------
  // Full-screen "document mode": Word-like editor with a tall body
  // that fills the viewport and metadata pushed to a side rail (wide
  // screens) or a dismissable end-drawer (narrow screens).
  // ------------------------------------------------------------------

  Widget _buildFullScreen(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.of(context).size.width;
    // Wide enough to fit a 720-px document column AND a 320-px metadata
    // rail without crowding either. Below this break we collapse the
    // rail into an end-drawer accessed from the app bar.
    final wide = width >= 1024;

    final scaffold = Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: palette.fg),
          tooltip: S.of(context)!.editorClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.existing == null ? S.of(context)!.editorNewEntry : S.of(context)!.editorEntry,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: palette.muted),
        ),
        actions: [
          if (!wide)
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.tune, color: palette.fg),
                tooltip: S.of(context)!.editorParams,
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          if (widget.existing != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: palette.fg),
              tooltip: S.of(context)!.actionDelete,
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '...' : S.of(context)!.actionSave),
            ),
          ),
        ],
      ),
      endDrawer: wide ? null : _buildMetadataDrawer(context, palette),
      body: SafeArea(
        top: false,
        child: wide
            ? _buildFullScreenWide(context, palette)
            : _buildFullScreenNarrow(context, palette),
      ),
    );

    return scaffold;
  }

  Widget _buildFullScreenWide(
      BuildContext context, NoeticaPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildDocumentColumn(context, palette)),
        Container(width: 1, color: palette.line),
        SizedBox(
          width: 340,
          child: _buildMetadataPanel(context, palette,
              embedded: true),
        ),
      ],
    );
  }

  Widget _buildFullScreenNarrow(
      BuildContext context, NoeticaPalette palette) {
    return _buildDocumentColumn(context, palette);
  }

  /// Centred "page" with title at the top and the body editor filling
  /// the remaining height. Padded so it reads like a Word document.
  Widget _buildDocumentColumn(
      BuildContext context, NoeticaPalette palette) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleField(context, large: true),
              const SizedBox(height: 12),
              Expanded(
                child: MarkdownBodyEditor(
                  controller: _body,
                  entryId: widget.existing?.id,
                  expand: true,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataDrawer(
      BuildContext context, NoeticaPalette palette) {
    return Drawer(
      backgroundColor: palette.bg,
      width: 340,
      child: SafeArea(
        child: _buildMetadataPanel(context, palette, embedded: false),
      ),
    );
  }

  /// Right-rail content shared by the wide layout (`embedded=true`,
  /// flush against the document) and the narrow drawer (`embedded=false`,
  /// gets its own header with a close button).
  Widget _buildMetadataPanel(
      BuildContext context, NoeticaPalette palette,
      {required bool embedded}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  S.of(context)!.editorParams,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: palette.fg),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, embedded ? 24 : 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKindAndDuePanel(context, palette),
                const SizedBox(height: 20),
                if (parseSubtasks(_body.text).isNotEmpty) ...[
                  _buildSubtaskSection(),
                  const SizedBox(height: 20),
                ],
                _buildAxesSection(context, palette),
                const SizedBox(height: 20),
                _buildTagsSection(palette),
                if (widget.existing != null) ...[
                  const SizedBox(height: 20),
                  _buildBacklinksSection(palette),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

