import 'package:flutter_test/flutter_test.dart';

// Verify the barrel file re-exports all provider symbols.
// If any sub-module has a compile error, this test will fail to load.
import 'package:noetica/providers.dart';

void main() {
  test('barrel file exports core data providers', () {
    // These are compile-time checks — if the symbols don't exist,
    // the test won't even compile.
    expect(dbProvider, isNotNull);
    expect(repositoryProvider, isNotNull);
    expect(axesProvider, isNotNull);
    expect(entriesProvider, isNotNull);
  });

  test('barrel file exports profile providers', () {
    expect(profileServiceProvider, isNotNull);
    expect(profileProvider, isNotNull);
    expect(onboardedProvider, isNotNull);
  });

  test('barrel file exports auth providers', () {
    expect(backendUrlsServiceProvider, isNotNull);
    expect(backendUrlsStateProvider, isNotNull);
    expect(activeBackendUrlProvider, isNotNull);
    expect(authServiceProvider, isNotNull);
    expect(authSessionProvider, isNotNull);
    expect(syncServiceProvider, isNotNull);
  });

  test('barrel file exports API providers', () {
    expect(roadmapApiProvider, isNotNull);
    expect(axesApiProvider, isNotNull);
    expect(toolsApiProvider, isNotNull);
  });

  test('barrel file exports score providers', () {
    expect(scoresProvider, isNotNull);
    expect(lifetimeXpProvider, isNotNull);
    expect(levelStatsProvider, isNotNull);
    expect(axisLifetimeXpProvider, isNotNull);
    expect(axisLevelStatsProvider, isNotNull);
    expect(streakProvider, isNotNull);
  });
}
