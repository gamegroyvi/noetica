import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../services/levels.dart';
import 'data_providers.dart';
import 'profile_providers.dart';

final scoresProvider = FutureProvider<List<AxisScore>>((ref) async {
  ref.watch(entriesProvider);
  ref.watch(axesProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final repo = await ref.watch(repositoryProvider.future);
  return repo.computeScores(baselineCutoff: profile?.epochRefreshedAt);
});

final lifetimeXpProvider = FutureProvider<int>((ref) async {
  ref.watch(entriesProvider);
  final repo = await ref.watch(repositoryProvider.future);
  return repo.lifetimeXp();
});

final levelStatsProvider = FutureProvider<LevelStats>((ref) async {
  final xp = await ref.watch(lifetimeXpProvider.future);
  return levelStatsFor(xp);
});

final axisLifetimeXpProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(entriesProvider);
  ref.watch(axesProvider);
  final repo = await ref.watch(repositoryProvider.future);
  return repo.axisLifetimeXp();
});

final axisLevelStatsProvider =
    FutureProvider<Map<String, LevelStats>>((ref) async {
  final perAxis = await ref.watch(axisLifetimeXpProvider.future);
  return {for (final e in perAxis.entries) e.key: levelStatsFor(e.value)};
});

final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(entriesProvider);
  final repo = await ref.watch(repositoryProvider.future);
  return repo.streakDays();
});
