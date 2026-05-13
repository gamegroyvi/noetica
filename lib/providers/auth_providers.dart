import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/backend_urls_service.dart';
import '../services/sync_service.dart';
import 'data_providers.dart';
import 'profile_providers.dart';

final backendUrlsServiceProvider = Provider<BackendUrlsService>((ref) {
  final service = BackendUrlsService();
  ref.onDispose(service.dispose);
  return service;
});

final backendUrlsStateProvider =
    StreamProvider<BackendUrlsState>((ref) async* {
  final svc = ref.watch(backendUrlsServiceProvider);
  yield* svc.changes;
});

final activeBackendUrlProvider = Provider<String>((ref) {
  final state = ref.watch(backendUrlsStateProvider).valueOrNull;
  return state?.activeUrl ??
      ref.watch(backendUrlsServiceProvider).activeUrlOrDefault;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final url = ref.watch(activeBackendUrlProvider);
  final service = AuthService(backendBaseUrl: url);
  ref.onDispose(service.dispose);
  return service;
});

final authSessionProvider = StreamProvider<AuthSession?>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield await service.restore();
  yield* service.sessionStream;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  final auth = ref.watch(authServiceProvider);
  final profile = await ref.watch(profileServiceProvider.future);
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
