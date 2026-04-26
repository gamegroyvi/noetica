// Parsing + mutation helpers for markdown checkbox subtasks embedded in
// an entry's body text (`- [ ] …` / `- [x] …`). We keep the subtasks in
// the body rather than adding a dedicated DB column so we don't have to
// change the sync schema — the source of truth is still plain
// markdown, we just render it as real checkboxes.

/// A single parsed subtask line.
class Subtask {
  const Subtask({
    required this.lineIndex,
    required this.checked,
    required this.text,
    required this.raw,
  });

  /// 0-based index of the line in the source body.
  final int lineIndex;

  /// Whether the checkbox is marked (`[x]`).
  final bool checked;

  /// Trimmed text after the checkbox marker.
  final String text;

  /// The raw source line (including the marker + indentation) — useful
  /// when we need to rewrite just this line without touching the rest.
  final String raw;
}

/// Matches a markdown task list bullet, e.g. `  - [ ] buy groceries`.
final RegExp _subtaskLine = RegExp(
  r'^(\s*[-*]\s*)\[([ xX])\]\s*(.*)$',
);

/// Extract every checkbox subtask line from [body], preserving order.
List<Subtask> parseSubtasks(String body) {
  if (body.isEmpty) return const [];
  final out = <Subtask>[];
  final lines = body.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final m = _subtaskLine.firstMatch(lines[i]);
    if (m == null) continue;
    final mark = m.group(2) ?? ' ';
    final text = (m.group(3) ?? '').trim();
    out.add(Subtask(
      lineIndex: i,
      checked: mark.toLowerCase() == 'x',
      text: text,
      raw: lines[i],
    ));
  }
  return out;
}

/// True when [body] contains at least one markdown checkbox line.
bool hasSubtasks(String body) => parseSubtasks(body).isNotEmpty;

/// `(done, total)` counts for the checkbox list embedded in [body].
({int done, int total}) subtaskProgress(String body) {
  final subs = parseSubtasks(body);
  var done = 0;
  for (final s in subs) {
    if (s.checked) done++;
  }
  return (done: done, total: subs.length);
}

/// Flip the [index]-th subtask (by position in `parseSubtasks`) and
/// return the updated body. No-op when the index is out of range.
String toggleSubtask(String body, int index) {
  final subs = parseSubtasks(body);
  if (index < 0 || index >= subs.length) return body;
  final target = subs[index];
  final lines = body.split('\n');
  final m = _subtaskLine.firstMatch(lines[target.lineIndex]);
  if (m == null) return body;
  final prefix = m.group(1) ?? '- ';
  final text = m.group(3) ?? '';
  final newMark = target.checked ? ' ' : 'x';
  lines[target.lineIndex] = '$prefix[$newMark] $text'.trimRight();
  return lines.join('\n');
}

/// Body text with every subtask line stripped — used for "plain preview"
/// rendering in task tiles where the checklist is shown separately.
String stripSubtasks(String body) {
  if (body.isEmpty) return body;
  final kept = <String>[];
  for (final line in body.split('\n')) {
    if (_subtaskLine.hasMatch(line)) continue;
    kept.add(line);
  }
  return kept.join('\n').trim();
}
