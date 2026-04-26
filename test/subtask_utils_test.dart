import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/utils/subtask_utils.dart';

/// Unit tests for the markdown checkbox parser that surfaces LLM
/// roadmap subtasks as real, tickable items in the UI.
void main() {
  group('parseSubtasks', () {
    test('returns empty list for bodies without checkbox lines', () {
      expect(parseSubtasks(''), isEmpty);
      expect(parseSubtasks('just some prose\nwith multiple lines'), isEmpty);
      expect(parseSubtasks('- bullet\n- another bullet'), isEmpty);
    });

    test('parses unchecked and checked checkboxes', () {
      const body = '- [ ] Первое дело\n- [x] Сделано\n- [X] И это тоже';
      final subs = parseSubtasks(body);
      expect(subs, hasLength(3));
      expect(subs[0].checked, isFalse);
      expect(subs[0].text, 'Первое дело');
      expect(subs[1].checked, isTrue);
      expect(subs[1].text, 'Сделано');
      expect(subs[2].checked, isTrue);
    });

    test('tolerates leading whitespace and asterisk bullets', () {
      const body = '  - [ ] indented\n* [x] asterisk';
      final subs = parseSubtasks(body);
      expect(subs, hasLength(2));
      expect(subs[0].text, 'indented');
      expect(subs[1].checked, isTrue);
    });

    test('mixes prose and checkboxes in a single body', () {
      const body = 'Short intro\n\n- [ ] one\n- [ ] two\n\nOutro';
      final subs = parseSubtasks(body);
      expect(subs, hasLength(2));
      expect(subs.map((s) => s.lineIndex), [2, 3]);
    });
  });

  group('subtaskProgress', () {
    test('counts done vs total', () {
      const body = '- [ ] a\n- [x] b\n- [ ] c';
      final p = subtaskProgress(body);
      expect(p.done, 1);
      expect(p.total, 3);
    });

    test('returns (0,0) when no checkboxes', () {
      final p = subtaskProgress('no boxes here');
      expect(p.done, 0);
      expect(p.total, 0);
    });
  });

  group('toggleSubtask', () {
    test('flips unchecked -> checked', () {
      const body = '- [ ] make tea';
      final after = toggleSubtask(body, 0);
      expect(parseSubtasks(after).first.checked, isTrue);
    });

    test('flips checked -> unchecked', () {
      const body = '- [x] make tea';
      final after = toggleSubtask(body, 0);
      expect(parseSubtasks(after).first.checked, isFalse);
    });

    test('does not mangle surrounding prose lines', () {
      const body = 'Intro\n- [ ] step one\nMiddle\n- [ ] step two\nOutro';
      final after = toggleSubtask(body, 1);
      final lines = after.split('\n');
      expect(lines[0], 'Intro');
      expect(lines[2], 'Middle');
      expect(lines[4], 'Outro');
      final subs = parseSubtasks(after);
      expect(subs[0].checked, isFalse);
      expect(subs[1].checked, isTrue);
    });

    test('no-ops on out-of-range index', () {
      const body = '- [ ] only';
      expect(toggleSubtask(body, 5), body);
      expect(toggleSubtask(body, -1), body);
    });
  });

  group('stripSubtasks', () {
    test('removes checkbox lines and keeps prose', () {
      const body = 'intro\n\n- [ ] one\n- [x] two\n\noutro';
      final stripped = stripSubtasks(body);
      expect(stripped, contains('intro'));
      expect(stripped, contains('outro'));
      expect(stripped, isNot(contains('[ ]')));
      expect(stripped, isNot(contains('[x]')));
    });

    test('returns empty when body is all checkboxes', () {
      expect(stripSubtasks('- [ ] a\n- [ ] b'), isEmpty);
    });
  });
}
