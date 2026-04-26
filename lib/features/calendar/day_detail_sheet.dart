import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_editor_sheet.dart';

/// Bottom sheet that summarises a single day — completed tasks + open
/// deadlines + notes. Used by the dashboard heatmap so tapping a cell
/// gives an immediate preview without leaving the dashboard tab.
Future<void> showDayDetailSheet(
  BuildContext context,
  DateTime day, {
  VoidCallback? onOpenCalendar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _DayDetailSheet(
      day: day,
      onOpenCalendar: onOpenCalendar,
    ),
  );
}

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({required this.day, this.onOpenCalendar});

  final DateTime day;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entries = ref.watch(entriesProvider).valueOrNull ?? const <Entry>[];
    final axes = ref.watch(axesProvider).valueOrNull ?? const <LifeAxis>[];
    final axesById = {for (final a in axes) a.id: a};

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final completed = entries
        .where((e) =>
            e.completedAt != null &&
            !e.completedAt!.isBefore(dayStart) &&
            e.completedAt!.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final dueOpen = entries
        .where((e) =>
            e.isTask &&
            !e.isCompleted &&
            e.dueAt != null &&
            !e.dueAt!.isBefore(dayStart) &&
            e.dueAt!.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    final xpSum = completed.fold<int>(0, (a, e) => a + e.xp);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatHeadline(day),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (onOpenCalendar != null)
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text('Календарь'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenCalendar!();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _summaryLine(completed.length, xpSum, dueOpen.length),
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty && dueOpen.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'В этот день ничего не закрыто и не запланировано.',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                    ),
                  )
                else ...[
                  if (completed.isNotEmpty) ...[
                    _Heading(
                      '✓ Выполнено (${completed.length})',
                      palette: palette,
                    ),
                    for (final e in completed)
                      _EntryTile(
                        entry: e,
                        axesById: axesById,
                        palette: palette,
                        timeLabel: _fmtTime(e.completedAt!),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (dueOpen.isNotEmpty) ...[
                    _Heading(
                      '⏳ Дедлайны (${dueOpen.length})',
                      palette: palette,
                    ),
                    for (final e in dueOpen)
                      _EntryTile(
                        entry: e,
                        axesById: axesById,
                        palette: palette,
                        timeLabel: _fmtTime(e.dueAt!),
                        accent: Colors.orangeAccent,
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summaryLine(int done, int xp, int due) {
    final parts = <String>[];
    if (done > 0) parts.add('$done закрыто · +$xp XP');
    if (due > 0) parts.add('$due дедлайн(ов)');
    if (parts.isEmpty) return 'Без записей.';
    return parts.join(' · ');
  }

  String _formatHeadline(DateTime d) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final label = '${d.day} ${months[d.month - 1]} · ${days[d.weekday - 1]}';
    if (diff == 0) return 'Сегодня · $label';
    if (diff == -1) return 'Вчера · $label';
    if (diff == 1) return 'Завтра · $label';
    return label;
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.palette});
  final String text;
  final NoeticaPalette palette;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.entry,
    required this.axesById,
    required this.palette,
    required this.timeLabel,
    this.accent,
  });

  final Entry entry;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;
  final String timeLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbols = entry.axisIds
        .map((id) => axesById[id]?.symbol)
        .whereType<String>()
        .toList();
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        showEntryEditor(context, ref, existing: entry);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: accent ?? palette.muted,
                  fontSize: 12,
                ),
              ),
            ),
            if (symbols.isNotEmpty) ...[
              Text(
                symbols.join(' '),
                style: TextStyle(color: palette.fg, fontSize: 14),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                entry.title.isEmpty ? '(без названия)' : entry.title,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 14,
                  decoration: entry.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: palette.muted,
                ),
              ),
            ),
            if (entry.xp > 0 && entry.isCompleted)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '+${entry.xp}',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
