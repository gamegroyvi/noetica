// Unit tests for `LiveMarkdownController` — verifies that markdown
// syntax produces styled inline spans without mutating the raw text.
// This is what lets users see rendered formatting while the source of
// truth stays plain markdown (no block-tree JSON migration needed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/features/entry/markdown_body_editor.dart';
import 'package:noetica/theme/app_theme.dart';

const _palette = NoeticaPalette(
  fg: Color(0xFF000000),
  bg: Color(0xFFFFFFFF),
  surface: Color(0xFFF2F2F2),
  muted: Color(0xFF888888),
  line: Color(0xFFCCCCCC),
);

/// Walk every nested TextSpan and collect the concrete text.
List<(String, TextStyle?)> _flatten(InlineSpan span) {
  final out = <(String, TextStyle?)>[];
  span.visitChildren((child) {
    if (child is TextSpan && child.text != null) {
      out.add((child.text!, child.style));
    }
    return true;
  });
  return out;
}

void main() {
  // Need binding because buildTextSpan calls MediaQuery via default
  // TextStyle resolution in some code paths.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveMarkdownController.buildTextSpan', () {
    late BuildContext ctx;

    Future<void> withContext(WidgetTester tester, VoidCallback body) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ));
      body();
    }

    testWidgets('keeps underlying text untouched', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: '**bold** and *italic* and [[wiki]]',
        palette: _palette,
      );
      expect(c.text, '**bold** and *italic* and [[wiki]]');
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final joined = _flatten(span).map((p) => p.$1).join();
      // Reconstructed text from spans should equal the raw source
      // so the caret never desyncs.
      expect(joined, '**bold** and *italic* and [[wiki]]');
    });

    testWidgets('bold markers rendered dim, inner text bold', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: '**hello**',
        palette: _palette,
      );
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
        withComposing: false,
      );
      final parts = _flatten(span);
      final helloSpan = parts.firstWhere((p) => p.$1 == 'hello');
      expect(helloSpan.$2?.fontWeight, FontWeight.w700);
      final markerSpans = parts.where((p) => p.$1 == '**').toList();
      expect(markerSpans, hasLength(2));
      expect(markerSpans.first.$2?.color, _palette.muted);
    });

    testWidgets('heading sized up, hash dim', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: '## Section',
        palette: _palette,
      );
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final parts = _flatten(span);
      final hash = parts.firstWhere((p) => p.$1 == '## ');
      expect(hash.$2?.color, _palette.muted);
      final body = parts.firstWhere((p) => p.$1 == 'Section');
      expect(body.$2?.fontSize, 19.0);
      expect(body.$2?.fontWeight, FontWeight.w700);
    });

    testWidgets('wiki link inner text styled, brackets dim', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: 'see [[Alpha]] there',
        palette: _palette,
      );
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final parts = _flatten(span);
      expect(parts.where((p) => p.$1 == '[[').length, 1);
      expect(parts.where((p) => p.$1 == ']]').length, 1);
      final alpha = parts.firstWhere((p) => p.$1 == 'Alpha');
      expect(alpha.$2?.decoration, TextDecoration.underline);
    });

    testWidgets('task item marker dim, checked item strike-through',
        (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: '- [x] done\n- [ ] todo',
        palette: _palette,
      );
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final parts = _flatten(span);
      final done = parts.firstWhere((p) => p.$1 == 'done');
      expect(done.$2?.decoration, TextDecoration.lineThrough);
      final todo = parts.firstWhere((p) => p.$1 == 'todo');
      expect(todo.$2?.decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('#tag highlighted', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(
        text: 'a #project b',
        palette: _palette,
      );
      final span = c.buildTextSpan(
        context: ctx,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final parts = _flatten(span);
      final tag = parts.firstWhere((p) => p.$1 == '#project');
      expect(tag.$2?.fontWeight, FontWeight.w600);
    });

    testWidgets('palette swap triggers listener', (t) async {
      await withContext(t, () {});
      final c = LiveMarkdownController(text: 'x', palette: _palette);
      var fired = 0;
      c.addListener(() => fired++);
      c.setPalette(_palette); // same palette → no-op
      expect(fired, 0);
      c.setPalette(const NoeticaPalette(
        fg: Color(0xFFFFFFFF),
        bg: Color(0xFF000000),
        surface: Color(0xFF0A0A0A),
        muted: Color(0xFFAAAAAA),
        line: Color(0xFF222222),
      ));
      expect(fired, 1);
    });
  });
}
