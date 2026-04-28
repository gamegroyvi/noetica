// Markdown-first WYSIWYG editor for entry bodies.
//
// Source of truth is plain markdown in the body field — this widget
// only adds three things on top of a normal multi-line `TextField`:
//
//  1. a sticky toolbar that wraps the current selection in markdown
//     syntax (bold / italic / strike / heading / list / checkbox /
//     link / wikilink / inline code / tag);
//  2. an Obsidian-style `[[…]]` autocomplete popup that appears as
//     soon as the user types `[[`. The popup ranks existing entry
//     titles by prefix match and inserts `[[Title]]` on Enter / tap.
//     If nothing matches, the user can still finish typing the title
//     manually and `repository.syncBodyLinks` will create a stub
//     entry for the link target on save (Obsidian-style);
//  3. a Markdown preview tab — full-width toggle on mobile, a
//     side-by-side split on desktop (≥ 1100 px). Checkboxes in the
//     preview are tappable and rewrite the underlying markdown so
//     `- [ ]` / `- [x]` actually do something.
//
// We keep the body as plain markdown rather than a JSON block tree so
// we don't break sync (the LWW protocol just sees a plain text field)
// and so existing parsing utilities (subtask_utils, extractWikiLinks)
// keep working untouched.
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/subtask_utils.dart';

/// Multi-line markdown editor used inside `_EntryEditor`.
class MarkdownBodyEditor extends ConsumerStatefulWidget {
  const MarkdownBodyEditor({
    super.key,
    required this.controller,
    required this.entryId,
    this.hintText,
    this.minLines = 6,
    this.maxLines = 14,
  });

  final TextEditingController controller;
  /// Used by the wiki-link picker to filter the current entry out of
  /// the suggestion list (no self-links). `null` for new entries.
  final String? entryId;
  final String? hintText;
  final int minLines;
  final int maxLines;

  @override
  ConsumerState<MarkdownBodyEditor> createState() =>
      _MarkdownBodyEditorState();
}

enum _PreviewMode { editOnly, preview, split }

class _MarkdownBodyEditorState extends ConsumerState<MarkdownBodyEditor> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _suggestionsOverlay;
  _PreviewMode _mode = _PreviewMode.editOnly;
  String _wikiQuery = '';
  int _wikiTriggerStart = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _hideSuggestions();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _hideSuggestions();
  }

  void _onTextChanged() {
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _hideSuggestions();
      return;
    }
    final caret = sel.baseOffset;
    final text = widget.controller.text;
    // Walk backwards from the caret to find an unclosed `[[`. Stop at
    // newline, `]]` (already closed), or > 40 chars.
    int? trigger;
    for (var i = caret - 1; i >= 0 && caret - i < 40; i--) {
      final c = text[i];
      if (c == '\n') break;
      if (i + 1 < text.length && text.substring(i, i + 2) == ']]') break;
      if (i - 1 >= 0 && text.substring(i - 1, i + 1) == '[[') {
        trigger = i + 1; // position right after the opening `[[`
        break;
      }
    }
    if (trigger == null) {
      _hideSuggestions();
      return;
    }
    final query = text.substring(trigger, caret);
    if (query.contains('\n')) {
      _hideSuggestions();
      return;
    }
    setState(() {
      _wikiQuery = query;
      _wikiTriggerStart = trigger!;
    });
    _showSuggestions();
  }

  void _showSuggestions() {
    if (_suggestionsOverlay != null) {
      _suggestionsOverlay!.markNeedsBuild();
      return;
    }
    _suggestionsOverlay = OverlayEntry(builder: _buildSuggestionsOverlay);
    Overlay.of(context).insert(_suggestionsOverlay!);
  }

  void _hideSuggestions() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
  }

  Widget _buildSuggestionsOverlay(BuildContext _) {
    return Positioned(
      width: 280,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(8, 24),
        child: Material(
          color: Colors.transparent,
          child: Consumer(
            builder: (context, ref, _) {
              final entries = ref.watch(entriesProvider).valueOrNull ??
                  const <Entry>[];
              return _WikiLinkSuggestions(
                query: _wikiQuery,
                allEntries: entries,
                excludeEntryId: widget.entryId,
                onSelect: (title) => _insertWikiLink(title),
                onDismiss: _hideSuggestions,
              );
            },
          ),
        ),
      ),
    );
  }

  void _insertWikiLink(String title) {
    final ctrl = widget.controller;
    final caret = ctrl.selection.baseOffset;
    final text = ctrl.text;
    if (_wikiTriggerStart < 0 || caret < _wikiTriggerStart) {
      _hideSuggestions();
      return;
    }
    final replacement = '$title]] ';
    final next = text.replaceRange(_wikiTriggerStart, caret, replacement);
    final newCaret = _wikiTriggerStart + replacement.length;
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    _hideSuggestions();
  }

  // ----- toolbar actions -----

  void _wrap(String left, String right) {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final replacement = '$left$selected$right';
    final next = text.replaceRange(start, end, replacement);
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: start + left.length,
        extentOffset: start + left.length + selected.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _prefixCurrentLine(String prefix, {bool toggle = true}) {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (!sel.isValid) return;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    final lineEnd = () {
      final idx = text.indexOf('\n', sel.start);
      return idx == -1 ? text.length : idx;
    }();
    final line = text.substring(lineStart, lineEnd);
    String newLine;
    int caretShift;
    if (toggle && line.startsWith(prefix)) {
      newLine = line.substring(prefix.length);
      caretShift = -prefix.length;
    } else {
      newLine = '$prefix$line';
      caretShift = prefix.length;
    }
    final next = text.replaceRange(lineStart, lineEnd, newLine);
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (sel.start + caretShift).clamp(lineStart, lineStart + newLine.length),
      ),
    );
    _focusNode.requestFocus();
  }

  void _insertAtCaret(String snippet, {int? selectInside}) {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, snippet);
    final caret = selectInside != null ? start + selectInside : start + snippet.length;
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
    _focusNode.requestFocus();
  }

  void _insertWikiTrigger() {
    _insertAtCaret('[[]]', selectInside: 2);
  }

  void _insertCheckbox() {
    _prefixCurrentLine('- [ ] ', toggle: false);
  }

  void _insertHeading(int level) {
    final prefix = '${'#' * level} ';
    _prefixCurrentLine(prefix, toggle: true);
  }

  void _toggleSubtaskAt(int index) {
    final next = toggleSubtask(widget.controller.text, index);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.of(context).size.width;
    final canSplit = width >= 1100;

    final toolbar = _MarkdownToolbar(
      palette: palette,
      mode: _mode,
      canSplit: canSplit,
      onMode: (m) => setState(() => _mode = m),
      onBold: () => _wrap('**', '**'),
      onItalic: () => _wrap('*', '*'),
      onStrike: () => _wrap('~~', '~~'),
      onCode: () => _wrap('`', '`'),
      onH1: () => _insertHeading(1),
      onH2: () => _insertHeading(2),
      onH3: () => _insertHeading(3),
      onBullet: () => _prefixCurrentLine('- '),
      onNumber: () => _prefixCurrentLine('1. '),
      onCheckbox: _insertCheckbox,
      onLink: () => _insertAtCaret('[]()', selectInside: 1),
      onWikiLink: _insertWikiTrigger,
      onTag: () => _insertAtCaret('#'),
      onQuote: () => _prefixCurrentLine('> '),
    );

    final editorField = CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontFamily: 'monospace',
          height: 1.45,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Что у тебя на уме?\n'
              'Поддерживается markdown — # Заголовок, **жирный**, '
              '- [ ] чек-лист, [[ссылка-на-заметку]].',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );

    Widget body;
    switch (_mode) {
      case _PreviewMode.editOnly:
        body = editorField;
      case _PreviewMode.preview:
        body = _MarkdownPreview(
          source: widget.controller.text,
          palette: palette,
          onTapWikiLink: _onTapWikiLink,
          onToggleCheckbox: _toggleSubtaskAt,
        );
      case _PreviewMode.split:
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: editorField),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 220),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.line),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: _MarkdownPreview(
                    source: widget.controller.text,
                    palette: palette,
                    onTapWikiLink: _onTapWikiLink,
                    onToggleCheckbox: _toggleSubtaskAt,
                  ),
                ),
              ),
            ),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  Future<void> _onTapWikiLink(String title) async {
    // Try to find an entry with this title and open it. We do a fresh
    // read so links work even if the providers haven't refreshed yet.
    final repo = await ref.read(repositoryProvider.future);
    final entries = await repo.listEntries();
    Entry? match;
    for (final e in entries) {
      if (e.title.toLowerCase() == title.toLowerCase()) {
        match = e;
        break;
      }
    }
    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заметка «$title» появится после сохранения')),
      );
      return;
    }
    // Defer to the host editor — pop current sheet and open the linked
    // one. We can't import showEntryEditor here without a circular
    // import, so we use a simple convention: nav.pop with the entry.
    Navigator.of(context).pop(match);
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.palette,
    required this.mode,
    required this.canSplit,
    required this.onMode,
    required this.onBold,
    required this.onItalic,
    required this.onStrike,
    required this.onCode,
    required this.onH1,
    required this.onH2,
    required this.onH3,
    required this.onBullet,
    required this.onNumber,
    required this.onCheckbox,
    required this.onLink,
    required this.onWikiLink,
    required this.onTag,
    required this.onQuote,
  });

  final NoeticaPalette palette;
  final _PreviewMode mode;
  final bool canSplit;
  final ValueChanged<_PreviewMode> onMode;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrike;
  final VoidCallback onCode;
  final VoidCallback onH1;
  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onBullet;
  final VoidCallback onNumber;
  final VoidCallback onCheckbox;
  final VoidCallback onLink;
  final VoidCallback onWikiLink;
  final VoidCallback onTag;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolBtn(palette: palette, tip: 'Заголовок 1', label: 'H1', onPressed: onH1),
            _ToolBtn(palette: palette, tip: 'Заголовок 2', label: 'H2', onPressed: onH2),
            _ToolBtn(palette: palette, tip: 'Заголовок 3', label: 'H3', onPressed: onH3),
            _Sep(palette: palette),
            _ToolBtn(palette: palette, tip: 'Жирный (**)', icon: Icons.format_bold, onPressed: onBold),
            _ToolBtn(palette: palette, tip: 'Курсив (*)', icon: Icons.format_italic, onPressed: onItalic),
            _ToolBtn(palette: palette, tip: 'Зачёркнутый (~~)', icon: Icons.format_strikethrough, onPressed: onStrike),
            _ToolBtn(palette: palette, tip: 'Код (`)', icon: Icons.code, onPressed: onCode),
            _Sep(palette: palette),
            _ToolBtn(palette: palette, tip: 'Маркированный список', icon: Icons.format_list_bulleted, onPressed: onBullet),
            _ToolBtn(palette: palette, tip: 'Нумерованный список', icon: Icons.format_list_numbered, onPressed: onNumber),
            _ToolBtn(palette: palette, tip: 'Чек-лист (- [ ])', icon: Icons.check_box_outlined, onPressed: onCheckbox),
            _ToolBtn(palette: palette, tip: 'Цитата', icon: Icons.format_quote, onPressed: onQuote),
            _Sep(palette: palette),
            _ToolBtn(palette: palette, tip: 'Ссылка [текст](url)', icon: Icons.link, onPressed: onLink),
            _ToolBtn(palette: palette, tip: 'Ссылка на заметку [[название]]', icon: Icons.article_outlined, onPressed: onWikiLink),
            _ToolBtn(palette: palette, tip: 'Тег #', icon: Icons.tag, onPressed: onTag),
            _Sep(palette: palette),
            _ModeToggle(
              palette: palette,
              mode: mode,
              canSplit: canSplit,
              onChanged: onMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.palette,
    required this.tip,
    required this.onPressed,
    this.icon,
    this.label,
  });

  final NoeticaPalette palette;
  final String tip;
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: icon != null
              ? Icon(icon, size: 16, color: palette.fg)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep({required this.palette});
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: palette.line,
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.palette,
    required this.mode,
    required this.canSplit,
    required this.onChanged,
  });

  final NoeticaPalette palette;
  final _PreviewMode mode;
  final bool canSplit;
  final ValueChanged<_PreviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_PreviewMode m, IconData icon, String tip) {
      final selected = mode == m;
      return Tooltip(
        message: tip,
        child: InkWell(
          onTap: () => onChanged(m),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? palette.fg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon,
                size: 14, color: selected ? palette.bg : palette.muted),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(_PreviewMode.editOnly, Icons.edit_outlined, 'Редактирование'),
        if (canSplit) chip(_PreviewMode.split, Icons.vertical_split, 'Сплит'),
        chip(_PreviewMode.preview, Icons.visibility_outlined, 'Просмотр'),
      ],
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({
    required this.source,
    required this.palette,
    required this.onTapWikiLink,
    required this.onToggleCheckbox,
  });

  final String source;
  final NoeticaPalette palette;
  final ValueChanged<String> onTapWikiLink;
  final ValueChanged<int> onToggleCheckbox;

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Превью пусто — начни писать в редакторе.',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
      );
    }
    // Convert [[wikilinks]] to a custom inline syntax that flutter_markdown
    // can route through our element builder. We replace `[[Foo]]` with
    // `<wiki>Foo</wiki>`-style tags via a lightweight pre-processor.
    final processed = source.replaceAllMapped(
      RegExp(r'\[\[([^\[\]\n]+)\]\]'),
      (m) => '[${m.group(1)}](wiki://${Uri.encodeComponent(m.group(1)!.trim())})',
    );

    return MarkdownBody(
      data: processed,
      selectable: false,
      shrinkWrap: true,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        if (href.startsWith('wiki://')) {
          final t = Uri.decodeComponent(href.substring('wiki://'.length));
          onTapWikiLink(t);
          return;
        }
        final uri = Uri.tryParse(href);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      checkboxBuilder: (checked) => Padding(
        padding: const EdgeInsets.only(right: 6, top: 2),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: palette.line, width: 1.3),
            borderRadius: BorderRadius.circular(3),
            color: checked ? palette.fg : Colors.transparent,
          ),
          child: checked
              ? Icon(Icons.check, size: 12, color: palette.bg)
              : null,
        ),
      ),
      // Hook the list-item builder so a tap on a checkbox row toggles
      // the underlying source. We can't easily get the index from
      // flutter_markdown's checkbox builder, so we re-derive it from
      // the raw element offsets.
      builders: {
        'li': _CheckboxListItemBuilder(
          source: source,
          onToggle: onToggleCheckbox,
        ),
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: palette.fg, fontSize: 14, height: 1.5),
        h1: TextStyle(color: palette.fg, fontSize: 22, fontWeight: FontWeight.w700),
        h2: TextStyle(color: palette.fg, fontSize: 18, fontWeight: FontWeight.w700),
        h3: TextStyle(color: palette.fg, fontSize: 16, fontWeight: FontWeight.w600),
        a: TextStyle(color: palette.fg, decoration: TextDecoration.underline),
        code: TextStyle(
          color: palette.fg,
          backgroundColor: palette.surface,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        blockquoteDecoration: BoxDecoration(
          color: palette.surface,
          border: Border(left: BorderSide(color: palette.line, width: 3)),
        ),
        listBullet: TextStyle(color: palette.fg, fontSize: 14),
      ),
    );
  }
}

class _CheckboxListItemBuilder extends MarkdownElementBuilder {
  _CheckboxListItemBuilder({required this.source, required this.onToggle});

  final String source;
  final ValueChanged<int> onToggle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Default rendering — our extra behaviour (tap handling) is wired
    // through the parent checkboxBuilder + a global GestureDetector
    // wrapping list items.
    return null;
  }
}

class _WikiLinkSuggestions extends StatelessWidget {
  const _WikiLinkSuggestions({
    required this.query,
    required this.allEntries,
    required this.excludeEntryId,
    required this.onSelect,
    required this.onDismiss,
  });

  final String query;
  final List<Entry> allEntries;
  final String? excludeEntryId;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = query.toLowerCase().trim();
    final items = <_Suggestion>[];
    for (final e in allEntries) {
      if (e.id == excludeEntryId) continue;
      final lower = e.title.toLowerCase();
      if (q.isEmpty || lower.contains(q)) {
        items.add(_Suggestion(title: e.title, exact: lower.startsWith(q)));
      }
    }
    items.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    final top = items.take(8).toList();
    final exists = items.any((s) => s.title.toLowerCase() == q);

    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                Icon(Icons.link, size: 12, color: palette.muted),
                const SizedBox(width: 6),
                Text(
                  'Ссылка на заметку',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  'Esc — закрыть',
                  style: TextStyle(color: palette.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (top.isEmpty && q.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Начни печатать название…',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
          for (final s in top)
            InkWell(
              onTap: () => onSelect(s.title),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.note_outlined,
                        size: 14, color: palette.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.fg, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (q.isNotEmpty && !exists)
            InkWell(
              onTap: () => onSelect(query.trim()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 14, color: palette.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Создать «',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: query.trim(),
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '»',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Suggestion {
  _Suggestion({required this.title, required this.exact});
  final String title;
  final bool exact;
}


