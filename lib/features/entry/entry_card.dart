import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import 'entry_editor_sheet.dart';

/// A single entry card. Used by the dashboard, the notes list and any other
/// screen that shows entries in card form.
class EntryCard extends ConsumerWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.axesById,
    this.dense = false,
  });

  final Entry entry;
  final Map<String, LifeAxis> axesById;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: entry),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.line),
        ),
        padding: EdgeInsets.all(dense ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatTimestamp(entry.createdAt),
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (entry.isTask)
                  _Chip(
                    text: entry.isCompleted ? '✓ задача' : 'задача',
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.title.isEmpty ? '—' : entry.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration:
                        entry.isCompleted ? TextDecoration.lineThrough : null,
                  ),
            ),
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.body,
                maxLines: dense ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (entry.axisIds.isNotEmpty || entry.isTask) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final aid in entry.axisIds)
                    if (axesById[aid] != null)
                      AxisChip(axis: axesById[aid]!),
                  if (entry.isTask) _Chip(text: '+${entry.xp} XP'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AxisChip extends StatelessWidget {
  const AxisChip({super.key, required this.axis});
  final LifeAxis axis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(axis.symbol, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            axis.name,
            style: TextStyle(
              fontSize: 11,
              color: palette.fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: palette.fg),
      ),
    );
  }
}

/// Time-gap divider shown between two adjacent entries on a timeline.
class GapDivider extends StatelessWidget {
  const GapDivider({super.key, required this.from, required this.to});

  /// Older entry timestamp (lower on the screen).
  final DateTime from;

  /// More recent entry timestamp (higher on the screen).
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = formatGapSince(to, from);
    final emphasised = to.difference(from).abs().inDays >= 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.line, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: emphasised ? palette.fg : palette.muted,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.line, height: 1)),
        ],
      ),
    );
  }
}
