import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import 'entry_editor_page.dart';

/// Opens the WYSIWYG entry editor as a bottom sheet that slides up.
Future<void> showEntryEditor(
  BuildContext context,
  WidgetRef ref, {
  Entry? existing,
  DateTime? initialDueAt,
  EntryKind? initialKind,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      final maxH =
          size.width >= 1100 ? size.height * 0.92 : size.height * 0.85;
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: EntryEditorContent(
            existing: existing,
            initialDueAt: initialDueAt,
            initialKind: initialKind,
          ),
        ),
      );
    },
  );
}
