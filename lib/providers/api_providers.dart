import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/axes_api.dart';
import '../services/roadmap_api.dart';
import '../services/tools_api.dart';
import 'auth_providers.dart';

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
