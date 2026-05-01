// Unit tests for `bodyToPlainText` / `bodyToMarkdown`.
//
// Covers the legacy Quill Delta JSON path AND the plain-markdown path
// — entries created before MVP-1 may still be stored as JSON, and the
// new editor reads markdown. Both shapes must produce a clean preview
// for cards / lists.
import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/utils/body_utils.dart';

void main() {
  group('bodyToMarkdown', () {
    test('returns empty string for empty body', () {
      expect(bodyToMarkdown(''), '');
    });

    test('returns plain markdown body unchanged', () {
      const src = '# Heading\n**bold** plain';
      expect(bodyToMarkdown(src), src);
    });

    test('extracts inserts from legacy Delta JSON', () {
      const json =
          '[{"insert":"hello "},{"insert":"world","attributes":{"bold":true}},{"insert":"\\n"}]';
      expect(bodyToMarkdown(json), 'hello world\n');
    });

    test('falls back to raw text when JSON is malformed', () {
      const broken = '[{"insert":';
      expect(bodyToMarkdown(broken), broken);
    });
  });

  group('bodyToPlainText', () {
    test('strips bold/italic/strike/code markers', () {
      expect(
        bodyToPlainText('**bold** *italic* ~~struck~~ `code`'),
        'bold italic struck code',
      );
    });

    test('strips wiki and markdown link syntax', () {
      expect(bodyToPlainText('see [[Alpha]]'), 'see Alpha');
      expect(
        bodyToPlainText('open [home](https://example.com)'),
        'open home',
      );
    });

    test('strips heading prefixes', () {
      expect(bodyToPlainText('# H1\n## H2\n### H3'), 'H1\nH2\nH3');
    });

    test('strips checkbox and bullet prefixes', () {
      expect(
        bodyToPlainText('- [ ] one\n- [x] two\n- three'),
        'one\ntwo\nthree',
      );
    });

    test('strips blockquote marker', () {
      expect(bodyToPlainText('> wisdom'), 'wisdom');
    });

    test('handles legacy Quill JSON with markdown markers inside', () {
      const json = '[{"insert":"**hi** there\\n"}]';
      expect(bodyToPlainText(json), 'hi there');
    });

    test('returns empty string for empty body', () {
      expect(bodyToPlainText(''), '');
    });
  });
}
