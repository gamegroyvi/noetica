import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/subtask_utils.dart';
import '../markdown_body_editor.dart';

/// Pill-style toggle chip for selecting life axes.
class AxisToggleChip extends StatelessWidget {
  const AxisToggleChip({
    super.key,
    required this.axis,
    required this.selected,
    required this.onTap,
  });

  final LifeAxis axis;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.bg,
          border: Border.all(color: selected ? palette.fg : palette.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              axis.symbol,
              style: TextStyle(
                fontSize: 13,
                color: selected ? palette.bg : palette.fg,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              axis.name,
              style: TextStyle(
                fontSize: 12,
                color: selected ? palette.bg : palette.fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tag input field with inline tag pills.
class TagsField extends StatelessWidget {
  const TagsField({
    super.key,
    required this.palette,
    required this.tags,
    required this.controller,
    required this.onCommit,
    required this.onRemove,
  });

  final NoeticaPalette palette;
  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onCommit;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.editorTags,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: palette.muted, letterSpacing: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in tags)
                InkWell(
                  onTap: () => onRemove(tag),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#',
                            style: TextStyle(
                                color: palette.muted, fontSize: 11)),
                        Text(
                          tag,
                          style:
                              TextStyle(color: palette.fg, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 11, color: palette.muted),
                      ],
                    ),
                  ),
                ),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(color: palette.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: tags.isEmpty ? S.of(context)!.editorAddTag : '+',
                      hintStyle:
                          TextStyle(color: palette.muted, fontSize: 12),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                    ),
                    onSubmitted: (_) => onCommit(),
                    onChanged: (v) {
                      if (v.endsWith(' ') || v.endsWith(',')) onCommit();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows entries that link back to the current entry via [[wiki-links]].
class BacklinksPanel extends ConsumerWidget {
  const BacklinksPanel({
    super.key,
    required this.palette,
    required this.entryId,
    required this.onTapEntry,
  });

  final NoeticaPalette palette;
  final String entryId;
  final ValueChanged<Entry> onTapEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(repositoryProvider);
    return repoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (repo) => FutureBuilder<List<Entry>>(
        future: repo.listBacklinks(entryId),
        builder: (context, snap) {
          final items = snap.data ?? const <Entry>[];
          if (items.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_left,
                        size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Text(
                      S.of(context)!.editorBacklinksCount(items.length),
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in items)
                  InkWell(
                    onTap: () => onTapEntry(e),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            e.kind == EntryKind.task
                                ? Icons.check_circle_outline
                                : Icons.note_outlined,
                            size: 14,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.title.isEmpty
                                  ? S.of(context)!.editorUntitled
                                  : e.title,
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Inline subtask editor with toggleable checkboxes.
class SubtaskEditor extends StatelessWidget {
  const SubtaskEditor({super.key, required this.body, required this.onChanged});

  final String body;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final subs = parseSubtasks(body);
    if (subs.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final prog = subtaskProgress(body);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.editorSubtasksProgress(prog.done, prog.total),
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < subs.length; i++)
              InkWell(
                onTap: () => onChanged(toggleSubtask(body, i)),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: palette.line, width: 1.3),
                          borderRadius: BorderRadius.circular(4),
                          color: subs[i].checked
                              ? palette.fg
                              : Colors.transparent,
                        ),
                        child: subs[i].checked
                            ? Icon(Icons.check,
                                size: 12, color: palette.bg)
                            : null,
                      ),
                      Expanded(
                        child: subs[i].text.isEmpty
                            ? Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.muted,
                                ),
                              )
                            : MarkdownPreview(
                                body: subs[i].text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subs[i].checked
                                      ? palette.muted
                                      : palette.fg,
                                  decoration: subs[i].checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
