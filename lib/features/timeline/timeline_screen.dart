import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../entry/entry_editor_sheet.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Лента')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Лента пуста',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создай первую запись — она будет якорем твоей ленты воспоминаний.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            );
          }
          final axes = axesAsync.valueOrNull ?? const [];
          final axesById = {for (final a in axes) a.id: a};

          // entries already sorted DESC by created_at
          final widgets = <Widget>[];
          for (var i = 0; i < entries.length; i++) {
            final e = entries[i];
            if (i > 0) {
              final prev = entries[i - 1];
              widgets.add(_GapDivider(
                from: e.createdAt,
                to: prev.createdAt,
              ));
            }
            widgets.add(_EntryCard(entry: e, axesById: axesById));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: widgets.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: widgets[i],
            ),
          );
        },
      ),
    );
  }
}

class _GapDivider extends StatelessWidget {
  const _GapDivider({required this.from, required this.to});

  final DateTime from;
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
                fontWeight:
                    emphasised ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.line, height: 1)),
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry, required this.axesById});

  final Entry entry;
  final Map<String, LifeAxis> axesById;

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
        padding: const EdgeInsets.all(14),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.isCompleted ? '✓ задача' : 'задача',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: palette.fg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.title.isEmpty ? '—' : entry.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: entry.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
            ),
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (entry.axisIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final aid in entry.axisIds)
                    if (axesById[aid] != null)
                      _AxisChip(axis: axesById[aid]!),
                  if (entry.isTask)
                    _Chip(text: '+${entry.xp} XP'),
                ],
              ),
            ] else if (entry.isTask) ...[
              const SizedBox(height: 10),
              _Chip(text: '+${entry.xp} XP'),
            ],
          ],
        ),
      ),
    );
  }
}

class _AxisChip extends StatelessWidget {
  const _AxisChip({required this.axis});
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
