import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/analytics_service.dart';

void main() {
  group('AnalyticsEvents', () {
    test('all event names are non-empty snake_case strings', () {
      final events = [
        AnalyticsEvents.onboardingStarted,
        AnalyticsEvents.onboardingCompleted,
        AnalyticsEvents.onboardingStepCompleted,
        AnalyticsEvents.taskCreated,
        AnalyticsEvents.taskCompleted,
        AnalyticsEvents.noteCreated,
        AnalyticsEvents.entryDeleted,
        AnalyticsEvents.reflectionSubmitted,
        AnalyticsEvents.weeklyReflectionSubmitted,
        AnalyticsEvents.roadmapGenerated,
        AnalyticsEvents.menuGenerated,
        AnalyticsEvents.recipeGenerated,
        AnalyticsEvents.axesGenerated,
        AnalyticsEvents.aiGenerationBlocked,
        AnalyticsEvents.screenViewed,
        AnalyticsEvents.sidebarItemTapped,
        AnalyticsEvents.paywallShown,
        AnalyticsEvents.paywallDismissed,
        AnalyticsEvents.purchaseStarted,
        AnalyticsEvents.purchaseCompleted,
        AnalyticsEvents.subscriptionExpired,
        AnalyticsEvents.epochCompleted,
        AnalyticsEvents.epochTierUp,
        AnalyticsEvents.appOpened,
        AnalyticsEvents.pomodoroStarted,
        AnalyticsEvents.pomodoroCompleted,
        AnalyticsEvents.streakMilestone,
      ];
      for (final e in events) {
        expect(e, isNotEmpty, reason: 'Event name should not be empty');
        expect(e, matches(RegExp(r'^[a-z][a-z0-9_]*$')),
            reason: '"$e" should be snake_case');
      }
    });

    test('all event names are unique', () {
      final events = [
        AnalyticsEvents.onboardingStarted,
        AnalyticsEvents.onboardingCompleted,
        AnalyticsEvents.onboardingStepCompleted,
        AnalyticsEvents.taskCreated,
        AnalyticsEvents.taskCompleted,
        AnalyticsEvents.noteCreated,
        AnalyticsEvents.entryDeleted,
        AnalyticsEvents.reflectionSubmitted,
        AnalyticsEvents.weeklyReflectionSubmitted,
        AnalyticsEvents.roadmapGenerated,
        AnalyticsEvents.menuGenerated,
        AnalyticsEvents.recipeGenerated,
        AnalyticsEvents.axesGenerated,
        AnalyticsEvents.aiGenerationBlocked,
        AnalyticsEvents.screenViewed,
        AnalyticsEvents.sidebarItemTapped,
        AnalyticsEvents.paywallShown,
        AnalyticsEvents.paywallDismissed,
        AnalyticsEvents.purchaseStarted,
        AnalyticsEvents.purchaseCompleted,
        AnalyticsEvents.subscriptionExpired,
        AnalyticsEvents.epochCompleted,
        AnalyticsEvents.epochTierUp,
        AnalyticsEvents.appOpened,
        AnalyticsEvents.pomodoroStarted,
        AnalyticsEvents.pomodoroCompleted,
        AnalyticsEvents.streakMilestone,
      ];
      expect(events.toSet().length, events.length);
    });
  });

  group('AnalyticsService', () {
    test('track does not throw without a provider', () {
      final svc = AnalyticsService.instance;
      expect(
        () => svc.track('test_event', {'key': 'value'}),
        returnsNormally,
      );
    });

    test('identify does not throw without a provider', () {
      final svc = AnalyticsService.instance;
      expect(
        () => svc.identify('user123', {'name': 'Test'}),
        returnsNormally,
      );
    });

    test('reset does not throw without a provider', () {
      final svc = AnalyticsService.instance;
      expect(() => svc.reset(), returnsNormally);
    });

    test('setProvider accepts a custom provider', () {
      final calls = <String>[];
      final provider = _TestProvider(calls);
      final svc = AnalyticsService.instance;
      svc.setProvider(provider);
      svc.track('test', {'a': 1});
      expect(calls, contains('track:test'));
      svc.identify('u1');
      expect(calls, contains('identify:u1'));
      svc.reset();
      expect(calls, contains('reset'));
    });
  });
}

class _TestProvider implements AnalyticsProvider {
  final List<String> calls;
  _TestProvider(this.calls);

  @override
  void track(String event, Map<String, Object?>? properties) {
    calls.add('track:$event');
  }

  @override
  void identify(String userId, Map<String, Object?>? traits) {
    calls.add('identify:$userId');
  }

  @override
  void reset() {
    calls.add('reset');
  }
}
