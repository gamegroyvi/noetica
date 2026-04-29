import 'dart:convert';

/// Extract plain text from an entry body. The body may be:
///   1. Legacy plain text / markdown (no JSON prefix)
///   2. Quill Delta JSON (starts with '[')
String bodyToPlainText(String body) {
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
      return buf.toString().trim();
    } catch (_) {
      return body;
    }
  }
  return body;
}
