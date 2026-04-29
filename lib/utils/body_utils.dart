import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Extract plain text from an entry body. The body may be:
///   1. Legacy plain text (no JSON prefix)
///   2. Quill Delta JSON (starts with '[')
String bodyToPlainText(String body) {
  if (body.isEmpty) return '';
  if (body.startsWith('[')) {
    try {
      final json = jsonDecode(body) as List;
      final doc = Document.fromJson(json);
      return doc.toPlainText().trim();
    } catch (_) {
      return body;
    }
  }
  return body;
}
