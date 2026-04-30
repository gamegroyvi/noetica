// Unit tests for `LiveMarkdownController` and `buildMarkdownTextSpan`.
//
// These guard the WYSIWYG invariant: markdown markers (**, *, ~~,
// `, [[…]], # / ##, > , - / 1. , - [ ] / - [x] ) all render as
// zero-size + transparent spans so the user sees only the formatted
// content while the underlying string stays as plain markdown — no
// caret/selection desync inside an editable TextField.
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

const _baseStyle = TextStyle(fontSize: 14, color: Color(0xFF111111));

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

bool _isInvisible(TextStyle? s) =>
    s != null && s.color == Colors.transparent && s.fontSize == 0.01;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildMarkdownTextSpan — text invariant', () {
    test('reconstructed text equals raw source for inline mix', () {
      const src = '**bold** and *italic* and ~~struck~~ and `code` and [[wiki]]';
      final span = buildMarkdownTextSpan(
        text: src,
        base: _baseStyle,
        palette: _palette,
      );
      expect(_flatten(span).map((p) => p.$1).join(), src);
    });

    test('reconstructed text equals raw source for multiline blocks', () {
      const src = '# Heading\n\n'
          '> quote\n\n'
          '- bullet one\n'
          '* bullet two\n'
          '1. ordered\n\n'
          '- [ ] todo\n'
          '- [x] done';
      final span = buildMarkdownTextSpan(
        text: src,
        base: _baseStyle,
        palette: _palette,
      );
      expect(_flatten(span).map((p) => p.$1).join(), src);
    });

    test('handles empty body without throwing', () {
      final span = buildMarkdownTextSpan(
        text: '',
        base: _baseStyle,
        palette: _palette,
      );
      expect(_flatten(span), isEmpty);
    });
  });

  group('buildMarkdownTextSpan — markers are invisible', () {
    test('** bold markers → transparent zero-size', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '**hello**',
        base: _baseStyle,
        palette: _palette,
      ));
      for (final m in parts.where((p) => p.$1 == '**')) {
        expect(_isInvisible(m.$2), isTrue,
            reason: 'bold marker must be invisible');
      }
      final hello = parts.firstWhere((p) => p.$1 == 'hello');
      expect(hello.$2?.fontWeight, FontWeight.w700);
    });

    test('* italic markers → invisible; inner text italic', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '*soft*',
        base: _baseStyle,
        palette: _palette,
      ));
      for (final m in parts.where((p) => p.$1 == '*')) {
        expect(_isInvisible(m.$2), isTrue);
      }
      expect(
        parts.firstWhere((p) => p.$1 == 'soft').$2?.fontStyle,
        FontStyle.italic,
      );
    });

    test('~~ strikethrough markers → invisible; inner has line-through', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '~~gone~~',
        base: _baseStyle,
        palette: _palette,
      ));
      for (final m in parts.where((p) => p.$1 == '~~')) {
        expect(_isInvisible(m.$2), isTrue);
      }
      expect(
        parts.firstWhere((p) => p.$1 == 'gone').$2?.decoration,
        TextDecoration.lineThrough,
      );
    });

    test('` inline code markers → invisible; inner monospace', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: 'see `git status`',
        base: _baseStyle,
        palette: _palette,
      ));
      for (final m in parts.where((p) => p.$1 == '`')) {
        expect(_isInvisible(m.$2), isTrue);
      }
      expect(
        parts.firstWhere((p) => p.$1 == 'git status').$2?.fontFamily,
        'monospace',
      );
    });

    test('# heading prefix → invisible; body sized up', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '# Big',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '# ').$2), isTrue);
      expect(parts.firstWhere((p) => p.$1 == 'Big').$2?.fontSize, 22.0);
    });

    test('### h3 prefix → invisible; body smaller heading', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '### tiny',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '### ').$2), isTrue);
      expect(parts.firstWhere((p) => p.$1 == 'tiny').$2?.fontSize, 16.0);
    });

    test('> quote prefix → invisible; body italic+muted', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '> wisdom',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '> ').$2), isTrue);
      final inner = parts.firstWhere((p) => p.$1 == 'wisdom');
      expect(inner.$2?.fontStyle, FontStyle.italic);
      expect(inner.$2?.color, _palette.muted);
    });

    test('- bullet prefix → invisible', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '- one',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '- ').$2), isTrue);
      expect(parts.any((p) => p.$1 == 'one'), isTrue);
    });

    test('1. ordered prefix → digit kept visible, `. ` invisible', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '1. plan',
        base: _baseStyle,
        palette: _palette,
      ));
      // Digit is still visible (it's the index).
      expect(
        parts.firstWhere((p) => p.$1 == '1').$2?.color,
        _palette.muted,
      );
      // `. ` part is invisible.
      expect(
        _isInvisible(parts.firstWhere((p) => p.$1 == '. ').$2),
        isTrue,
      );
      expect(parts.any((p) => p.$1 == 'plan'), isTrue);
    });

    test('- [ ] task prefix → invisible; content normal', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '- [ ] buy milk',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(
        _isInvisible(parts.firstWhere((p) => p.$1 == '- [ ] ').$2),
        isTrue,
      );
      final body = parts.firstWhere((p) => p.$1 == 'buy milk');
      expect(body.$2?.decoration ?? TextDecoration.none,
          isNot(TextDecoration.lineThrough));
    });

    test('- [x] task prefix → invisible; content struck-through', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: '- [x] done already',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(
        _isInvisible(parts.firstWhere((p) => p.$1 == '- [x] ').$2),
        isTrue,
      );
      expect(
        parts.firstWhere((p) => p.$1 == 'done already').$2?.decoration,
        TextDecoration.lineThrough,
      );
    });

    test('[[wiki]] brackets invisible; inner underlined', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: 'see [[Alpha]] now',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '[[').$2), isTrue);
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == ']]').$2), isTrue);
      expect(
        parts.firstWhere((p) => p.$1 == 'Alpha').$2?.decoration,
        TextDecoration.underline,
      );
    });

    test('[text](url) — url & brackets invisible, link text underlined', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: 'visit [home](https://example.com) here',
        base: _baseStyle,
        palette: _palette,
      ));
      expect(_isInvisible(parts.firstWhere((p) => p.$1 == '[').$2), isTrue);
      // The URL portion `(https://example.com)` is rendered as a
      // single hidden span after the visible link text.
      expect(
        parts.any((p) =>
            p.$1 == '](https://example.com)' && _isInvisible(p.$2)),
        isTrue,
      );
      expect(
        parts.firstWhere((p) => p.$1 == 'home').$2?.decoration,
        TextDecoration.underline,
      );
    });

    test('#tag → bold + surface background; no markers needed', () {
      final parts = _flatten(buildMarkdownTextSpan(
        text: 'note about #project today',
        base: _baseStyle,
        palette: _palette,
      ));
      final tag = parts.firstWhere((p) => p.$1 == '#project');
      expect(tag.$2?.fontWeight, FontWeight.w600);
      expect(tag.$2?.backgroundColor, _palette.surface);
    });
  });

  group('LiveMarkdownController', () {
    late BuildContext ctx;

    Future<void> withContext(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ));
    }

    testWidgets('delegates to buildMarkdownTextSpan', (t) async {
      await withContext(t);
      final c = LiveMarkdownController(text: '**hi**', palette: _palette);
      final span = c.buildTextSpan(
        context: ctx,
        style: _baseStyle,
        withComposing: false,
      );
      expect(_flatten(span).map((p) => p.$1).join(), '**hi**');
      expect(
        _flatten(span).firstWhere((p) => p.$1 == 'hi').$2?.fontWeight,
        FontWeight.w700,
      );
    });

    testWidgets('palette swap notifies listeners; same-palette no-op',
        (t) async {
      await withContext(t);
      final c = LiveMarkdownController(text: 'x', palette: _palette);
      var fired = 0;
      c.addListener(() => fired++);
      c.setPalette(_palette);
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

    testWidgets('caret/selection text equals controller.text after rebuild',
        (t) async {
      // Regression guard: WYSIWYG must never desync the text TextField
      // sees from what `controller.text` exposes — otherwise typing,
      // pasting, or backspacing would visually corrupt the document.
      await withContext(t);
      const src = '# h\n**b** *i* `c` [[w]] - [ ] task\n> q';
      final c = LiveMarkdownController(text: src, palette: _palette);
      final span = c.buildTextSpan(
        context: ctx,
        style: _baseStyle,
        withComposing: false,
      );
      expect(_flatten(span).map((p) => p.$1).join(), c.text);
    });
  });

  group('MarkdownPreview', () {
    testWidgets('renders Text.rich with the same span structure',
        (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(body: '**big** _word_'),
        ),
      ));
      // The preview renders a `Text.rich` — find its rich text content
      // and verify the span flattens back to the source string.
      final text = t.widget<RichText>(find.byType(RichText).first);
      // RichText flatten will include the surrounding line, so just
      // assert it contains the source markdown verbatim.
      expect(text.text.toPlainText(), contains('**big**'));
    });
  });
}
