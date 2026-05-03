import 'package:flutter/foundation.dart';

/// Lightweight analytics abstraction. Events are logged via [debugPrint]
/// in debug builds and forwarded to an external provider (PostHog,
/// Mixpanel, Amplitude, etc.) when one is configured.
///
/// Call [AnalyticsService.instance.track] from anywhere — the service
/// is a fire-and-forget singleton; no async, no context needed.
///
/// Adding a real provider later:
/// 1. Implement [AnalyticsProvider] (e.g. `PostHogProvider`).
/// 2. Call `AnalyticsService.instance.setProvider(PostHogProvider(...))`.
/// 3. That's it — every `track()` call routes through the provider.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsProvider? _provider;

  /// Plug in an external analytics provider. Until this is called,
  /// events are only printed in debug mode.
  void setProvider(AnalyticsProvider provider) {
    _provider = provider;
  }

  /// Track a named event with optional properties.
  void track(String event, [Map<String, Object?>? properties]) {
    assert(() {
      debugPrint('[analytics] $event ${properties ?? ''}');
      return true;
    }());
    _provider?.track(event, properties);
  }

  /// Identify the current user (e.g. after sign-in).
  void identify(String userId, [Map<String, Object?>? traits]) {
    assert(() {
      debugPrint('[analytics] identify $userId ${traits ?? ''}');
      return true;
    }());
    _provider?.identify(userId, traits);
  }

  /// Reset identity (e.g. on sign-out).
  void reset() {
    _provider?.reset();
  }
}

/// Contract for external analytics providers.
abstract class AnalyticsProvider {
  void track(String event, Map<String, Object?>? properties);
  void identify(String userId, Map<String, Object?>? traits);
  void reset();
}

/// Predefined event names — keeps instrumentation typo-free and
/// searchable. Add new events here as features grow.
abstract final class AnalyticsEvents {
  // ---- onboarding ----
  static const onboardingStarted = 'onboarding_started';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingStepCompleted = 'onboarding_step_completed';

  // ---- core actions ----
  static const taskCreated = 'task_created';
  static const taskCompleted = 'task_completed';
  static const noteCreated = 'note_created';
  static const entryDeleted = 'entry_deleted';
  static const reflectionSubmitted = 'reflection_submitted';
  static const weeklyReflectionSubmitted = 'weekly_reflection_submitted';

  // ---- AI features ----
  static const roadmapGenerated = 'roadmap_generated';
  static const menuGenerated = 'menu_generated';
  static const recipeGenerated = 'recipe_generated';
  static const axesGenerated = 'axes_generated';
  static const aiGenerationBlocked = 'ai_generation_blocked_limit';

  // ---- navigation ----
  static const screenViewed = 'screen_viewed';
  static const sidebarItemTapped = 'sidebar_item_tapped';

  // ---- premium / monetisation ----
  static const paywallShown = 'paywall_shown';
  static const paywallDismissed = 'paywall_dismissed';
  static const purchaseStarted = 'purchase_started';
  static const purchaseCompleted = 'purchase_completed';
  static const subscriptionExpired = 'subscription_expired';

  // ---- epochs ----
  static const epochCompleted = 'epoch_completed';
  static const epochTierUp = 'epoch_tier_up';

  // ---- retention signals ----
  static const appOpened = 'app_opened';
  static const pomodoroStarted = 'pomodoro_started';
  static const pomodoroCompleted = 'pomodoro_completed';
  static const streakMilestone = 'streak_milestone';
}
