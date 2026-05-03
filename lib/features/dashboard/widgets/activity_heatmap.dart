import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/plural.dart';

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.entries,
    required this.palette,
    this.onTapDay,
  });

  final List<Entry> entries;
  final NoeticaPalette palette;
  final ValueChanged<DateTime>? onTapDay;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  int? _selectedYear;
  final ScrollController _scroll = ScrollController();
  int _lastYearRendered = 0;

  static const _weekdayLabels = ['Пн', '', 'Ср', '', 'Пт', '', ''];
  static const _monthLabels = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  static const double _cellPx = 13;
  static const double _spacingPx = 3;
  static const double _labelGutter = 28;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);

    int minYear = todayD.year;
    for (final e in widget.entries) {
      final years = <int>[e.createdAt.year];
      if (e.completedAt != null) years.add(e.completedAt!.year);
      for (final y in years) {
        if (y < minYear) minYear = y;
      }
    }
    final maxYear = todayD.year;
    final year = _selectedYear ?? maxYear;

    final counts = <DateTime, int>{};
    var maxCount = 0;
    for (final e in widget.entries) {
      final c = e.completedAt;
      if (c == null) continue;
      if (c.year != year) continue;
      final d = DateTime(c.year, c.month, c.day);
      final v = (counts[d] ?? 0) + 1;
      counts[d] = v;
      if (v > maxCount) maxCount = v;
    }

    final yearStart = DateTime(year, 1, 1);
    final yearEndCap = DateTime(year, 12, 31);
    final firstCol = yearStart.subtract(Duration(days: yearStart.weekday - 1));
    final lastCol = yearEndCap
        .add(Duration(days: DateTime.sunday - yearEndCap.weekday));
    final cols = (lastCol.difference(firstCol).inDays + 1) ~/ 7;

    final monthMarkers = <int, String>{};
    int? lastMonth;
    for (var c = 0; c < cols; c++) {
      final d = firstCol.add(Duration(days: c * 7));
      if (d.year != year) continue;
      if (d.month != lastMonth) {
        monthMarkers[c] = _monthLabels[d.month - 1];
        lastMonth = d.month;
      }
    }

    String monthName(int m) => _monthLabels[m - 1];

    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxYear > minYear || widget.entries.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var y = maxYear; y >= minYear; y--) ...[
                  _YearChip(
                    year: y,
                    selected: y == year,
                    palette: palette,
                    onTap: () => setState(() => _selectedYear = y),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          total == 0
              ? 'в $year году пока пусто'
              : '$total ${plural(total, "задача", "задачи", "задач")} закрыто в $year — тапни день',
          style: TextStyle(color: palette.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const rows = 7;
            const spacing = _spacingPx;
            const labelGutter = _labelGutter;

            final available = constraints.maxWidth - labelGutter;
            final fitCellPx =
                (available - (cols - 1) * spacing) / cols;
            final cell = fitCellPx >= _cellPx
                ? fitCellPx.clamp(_cellPx.toDouble(), 22.0)
                : _cellPx.toDouble();
            final gridWidth = cols * cell + (cols - 1) * spacing;

            final nowCol = ((todayD.isBefore(firstCol)
                        ? 0
                        : todayD.difference(firstCol).inDays) /
                    7)
                .floor();
            final anchorCol = year == todayD.year ? nowCol : cols - 1;
            final anchorPx = anchorCol * (cell + spacing);

            if (_lastYearRendered != year) {
              _lastYearRendered = year;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                final max = _scroll.position.maxScrollExtent;
                final viewport = _scroll.position.viewportDimension;
                if (max <= 0) return;
                final desired =
                    (anchorPx - viewport + 8 * (cell + spacing))
                        .clamp(0.0, max);
                _scroll.jumpTo(desired);
              });
            }

            final grid = _buildGrid(
              cols: cols,
              rows: rows,
              cell: cell,
              spacing: spacing,
              firstCol: firstCol,
              year: year,
              todayD: todayD,
              counts: counts,
              maxCount: maxCount,
              monthMarkers: monthMarkers,
              gridWidth: gridWidth,
              labelGutter: labelGutter,
              palette: palette,
              monthName: monthName,
            );

            return SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: grid,
            );
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('меньше',
                  style: TextStyle(color: palette.muted, fontSize: 10)),
              const SizedBox(width: 6),
              for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _bucketColor(t),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              const SizedBox(width: 3),
              Text('больше',
                  style: TextStyle(color: palette.muted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid({
    required int cols,
    required int rows,
    required double cell,
    required double spacing,
    required DateTime firstCol,
    required int year,
    required DateTime todayD,
    required Map<DateTime, int> counts,
    required int maxCount,
    required Map<int, String> monthMarkers,
    required double gridWidth,
    required double labelGutter,
    required NoeticaPalette palette,
    required String Function(int) monthName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: Row(
            children: [
              SizedBox(width: labelGutter),
              SizedBox(
                width: gridWidth,
                child: Stack(
                  children: [
                    for (final entry in monthMarkers.entries)
                      Positioned(
                        left: entry.key * (cell + spacing),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelGutter,
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++) ...[
                    SizedBox(
                      height: cell,
                      child: Text(
                        _weekdayLabels[r],
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (r < rows - 1) SizedBox(height: spacing),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: gridWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    Column(
                      children: [
                        for (var r = 0; r < rows; r++) ...[
                          _buildCell(
                            firstCol.add(Duration(days: c * 7 + r)),
                            year,
                            todayD,
                            counts,
                            maxCount,
                            cell,
                            monthName,
                            palette,
                          ),
                          if (r < rows - 1) SizedBox(height: spacing),
                        ],
                      ],
                    ),
                    if (c < cols - 1) SizedBox(width: spacing),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCell(
    DateTime date,
    int year,
    DateTime todayD,
    Map<DateTime, int> counts,
    int maxCount,
    double size,
    String Function(int) monthName,
    NoeticaPalette palette,
  ) {
    if (date.year != year) {
      return SizedBox(width: size, height: size);
    }
    if (date.isAfter(todayD)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.line.withOpacity(0.18),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final key = DateTime(date.year, date.month, date.day);
    final value = counts[key] ?? 0;
    final t = maxCount == 0 ? 0.0 : (value / maxCount);
    final color =
        value == 0 ? palette.line.withOpacity(0.35) : _bucketColor(t);
    final label = value == 0
        ? '${date.day} ${monthName(date.month)} $year · ничего'
        : '${date.day} ${monthName(date.month)} $year · '
            '$value ${plural(value, "задача", "задачи", "задач")}';
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    final tooltipped = Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 250),
      child: cell,
    );
    if (widget.onTapDay == null) return tooltipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTapDay!(key),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: tooltipped,
      ),
    );
  }

  Color _bucketColor(double t) {
    final palette = widget.palette;
    if (t <= 0.001) return palette.line.withOpacity(0.35);
    if (t < 0.34) return palette.fg.withOpacity(0.28);
    if (t < 0.67) return palette.fg.withOpacity(0.55);
    if (t < 0.99) return palette.fg.withOpacity(0.80);
    return palette.fg;
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.line),
        ),
        child: Text(
          '$year',
          style: TextStyle(
            color: selected ? palette.bg : palette.fg,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
