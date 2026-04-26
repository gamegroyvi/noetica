import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/levels.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../entry/entry_editor_sheet.dart';

/// Bottom sheet shown when the user taps a branch on the Древо. Surfaces
/// (a) per-axis level + lifetime XP, (b) decay-window score, (c) the
/// last few completed tasks attached to this axis with their effective
/// per-axis XP contribution. Lets the user dive from "what does this
/// axis even mean" → "what have I actually done for it lately".
Future<void> showAxisDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required AxisScore score,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AxisDetailSheet(score: score),
  );
}

class _AxisDetailSheet extends ConsumerWidget {
  const _AxisDetailSheet({required this.score});
  final AxisScore score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final levels =
        ref.watch(axisLevelStatsProvider).valueOrNull ?? const <String, LevelStats>{};
    final entries = ref.watch(entriesProvider).valueOrNull ?? const <Entry>[];
    final ls = levels[score.axis.id];
    final tasks = entries
        .where((e) =>
            e.isTask &&
            e.isCompleted &&
            e.axisIds.contains(score.axis.id))
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
    final recent = tasks.take(15).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    score.axis.symbol,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    score.axis.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ls != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'L${ls.level}',
                      style: TextStyle(
                        color: palette.fg,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.fg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Э${epochFromXp(ls.totalXp)}',
                      style: TextStyle(
                        color: palette.bg,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  label: 'СОСТОЯНИЕ',
                  value: '${score.value.round()} / 100',
                  palette: palette,
                ),
                const SizedBox(width: 24),
                if (ls != null)
                  _Stat(
                    label: 'XP ВСЕГО',
                    value: '${ls.totalXp}',
                    palette: palette,
                  ),
                const SizedBox(width: 24),
                if (ls != null)
                  _Stat(
                    label: 'ДО Э${epochFromXp(ls.totalXp) + 1}',
                    value: '${xpToNextEpoch(ls.totalXp)}',
                    palette: palette,
                  ),
              ],
            ),
            if (ls != null) ...[
              const SizedBox(height: 6),
              Text(
                'Уровень L${ls.level} — от всех закрытых задач. '
                'Эпоха Э${epochFromXp(ls.totalXp)} — от XP именно этой оси, '
                'растёт и после того как древо заполнено на 100 %.',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
            ],
            if (ls != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ls.progress,
                  minHeight: 4,
                  backgroundColor: palette.line,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'ВЫПОЛНЕНО ПО ОСИ',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Здесь появятся выполненные задачи, привязанные к этой оси.',
                  style: TextStyle(color: palette.muted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: recent.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: palette.line, height: 1),
                  itemBuilder: (_, i) {
                    final t = recent[i];
                    final share = _axisShare(t, score.axis.id);
                    final xpForAxis = (t.xp * share).round();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        showEntryEditor(context, ref, existing: t);
                      },
                      title: Text(
                        t.title.isEmpty ? '—' : t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        t.completedAt != null
                            ? formatTimestamp(t.completedAt!)
                            : '',
                        style: TextStyle(color: palette.muted, fontSize: 11),
                      ),
                      trailing: Text(
                        '+$xpForAxis XP',
                        style: TextStyle(
                          color: palette.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Returns this task's normalised share for [axisId] — the same math
/// computeScores uses, kept inline here to avoid round-tripping through
/// the DB just for the per-row trailing XP label.
double _axisShare(Entry t, String axisId) {
  if (!t.axisIds.contains(axisId)) return 0;
  if (t.axisIds.isEmpty) return 0;
  final weights = t.axisWeights;
  if (weights.isEmpty) return 1.0 / t.axisIds.length;
  double total = 0;
  for (final id in t.axisIds) {
    total += weights[id] ?? 1.0;
  }
  if (total <= 0) return 1.0 / t.axisIds.length;
  return (weights[axisId] ?? 1.0) / total;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.palette,
  });
  final String label;
  final String value;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
