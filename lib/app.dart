import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/profile.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/questionnaire_screen.dart';
import 'providers.dart';
import 'theme/app_theme.dart';

class NoeticaApp extends ConsumerWidget {
  const NoeticaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final onboardedAsync = ref.watch(onboardedProvider);
    return MaterialApp(
      title: 'Noetica',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _resolveScreen(profileAsync, onboardedAsync),
      ),
    );
  }

  Widget _resolveScreen(
    AsyncValue<UserProfile?> profileAsync,
    AsyncValue<bool> onboardedAsync,
  ) {
    if (profileAsync.isLoading || onboardedAsync.isLoading) {
      return const _SplashScreen(key: ValueKey('splash'));
    }
    final profileError = profileAsync.error;
    if (profileError != null) {
      return _ErrorScreen(
        key: const ValueKey('err-profile'),
        message: profileError.toString(),
      );
    }
    final onboardError = onboardedAsync.error;
    if (onboardError != null) {
      return _ErrorScreen(
        key: const ValueKey('err-onboard'),
        message: onboardError.toString(),
      );
    }
    final profile = profileAsync.value;
    final onboarded = onboardedAsync.value ?? false;
    if (profile == null) {
      return const QuestionnaireScreen(key: ValueKey('questionnaire'));
    }
    if (!onboarded) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        seedPriorities: profile.priorities,
      );
    }
    return const HomeShell(key: ValueKey('home'));
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'noetica',
          style: TextStyle(fontSize: 28, letterSpacing: 4),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
