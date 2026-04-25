import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db.dart';
import 'data/models.dart';
import 'data/profile.dart';
import 'data/repository.dart';
import 'services/auth_service.dart';
import 'services/axes_api.dart';
import 'services/levels.dart';
import 'services/roadmap_api.dart';
import 'services/sync_service.dart';

const _kOnboardedKey = 'noetica.onboarded.v1';

final dbProvider = FutureProvider<NoeticaDb>((ref) async {
  final db = await NoeticaDb.open();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = FutureProvider<NoeticaRepository>((ref) async {
  final db = await ref.watch(dbProvider.future);
  return NoeticaRepository(db);
});

final axesProvider = StreamProvider<List<LifeAxis>>((ref) async* {
  final repo = await ref.watch(repositoryProvider.future);
  yield* repo.watchAxes();
});

final entriesProvider = StreamProvider<List<Entry>>((ref) async* {
  final repo = await ref.watch(repositoryProvider.future);
  yield* repo.watchEntries();
});

final scoresProvider = FutureProvider<List<AxisScore>>((ref) async {
  // Recompute whenever entries change.
  ref.watch(entriesProvider);
  ref.watch(axesProvider);
  final repo = await ref.watch(repositoryProvider.future);
  return repo.computeScores();
});

final onboardedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  // We're "onboarded" if the user has at least 3 axes OR explicitly skipped.
  if (prefs.getBool(_kOnboardedKey) == true) return true;
  final repo = await ref.watch(repositoryProvider.future);
  final axes = await repo.listAxes();
  if (axes.length >= 3) {
    await prefs.setBool(_kOnboardedKey, true);
    return true;
  }
  return false;
});

Future<void> markOnboarded() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardedKey, true);
}

final profileServiceProvider = Provider<ProfileService>((_) => ProfileService());

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  return ref.watch(profileServiceProvider).load();
});

final roadmapApiProvider = Provider<RoadmapApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  return RoadmapApi(authService: auth);
});

final axesApiProvider = Provider<AxesApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  return AxesApi(authService: auth);
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

/// Per-axis lifetime XP, recomputed whenever entries change. Empty map
/// when the user hasn't created any axes yet.
final axisLifetimeXpProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(entriesProvider);
  ref.watch(axesProvider);
  final repo = await ref.watch(repositoryProvider.future);
  return repo.axisLifetimeXp();
});

/// Per-axis level + progress, derived from [axisLifetimeXpProvider]
/// using the same threshold curve as the global profile level. Lets the
/// Древо show e.g. "Тело · L3 · 540/700" next to each branch without
/// every consumer redoing the math.
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

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});

/// Emits the current session (or null) and is rebuilt whenever it changes.
final authSessionProvider = StreamProvider<AuthSession?>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield await service.restore();
  yield* service.sessionStream;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  final auth = ref.watch(authServiceProvider);
  final profile = ref.watch(profileServiceProvider);
  final service = SyncService(
    repository: repo,
    auth: auth,
    profileService: profile,
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
