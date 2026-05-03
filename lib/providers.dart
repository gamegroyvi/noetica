import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db.dart';
import 'data/models.dart';
import 'data/profile.dart';
import 'data/repository.dart';
import 'services/auth_service.dart';
import 'services/axes_api.dart';
import 'services/backend_urls_service.dart';
import 'services/builtin_generators.dart';
import 'services/generator_manifest.dart';
import 'services/levels.dart';
import 'services/roadmap_api.dart';
import 'services/sync_service.dart';
import 'services/tools_api.dart';
import 'services/user_manifest.dart';

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
  // Recompute whenever entries, axes, or the эпоха tier change.
  ref.watch(entriesProvider);
  ref.watch(axesProvider);
  // Profile is the source for `epochRefreshedAt` — re-run on every
  // change so tapping «Углубиться» produces an immediate visible
  // pentagon reset without waiting for the decay window to roll.
  final profile = ref.watch(profileProvider).valueOrNull;
  final repo = await ref.watch(repositoryProvider.future);
  return repo.computeScores(baselineCutoff: profile?.epochRefreshedAt);
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

/// Streams the user profile. The initial value comes from
/// [ProfileService.load] (SharedPreferences); every subsequent
/// `ProfileService.save` / `clear` broadcasts on `ProfileService.changes`
/// so *all* watchers — scoresProvider, the self-screen overlay, the
/// header — see a fresh value without any call site having to remember
/// `ref.invalidate(profileProvider)`.
final profileProvider = StreamProvider<UserProfile?>((ref) async* {
  final svc = ref.watch(profileServiceProvider);
  yield await svc.load();
  yield* ProfileService.changes;
});

final roadmapApiProvider = Provider<RoadmapApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  final url = ref.watch(activeBackendUrlProvider);
  return RoadmapApi(authService: auth, baseUrl: url);
});

final axesApiProvider = Provider<AxesApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  final url = ref.watch(activeBackendUrlProvider);
  return AxesApi(authService: auth, baseUrl: url);
});

final toolsApiProvider = Provider<ToolsApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  final url = ref.watch(activeBackendUrlProvider);
  return ToolsApi(authService: auth, baseUrl: url);
});

/// Singleton store for user-authored manifests. Lives for the
/// lifetime of the app — the underlying SharedPreferences instance is
/// loaded lazily on first access.
final userManifestStoreProvider = Provider<UserManifestStore>((ref) {
  final store = UserManifestStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Stream of `UserManifest` snapshots. Re-emits whenever an entry is
/// added / updated / deleted.
final userManifestsProvider = StreamProvider<List<UserManifest>>((ref) {
  final store = ref.watch(userManifestStoreProvider);
  return store.changes;
});

/// Catalog of generators surfaced on the «Ассистент» screen. Composite
/// of builtins + user-authored manifests; rebuilds whenever
/// `userManifestsProvider` emits a new snapshot.
final generatorRegistryProvider = Provider<GeneratorRegistry>((ref) {
  final builtins = buildBuiltinGeneratorRegistry();
  final users = ref.watch(userManifestsProvider).valueOrNull ?? const [];
  final userRegistry = UserGeneratorRegistry(
    users.map((m) => m.toGenerator()).toList(growable: false),
  );
  return CompositeGeneratorRegistry([builtins, userRegistry]);
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

/// Holds the user-managed list of backend deployments. The service
/// itself is a singleton; consumers that just need the active URL
/// should watch [activeBackendUrlProvider] instead, which rebuilds
/// dependent providers whenever the user switches backends.
final backendUrlsServiceProvider = Provider<BackendUrlsService>((ref) {
  final service = BackendUrlsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of the current backend list + active selection. Loaded once
/// from SharedPreferences on first observation, then re-emitted every
/// time the user adds, edits, removes or switches backends.
final backendUrlsStateProvider = StreamProvider<BackendUrlsState>((ref) async* {
  final svc = ref.watch(backendUrlsServiceProvider);
  yield* svc.changes;
});

/// The URL every API client should hit. Falls back to the compile-time
/// default while the SharedPreferences load is in flight (so the very
/// first cold-start frame still has *something* to talk to).
final activeBackendUrlProvider = Provider<String>((ref) {
  final state = ref.watch(backendUrlsStateProvider).valueOrNull;
  return state?.activeUrl ?? ref.watch(backendUrlsServiceProvider).activeUrlOrDefault;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final url = ref.watch(activeBackendUrlProvider);
  final service = AuthService(backendBaseUrl: url);
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
  final url = ref.watch(activeBackendUrlProvider);
  final service = SyncService(
    repository: repo,
    auth: auth,
    profileService: profile,
    backendBaseUrl: url,
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
