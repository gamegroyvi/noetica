import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import 'entry_editor_page.dart';

/// Opens the WYSIWYG entry editor as a full-screen page.
///
/// This function preserves the same signature used by the rest of the
/// app so existing call-sites don't need any changes.
Future<void> showEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  await openEntryEditor(
    context,
    ref,
    existing: existing,
    initialDueAt: initialDueAt,
    initialKind: initialKind,
  );
}
