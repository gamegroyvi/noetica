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
  if (body.isEmpty) return '';

  // 1. Legacy Delta JSON → extract insert strings.
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
      return _stripMarkdown(buf.toString().trim());
    } catch (_) {
      // Not valid JSON — fall through to markdown stripping.
    }
  }

  // 2. Plain markdown — strip markers.
  return _stripMarkdown(body);
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
  s = s.replaceAll(RegExp(r'^(\s*)- \[[ xX]\]\s?', multiLine: true), r'$1');
  // Bullet markers: - / * / +
  s = s.replaceAll(RegExp(r'^(\s*)[-*+]\s', multiLine: true), r'$1');
  return s.trim();
}
