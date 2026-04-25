import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../onboarding/questionnaire_screen.dart';
import 'pentagon_painter.dart';

class SelfScreen extends ConsumerWidget {
  const SelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scoresAsync = ref.watch(scoresProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profileAsync.valueOrNull?.name.isNotEmpty == true
              ? profileAsync.value!.name
              : 'Я',
        ),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              final profile = profileAsync.valueOrNull;
              if (profile == null) return;
              final navigator = Navigator.of(context);
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => QuestionnaireScreen(
                    existing: profile,
                    onDone: () => navigator.pop(),
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _Streak()),
          ),
        ],
      ),
      body: scoresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (scores) {
          if (scores.length < 3) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Чтобы увидеть пентаграмму, нужно хотя бы 3 оси.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SizedBox(
                height: 320,
                child: CustomPaint(
                  painter: PentagonPainter(
                    scores: scores,
                    fg: palette.fg,
                    muted: palette.muted,
                    line: palette.line,
                    bg: palette.bg,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Текущее состояние',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.muted,
                      letterSpacing: 1.4,
                    ),
              ),
              const SizedBox(height: 12),
              for (final s in scores) _AxisTile(score: s),
              const SizedBox(height: 24),
              Text(
                'Очки начисляются за выполнение задач, привязанных к осям. Со временем затухают — пентаграмма отражает тебя за последний месяц.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({required this.score});
  final AxisScore score;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = score.value.clamp(0.0, 100.0) / 100.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      score.axis.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      score.value.round().toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.muted,
                            fontFeatures: const [],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    backgroundColor: palette.line,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Streak extends ConsumerWidget {
  const _Streak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    return entriesAsync.maybeWhen(
      data: (entries) {
        final streak = _computeStreak(entries);
        if (streak == 0) {
          return Text('—', style: TextStyle(color: palette.muted));
        }
        return Text(
          '$streak д.',
          style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  int _computeStreak(List<Entry> entries) {
    if (entries.isEmpty) return 0;
    final days = <DateTime>{};
    for (final e in entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      days.add(d);
    }
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }
}
