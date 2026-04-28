import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_editor_sheet.dart';

/// «Календарь» — hub-screen that lets the user walk through any day of the
/// year and see what was completed, what is due, and what was just noted.
///
/// Layout: a GitHub-style monthly grid on top (tapable cells with a
/// completion-count dot and deadline pill), plus a live day-detail list
/// below that filters entries to the selected day. Works standalone or
/// as a HomeShell tab.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  static const _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];
  static const _weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  void _gotoToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);
    final axesById = <String, LifeAxis>{
      for (final a in axesAsync.valueOrNull ?? const <LifeAxis>[]) a.id: a,
    };
    final entries = entriesAsync.valueOrNull ?? const <Entry>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь'),
        actions: [
          IconButton(
            tooltip: 'Сегодня',
            icon: const Icon(Icons.today),
            onPressed: _gotoToday,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final grid = _MonthGrid(
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              entries: entries,
              palette: palette,
              onPrev: _previousMonth,
              onNext: _nextMonth,
              onSelect: (d) => setState(() => _selectedDay = d),
              weekdayShort: _weekdayShort,
              monthNames: _monthNames,
            );
            final detail = _DayDetail(
              day: _selectedDay,
              entries: entries,
              axesById: axesById,
              palette: palette,
            );
            if (wide) {
              // Both columns scroll independently so a day with many
              // entries on the right doesn't overflow, and a tall grid
              // never clips the detail panel.
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SingleChildScrollView(child: grid),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(child: detail),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  grid,
                  const SizedBox(height: 20),
                  detail,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDay,
    required this.entries,
    required this.palette,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
    required this.weekdayShort,
    required this.monthNames,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<Entry> entries;
  final NoeticaPalette palette;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;
  final List<String> weekdayShort;
  final List<String> monthNames;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    // Offset so Monday = column 0.
    final leadingBlanks = monthStart.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Pre-aggregate counts per day for the visible month.
    final completions = <DateTime, int>{};
    final deadlines = <DateTime, int>{};
    for (final e in entries) {
      final c = e.completedAt;
      if (c != null &&
          c.year == visibleMonth.year &&
          c.month == visibleMonth.month) {
        final d = DateTime(c.year, c.month, c.day);
        completions[d] = (completions[d] ?? 0) + 1;
      }
      final d = e.dueAt;
      if (d != null &&
          d.year == visibleMonth.year &&
          d.month == visibleMonth.month &&
          e.isTask &&
          !e.isCompleted) {
        final key = DateTime(d.year, d.month, d.day);
        deadlines[key] = (deadlines[key] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrev,
              ),
              Expanded(
                child: Text(
                  '${monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in weekdayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: _buildCell(
                        cellIndex: r * 7 + c,
                        leadingBlanks: leadingBlanks,
                        daysInMonth: daysInMonth,
                        completions: completions,
                        deadlines: deadlines,
                        todayD: todayD,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required int cellIndex,
    required int leadingBlanks,
    required int daysInMonth,
    required Map<DateTime, int> completions,
    required Map<DateTime, int> deadlines,
    required DateTime todayD,
  }) {
    final dayNum = cellIndex - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 48);
    }
    final date = DateTime(visibleMonth.year, visibleMonth.month, dayNum);
    final isToday = date == todayD;
    final isSelected = date == DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final done = completions[date] ?? 0;
    final due = deadlines[date] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: () => onSelect(date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? palette.fg.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday ? palette.fg : palette.line.withOpacity(0.5),
              width: isToday ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: palette.fg,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (due > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (done > 0)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.fg,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    required this.day,
    required this.entries,
    required this.axesById,
    required this.palette,
  });

  final DateTime day;
  final List<Entry> entries;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final createdNotes = entries
        .where((e) =>
            !e.isTask &&
            !e.createdAt.isBefore(dayStart) &&
            e.createdAt.isBefore(dayEnd))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final xpSum = completed.fold<int>(0, (a, e) => a + e.xp);
    final headline = _formatDay(day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _summaryLine(completed.length, xpSum, dueOpen.length, createdNotes.length),
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          // CTA: start composing a task scheduled for this day. We
          // pre-populate dueAt with 09:00 local so the user usually just
          // has to type the title and hit "Сохранить" — the calendar
          // stream picks up the new task on the spot.
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                final due = DateTime(day.year, day.month, day.day, 9, 0);
                showEntryEditor(
                  context,
                  ref,
                  initialDueAt: due,
                  initialKind: EntryKind.task,
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Запланировать на этот день'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.fg,
                side: BorderSide(color: palette.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (completed.isEmpty && dueOpen.isEmpty && createdNotes.isEmpty)
            _EmptyDay(palette: palette)
          else ...[
            if (completed.isNotEmpty) ...[
              _Heading('✓ Выполнено (${completed.length})', palette: palette),
              const SizedBox(height: 4),
              for (final e in completed)
                _EntryRow(
                  entry: e,
                  axesById: axesById,
                  palette: palette,
                  timeLabel: _fmtTime(e.completedAt!),
                ),
              const SizedBox(height: 12),
            ],
            if (dueOpen.isNotEmpty) ...[
              _Heading('⏳ Дедлайны (${dueOpen.length})', palette: palette),
              const SizedBox(height: 4),
              for (final e in dueOpen)
                _EntryRow(
                  entry: e,
                  axesById: axesById,
                  palette: palette,
                  timeLabel: _fmtTime(e.dueAt!),
                  accent: Colors.orangeAccent,
                ),
              const SizedBox(height: 12),
            ],
            if (createdNotes.isNotEmpty) ...[
              _Heading('✎ Заметки (${createdNotes.length})', palette: palette),
              const SizedBox(height: 4),
              for (final e in createdNotes)
                _EntryRow(
                  entry: e,
                  axesById: axesById,
                  palette: palette,
                  timeLabel: _fmtTime(e.createdAt),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _summaryLine(int done, int xp, int due, int notes) {
    final parts = <String>[];
    if (done > 0) parts.add('$done ${_pluralize(done, "задача", "задачи", "задач")} · +$xp XP');
    if (due > 0) parts.add('$due ${_pluralize(due, "дедлайн", "дедлайна", "дедлайнов")}');
    if (notes > 0) parts.add('$notes ${_pluralize(notes, "заметка", "заметки", "заметок")}');
    if (parts.isEmpty) return 'Ничего не записано.';
    return parts.join(' · ');
  }

  String _pluralize(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
    return many;
  }

  String _formatDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    final label = '${d.day} ${months[d.month - 1]}  ·  ${days[d.weekday - 1]}';
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
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: palette.muted,
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
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
      onTap: () => showEntryEditor(context, ref, existing: entry),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: accent ?? palette.muted,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
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

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.palette});
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'В этот день ничего не записано.',
            style: TextStyle(color: palette.muted, fontSize: 13),
          ),
        ),
      );
}
