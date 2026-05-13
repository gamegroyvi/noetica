import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile.dart';
import 'data_providers.dart';

const _kOnboardedKey = 'noetica.onboarded.v1';

final profileServiceProvider = FutureProvider<ProfileService>((ref) async {
  final db = await ref.watch(dbProvider.future);
  return ProfileService(db);
});

final profileProvider = StreamProvider<UserProfile?>((ref) async* {
  final svc = await ref.watch(profileServiceProvider.future);
  yield await svc.load();
  yield* ProfileService.changes;
});

final onboardedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
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
