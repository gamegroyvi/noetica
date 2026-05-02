import 'dart:convert';

/// Extract plain text from an entry body for display in cards/lists.
///
/// The body may be:
///   1. Legacy Quill Delta JSON (starts with `[`)
///   2. Plain markdown
///
/// Delta JSON is parsed and text extracted. Markdown syntax markers
/// (`**`, `*`, `~~`, `` ` ``, `#`, `[[`, `]]`, `- [ ]`, etc.) are
/// stripped so the card shows clean readable text.
String bodyToPlainText(String body) {
  return _stripMarkdown(stripDisplayMetadata(bodyToMarkdown(body)));
}

/// Strip metadata HTML comments (e.g. `<!-- noetica:meal {...} -->`) from
/// a markdown body before rendering. The comments are kept in storage so
/// downstream tooling can still find them, but they look like raw text in
/// the renderer (which doesn't understand HTML), so we hide whole comment
/// lines from any user-facing preview / card / live-overlay.
///
/// Only standalone-line comments are stripped. Inline comments (rare) are
/// left alone to avoid silently joining surrounding words.
String stripDisplayMetadata(String body) {
  if (body.isEmpty) return body;
  // Match a comment that occupies a whole line (optionally with leading /
  // trailing horizontal whitespace), then consume the trailing newline so
  // the comment line collapses cleanly without leaving an empty gap.
  final pattern = RegExp(
    r'(^|\n)[ \t]*<!--[\s\S]*?-->[ \t]*\n?',
  );
  return body.replaceAllMapped(pattern, (m) => m.group(1) ?? '');
}

/// Normalise an entry body to plain markdown.
///
/// Legacy bodies may be stored as Quill Delta JSON; this helper
/// returns the markdown source either as-is (already markdown) or
/// reconstructed from the Delta `insert` strings, so downstream
/// renderers (cards, previews, the WYSIWYG editor) can rely on a
/// single shape.
String bodyToMarkdown(String body) {
  if (body.isEmpty) return '';
  if (body.startsWith('[')) {
    try {
      final json = jsonDecode(body) as List;
      final buf = StringBuffer();
      for (final op in json) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) buf.write(insert);
        }
      }
      return buf.toString();
    } catch (_) {
      // Not valid JSON — treat as plain markdown.
    }
  }
  return body;
}

/// Remove common markdown markers from [text] for card display.
String _stripMarkdown(String text) {
  var s = text;
  // Wiki links: [[title]] → title
  s = s.replaceAllMapped(RegExp(r'\[\[([^\]]+)\]\]'), (m) => m.group(1)!);
  // Markdown links: [text](url) → text
  s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1)!);
  // Bold: **text** → text
  s = s.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
  // Italic: *text* → text
  s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!);
  // Strikethrough: ~~text~~ → text
  s = s.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1)!);
  // Inline code: `text` → text
  s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
  // Heading prefixes: # / ## / ###
  s = s.replaceAll(RegExp(r'^#{1,3}\s+', multiLine: true), '');
  // Blockquote prefix
  s = s.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
  // Checkbox markers: - [ ] / - [x]
  s = s.replaceAllMapped(
      RegExp(r'^(\s*)- \[[ xX]\]\s?', multiLine: true),
      (m) => m.group(1) ?? '');
  // Bullet markers: - / * / +
  s = s.replaceAllMapped(
      RegExp(r'^(\s*)[-*+]\s', multiLine: true),
      (m) => m.group(1) ?? '');
  return s.trim();
}
