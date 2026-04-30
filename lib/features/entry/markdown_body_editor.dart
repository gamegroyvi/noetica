// WYSIWYG markdown editor for entry bodies.
//
// Source of truth is plain markdown — this widget renders formatted
// text inline (bold, italic, strikethrough, headings, wiki-links, etc.)
// while hiding the raw markdown markers so the user sees only the
// styled result. A compact toolbar inserts markdown syntax.
//
// Wiki-link `[[…]]` autocomplete appears as an inline suggestion list
// below the text field when the user types `[[`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// Inline syntax matched by [_buildMarkdownLineSpans].
final RegExp _inlineMarkdownRegex = RegExp(
  r'(\*\*(?:[^*\n]|\*(?!\*))+\*\*)' // 1: **bold**
  r'|(\*(?:[^*\n])+\*)' // 2: *italic*
  r'|(~~(?:[^~\n])+~~)' // 3: ~~strike~~
  r'|(`[^`\n]+`)' // 4: `code`
  r'|(\[\[[^\[\]\n]+\]\])' // 5: [[wiki]]
  r'|(\[[^\[\]\n]+\]\([^\s)]+\))' // 6: [text](url)
  r'|(?<=^|[\s(])(#[\p{L}\d_-]+)', // 7: #tag
  unicode: true,
);

/// Render markdown source [text] as a single TextSpan tree.
///
/// Markdown markers are rendered as zero-width transparent spans so the
/// underlying string is preserved character-for-character — this lets
/// the same builder feed both an editable [TextField] (where caret /
/// selection require span text to match `controller.text`) and a
/// read-only `Text.rich` preview in cards / lists.
///
/// The output therefore never adds or removes characters; we only
/// re-style ranges of the input.
TextSpan buildMarkdownTextSpan({
  required String text,
  required TextStyle base,
  required NoeticaPalette palette,
}) {
  final dim = base.copyWith(
    color: palette.muted,
    fontWeight: FontWeight.w400,
  );
  // Markdown marker style: near-zero font size + transparent color.
  // Characters survive in the text for parsing but take no visual
  // space, hiding `**`, `# `, `> `, `- [ ] `, etc. from the user.
  final marker = base.copyWith(
    fontSize: 0.01,
    color: Colors.transparent,
  );
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    _buildMarkdownLineSpans(
      line: lines[i],
      base: base,
      dim: dim,
      marker: marker,
      palette: palette,
      out: spans,
    );
    if (i < lines.length - 1) {
      spans.add(TextSpan(text: '\n', style: base));
    }
  }
  return TextSpan(style: base, children: spans);
}

void _buildMarkdownLineSpans({
  required String line,
  required TextStyle base,
  required TextStyle dim,
  required TextStyle marker,
  required NoeticaPalette palette,
  required List<InlineSpan> out,
}) {
  if (line.isEmpty) return;

  // Heading: `#`, `##`, `###` + space
  final heading = RegExp(r'^(#{1,3}) ').firstMatch(line);
  if (heading != null) {
    final level = heading.group(1)!.length;
    final headingStyle = base.copyWith(
      fontSize: switch (level) { 1 => 22.0, 2 => 19.0, _ => 16.0 },
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    out.add(TextSpan(text: heading.group(0), style: marker));
    _applyInlineMarkdown(
      text: line.substring(heading.end),
      base: headingStyle,
      dim: dim,
      marker: marker,
      palette: palette,
      out: out,
    );
    return;
  }

  // Blockquote: `> ` — marker hidden, body italic + muted.
  if (line.startsWith('> ')) {
    final quoteStyle = base.copyWith(
      fontStyle: FontStyle.italic,
      color: palette.muted,
    );
    out.add(TextSpan(text: '> ', style: marker));
    _applyInlineMarkdown(
      text: line.substring(2),
      base: quoteStyle,
      dim: dim,
      marker: marker,
      palette: palette,
      out: out,
    );
    return;
  }

  // Task item: `- [ ] ` / `- [x] ` — markers hidden so the user reads
  // only the task text. Strike-through is the visual cue for completed
  // tasks. Real interactive checkboxes live in the task list / card.
  final task = RegExp(r'^(\s*)- \[( |x|X)\] ').firstMatch(line);
  if (task != null) {
    final indent = task.group(1) ?? '';
    final done = task.group(2)!.toLowerCase() == 'x';
    out.add(TextSpan(text: indent, style: base));
    out.add(TextSpan(text: '- [${done ? 'x' : ' '}] ', style: marker));
    final content = line.substring(task.end);
    final contentStyle = done
        ? base.copyWith(
            decoration: TextDecoration.lineThrough,
            color: palette.muted,
          )
        : base;
    _applyInlineMarkdown(
      text: content,
      base: contentStyle,
      dim: dim,
      marker: marker,
      palette: palette,
      out: out,
    );
    return;
  }

  // Unordered list item: `- ` / `* ` / `+ ` — marker hidden.
  final bullet = RegExp(r'^(\s*)([-*+]) ').firstMatch(line);
  if (bullet != null) {
    out.add(TextSpan(text: bullet.group(1), style: base));
    out.add(TextSpan(text: '${bullet.group(2)} ', style: marker));
    _applyInlineMarkdown(
      text: line.substring(bullet.end),
      base: base,
      dim: dim,
      marker: marker,
      palette: palette,
      out: out,
    );
    return;
  }

  // Ordered list item: `1. ` — digit kept (it's the index), dot+space
  // hidden.
  final ordered = RegExp(r'^(\s*)(\d+)\. ').firstMatch(line);
  if (ordered != null) {
    out.add(TextSpan(text: ordered.group(1), style: base));
    out.add(TextSpan(
      text: ordered.group(2)!,
      style: base.copyWith(
        color: palette.muted,
        fontWeight: FontWeight.w600,
      ),
    ));
    out.add(TextSpan(text: '. ', style: marker));
    _applyInlineMarkdown(
      text: line.substring(ordered.end),
      base: base,
      dim: dim,
      marker: marker,
      palette: palette,
      out: out,
    );
    return;
  }

  _applyInlineMarkdown(
    text: line,
    base: base,
    dim: dim,
    marker: marker,
    palette: palette,
    out: out,
  );
}

void _applyInlineMarkdown({
  required String text,
  required TextStyle base,
  required TextStyle dim,
  required TextStyle marker,
  required NoeticaPalette palette,
  required List<InlineSpan> out,
}) {
  var cursor = 0;
  for (final m in _inlineMarkdownRegex.allMatches(text)) {
    if (m.start > cursor) {
      out.add(TextSpan(text: text.substring(cursor, m.start), style: base));
    }
    final match = m.group(0)!;
    if (m.group(1) != null) {
      // **bold** — hide markers
      final inner = match.substring(2, match.length - 2);
      out.add(TextSpan(text: '**', style: marker));
      out.add(TextSpan(
        text: inner,
        style: base.copyWith(fontWeight: FontWeight.w700),
      ));
      out.add(TextSpan(text: '**', style: marker));
    } else if (m.group(2) != null) {
      // *italic* — hide markers
      final inner = match.substring(1, match.length - 1);
      out.add(TextSpan(text: '*', style: marker));
      out.add(TextSpan(
        text: inner,
        style: base.copyWith(fontStyle: FontStyle.italic),
      ));
      out.add(TextSpan(text: '*', style: marker));
    } else if (m.group(3) != null) {
      // ~~strike~~ — hide markers
      final inner = match.substring(2, match.length - 2);
      out.add(TextSpan(text: '~~', style: marker));
      out.add(TextSpan(
        text: inner,
        style: base.copyWith(decoration: TextDecoration.lineThrough),
      ));
      out.add(TextSpan(text: '~~', style: marker));
    } else if (m.group(4) != null) {
      // `code` — hide markers
      final inner = match.substring(1, match.length - 1);
      out.add(TextSpan(text: '`', style: marker));
      out.add(TextSpan(
        text: inner,
        style: base.copyWith(
          fontFamily: 'monospace',
          backgroundColor: palette.surface,
        ),
      ));
      out.add(TextSpan(text: '`', style: marker));
    } else if (m.group(5) != null) {
      // [[wiki]] — hide brackets, underline content
      final inner = match.substring(2, match.length - 2);
      out.add(TextSpan(text: '[[', style: marker));
      out.add(TextSpan(
        text: inner,
        style: base.copyWith(
          color: palette.fg,
          decoration: TextDecoration.underline,
          decorationColor: palette.muted,
        ),
      ));
      out.add(TextSpan(text: ']]', style: marker));
    } else if (m.group(6) != null) {
      // [text](url) — hide brackets and url, underline text
      final closeBracket = match.indexOf(']');
      final linkText = match.substring(1, closeBracket);
      out.add(TextSpan(text: '[', style: marker));
      out.add(TextSpan(
        text: linkText,
        style: base.copyWith(
          color: palette.fg,
          decoration: TextDecoration.underline,
          decorationColor: palette.muted,
        ),
      ));
      // The URL portion `](https://…)` is hidden so the user sees
      // just the link text. We start at `closeBracket` (inclusive)
      // so the closing `]` is also hidden — otherwise the rendered
      // text would skip a character vs `controller.text`.
      out.add(TextSpan(text: match.substring(closeBracket), style: marker));
    } else if (m.group(7) != null) {
      // #tag
      out.add(TextSpan(
        text: match,
        style: base.copyWith(
          color: palette.fg,
          fontWeight: FontWeight.w600,
          backgroundColor: palette.surface,
        ),
      ));
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    out.add(TextSpan(text: text.substring(cursor), style: base));
  }
}

/// TextEditingController that renders markdown as WYSIWYG.
///
/// Markers (`**`, `*`, `~~`, `` ` ``, `[[`, `]]`, `#`-heading prefixes,
/// `- [ ]` task markers, `- ` bullets, `> ` blockquotes) are rendered
/// as zero-size transparent spans so the user sees only the formatted
/// content. The underlying text stays plain markdown.
class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text, required this.palette});

  NoeticaPalette palette;

  void setPalette(NoeticaPalette p) {
    if (p.fg == palette.fg && p.muted == palette.muted) return;
    palette = p;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildMarkdownTextSpan(
      text: text,
      base: style ?? const TextStyle(),
      palette: palette,
    );
  }
}

/// Read-only widget that renders entry-body markdown using the same
/// span builder as the editor. Use this in cards / lists so the user
/// sees `**bold**` actually rendered bold (no special characters
/// leaking through), and inline `[[wiki]]` / tags / strike-through all
/// keep their formatting in the preview.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.body,
    this.style,
    this.maxLines,
    this.color,
  });

  final String body;
  final TextStyle? style;
  final int? maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    var base = style ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    if (color != null) {
      base = base.copyWith(color: color);
    }
    return Text.rich(
      buildMarkdownTextSpan(text: body, base: base, palette: palette),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// WYSIWYG markdown editor widget.
class MarkdownBodyEditor extends ConsumerStatefulWidget {
  const MarkdownBodyEditor({
    super.key,
    required this.controller,
    required this.entryId,
    this.hintText,
    this.minLines = 6,
    this.maxLines = 14,
    this.expand = false,
    this.fontSize = 14,
  });

  final TextEditingController controller;
  final String? entryId;
  final String? hintText;
  final int minLines;
  final int maxLines;

  /// When true the inner [TextField] uses `expands: true` and the
  /// editor fills all the vertical space its parent gives it — used by
  /// the full-screen "document mode" so the body looks like a Word
  /// page, not a 14-line text box. Caller must wrap this widget in a
  /// box with bounded height (e.g. [Expanded] inside a [Column]).
  final bool expand;

  /// Base font size for the body. The full-screen view uses a slightly
  /// larger size so longer prose reads more like a document.
  final double fontSize;

  @override
  ConsumerState<MarkdownBodyEditor> createState() =>
      _MarkdownBodyEditorState();
}

class _MarkdownBodyEditorState extends ConsumerState<MarkdownBodyEditor> {
  final _focusNode = FocusNode();
  String _wikiQuery = '';
  int _wikiTriggerStart = -1;
  bool _showingSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      if (_showingSuggestions) setState(() => _showingSuggestions = false);
      return;
    }
    final caret = sel.baseOffset;
    final text = widget.controller.text;
    int? trigger;
    for (var i = caret - 1; i >= 0 && caret - i < 40; i--) {
      final c = text[i];
      if (c == '\n') break;
      if (i + 1 < text.length && text.substring(i, i + 2) == ']]') break;
      if (i - 1 >= 0 && text.substring(i - 1, i + 1) == '[[') {
        trigger = i + 1;
        break;
      }
    }
    if (trigger == null) {
      if (_showingSuggestions) setState(() => _showingSuggestions = false);
      return;
    }
    final query = text.substring(trigger, caret);
    if (query.contains('\n')) {
      if (_showingSuggestions) setState(() => _showingSuggestions = false);
      return;
    }
    setState(() {
      _wikiQuery = query;
      _wikiTriggerStart = trigger!;
      _showingSuggestions = true;
    });
  }

  void _insertWikiLink(String title) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    if (_wikiTriggerStart < 0 || _wikiTriggerStart > text.length) {
      setState(() => _showingSuggestions = false);
      return;
    }
    int end = ctrl.selection.baseOffset;
    if (end < _wikiTriggerStart) {
      final nl = text.indexOf('\n', _wikiTriggerStart);
      end = nl == -1 ? text.length : nl;
    }
    final replacement = '$title]] ';
    final next = text.replaceRange(_wikiTriggerStart, end, replacement);
    final newCaret = _wikiTriggerStart + replacement.length;
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    setState(() => _showingSuggestions = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
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
    final lineStart =
        sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
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
        offset: (sel.start + caretShift)
            .clamp(lineStart, lineStart + newLine.length),
      ),
    );
    _focusNode.requestFocus();
  }

  void _toggleCheckboxOnCurrentLine() {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    if (!sel.isValid) return;
    final lineStart =
        sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
    final lineEnd = () {
      final idx = text.indexOf('\n', sel.start);
      return idx == -1 ? text.length : idx;
    }();
    final line = text.substring(lineStart, lineEnd);
    final taskMatch = RegExp(r'^(\s*)- \[( |x|X)\] ').firstMatch(line);
    String newLine;
    int caretShift;
    if (taskMatch != null) {
      // Already a task — flip checked state.
      final indent = taskMatch.group(1) ?? '';
      final wasDone = taskMatch.group(2)!.toLowerCase() == 'x';
      newLine =
          '$indent- [${wasDone ? ' ' : 'x'}] ${line.substring(taskMatch.end)}';
      caretShift = 0;
    } else {
      // Plain line — promote to task.
      newLine = '- [ ] $line';
      caretShift = 6;
    }
    final next = text.replaceRange(lineStart, lineEnd, newLine);
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (sel.start + caretShift)
            .clamp(lineStart, lineStart + newLine.length),
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
    final caret =
        selectInside != null ? start + selectInside : start + snippet.length;
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
    _focusNode.requestFocus();
  }

  void _insertWikiTrigger() {
    _insertAtCaret('[[]]', selectInside: 2);
  }

  void _insertHeading(int level) {
    final prefix = '${'#' * level} ';
    _prefixCurrentLine(prefix, toggle: true);
  }


  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final toolbar = _MarkdownToolbar(
      palette: palette,
      onBold: () => _wrap('**', '**'),
      onItalic: () => _wrap('*', '*'),
      onStrike: () => _wrap('~~', '~~'),
      onCode: () => _wrap('`', '`'),
      onH1: () => _insertHeading(1),
      onH2: () => _insertHeading(2),
      onH3: () => _insertHeading(3),
      onBullet: () => _prefixCurrentLine('- '),
      onNumber: () => _prefixCurrentLine('1. '),
      onCheckbox: _toggleCheckboxOnCurrentLine,
      onLink: () => _insertAtCaret('[]()', selectInside: 1),
      onWikiLink: _insertWikiTrigger,
      onTag: () => _insertAtCaret('#'),
      onQuote: () => _prefixCurrentLine('> '),
    );

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      // `expands: true` requires both line counts to be null. Switching
      // between bounded ("sheet") and document ("full-screen") modes is
      // the whole reason this flag exists — see [MarkdownBodyEditor.expand].
      minLines: widget.expand ? null : widget.minLines,
      maxLines: widget.expand ? null : widget.maxLines,
      expands: widget.expand,
      textAlignVertical: TextAlignVertical.top,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      style: TextStyle(height: 1.5, fontSize: widget.fontSize),
      decoration: InputDecoration(
        hintText: widget.hintText ??
            'Что у тебя на уме?\n'
                'Форматирование: жирный, курсив, заголовки, '
                'чек-листы, [[ссылки на заметки]].',
        alignLabelWithHint: true,
        // In full-screen "document mode" the field has to paint its
        // border around the entire scrolling area, otherwise the
        // border collapses to a thin strip at the top.
        border: widget.expand
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.line),
              )
            : null,
        enabledBorder: widget.expand
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.line),
              )
            : null,
        focusedBorder: widget.expand
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.fg, width: 1.4),
              )
            : null,
        contentPadding: widget.expand
            ? const EdgeInsets.fromLTRB(20, 18, 20, 18)
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        const SizedBox(height: 8),
        if (widget.expand) Expanded(child: field) else field,
        if (_showingSuggestions)
          _WikiLinkSuggestions(
            query: _wikiQuery,
            excludeEntryId: widget.entryId,
            onSelect: _insertWikiLink,
            onDismiss: () => setState(() => _showingSuggestions = false),
          ),
      ],
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.palette,
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
            _ToolBtn(palette: palette, tip: 'Жирный', icon: Icons.format_bold, onPressed: onBold),
            _ToolBtn(palette: palette, tip: 'Курсив', icon: Icons.format_italic, onPressed: onItalic),
            _ToolBtn(palette: palette, tip: 'Зачёркнутый', icon: Icons.format_strikethrough, onPressed: onStrike),
            _ToolBtn(palette: palette, tip: 'Код', icon: Icons.code, onPressed: onCode),
            _Sep(palette: palette),
            _ToolBtn(palette: palette, tip: 'Маркированный список', icon: Icons.format_list_bulleted, onPressed: onBullet),
            _ToolBtn(palette: palette, tip: 'Нумерованный список', icon: Icons.format_list_numbered, onPressed: onNumber),
            _ToolBtn(palette: palette, tip: 'Чек-лист', icon: Icons.check_box_outlined, onPressed: onCheckbox),
            _ToolBtn(palette: palette, tip: 'Цитата', icon: Icons.format_quote, onPressed: onQuote),
            _Sep(palette: palette),
            _ToolBtn(palette: palette, tip: 'Ссылка', icon: Icons.link, onPressed: onLink),
            _ToolBtn(palette: palette, tip: 'Ссылка на заметку', icon: Icons.article_outlined, onPressed: onWikiLink),
            _ToolBtn(palette: palette, tip: 'Тег', icon: Icons.tag, onPressed: onTag),
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

/// Inline wiki-link suggestions rendered below the text field.
class _WikiLinkSuggestions extends ConsumerWidget {
  const _WikiLinkSuggestions({
    required this.query,
    required this.excludeEntryId,
    required this.onSelect,
    required this.onDismiss,
  });

  final String query;
  final String? excludeEntryId;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entries =
        ref.watch(entriesProvider).valueOrNull ?? const <Entry>[];
    final q = query.toLowerCase().trim();
    final items = <_Suggestion>[];
    for (final e in entries) {
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
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(Icons.close, size: 14, color: palette.muted),
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
