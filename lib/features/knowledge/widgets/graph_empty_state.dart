import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../graph_models.dart';

/// Empty state shown when the graph has no nodes matching
/// the current filter.
class GraphEmptyState extends StatelessWidget {
  const GraphEmptyState({
    super.key,
    required this.filter,
    required this.palette,
    required this.onCreateEntry,
    required this.onResetFilter,
  });

  final GraphFilterMode filter;
  final NoeticaPalette palette;
  final VoidCallback onCreateEntry;
  final VoidCallback onResetFilter;

  @override
  Widget build(BuildContext context) {
    final (title, hint, primaryLabel, primaryAction, showReset) =
        _copyForFilter(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filter.icon, size: 48, color: palette.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.fg,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryAction != null)
                  FilledButton.icon(
                    onPressed: primaryAction,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(primaryLabel),
                  ),
                if (showReset)
                  OutlinedButton.icon(
                    onPressed: onResetFilter,
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(S.of(context)!.graphResetFilter),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, String, String, VoidCallback?, bool) _copyForFilter(BuildContext context) {
    final tr = S.of(context)!;
    switch (filter) {
      case GraphFilterMode.all:
        return (
          tr.graphEmptyAllTitle,
          tr.graphEmptyAllBody,
          tr.graphEmptyAllAction,
          onCreateEntry,
          false,
        );
      case GraphFilterMode.notes:
        return (
          tr.graphEmptyNotesTitle,
          tr.graphEmptyNotesBody,
          tr.graphEmptyNotesAction,
          onCreateEntry,
          true,
        );
      case GraphFilterMode.tasks:
        return (
          tr.graphEmptyTasksTitle,
          tr.graphEmptyTasksBody,
          tr.graphEmptyAllAction,
          onCreateEntry,
          true,
        );
      case GraphFilterMode.bookmarks:
        return (
          tr.graphEmptyBookmarksTitle,
          tr.graphEmptyBookmarksBody,
          '',
          null,
          true,
        );
      case GraphFilterMode.daily:
        return (
          tr.graphEmptyDailyTitle,
          tr.graphEmptyDailyBody,
          '',
          null,
          true,
        );
      case GraphFilterMode.knowledge:
        return (
          tr.graphEmptyKnowledgeTitle,
          tr.graphEmptyKnowledgeBody,
          '',
          null,
          true,
        );
    }
  }
}
