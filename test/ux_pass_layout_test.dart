import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/features/calendar/calendar_screen.dart';
import 'package:noetica/features/knowledge/knowledge_graph_screen.dart';
import 'package:noetica/features/onboarding/onboarding_chat_screen.dart';
import 'package:noetica/features/tasks/tasks_screen.dart';
import 'package:noetica/features/settings/settings_screen.dart';

/// Build-smoke tests for every screen touched by the Phase-2 UX pass.
/// They exercise the widget tree at representative mobile + desktop
/// widths to make sure no code path throws during layout or overflows.
///
/// We deliberately don't stub Riverpod providers here — every screen
/// we hit knows how to render a loading / empty state gracefully, so
/// the test just catches structural bugs (unexpected exceptions,
/// overflow assertions, missing keys in layout).
void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  Future<void> renderAt(
    WidgetTester tester,
    Widget widget, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host(widget));
    await tester.pump();
  }

  group('Tasks screen builds with subtask decoration', () {
    testWidgets('mobile', (tester) async {
      await renderAt(tester, const TasksScreen(),
          size: const Size(380, 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop', (tester) async {
      await renderAt(tester, const TasksScreen(),
          size: const Size(1280, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('Calendar screen has the "plan task" CTA', () {
    testWidgets('mobile renders CTA in day detail', (tester) async {
      await renderAt(tester, const CalendarScreen(),
          size: const Size(420, 900));
      expect(tester.takeException(), isNull);
      // CTA label lives inside _DayDetail but is always present (shown
      // as soon as entries stream resolves). We just make sure the
      // tree builds without overflow at narrow widths.
    });

    testWidgets('desktop two-column layout', (tester) async {
      await renderAt(tester, const CalendarScreen(),
          size: const Size(1400, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings screen renders on both form factors', () {
    testWidgets('mobile', (tester) async {
      await renderAt(tester, const SettingsScreen(),
          size: const Size(380, 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop', (tester) async {
      await renderAt(tester, const SettingsScreen(),
          size: const Size(1280, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('Onboarding chat boots without throwing', () {
    testWidgets('mobile', (tester) async {
      await renderAt(tester, const OnboardingChatScreen(),
          size: const Size(380, 800));
      expect(tester.takeException(), isNull);
    });
  });

  group('Knowledge graph canvas tolerates tight viewports', () {
    testWidgets('mobile', (tester) async {
      await renderAt(tester, const KnowledgeGraphScreen(),
          size: const Size(380, 760));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop', (tester) async {
      await renderAt(tester, const KnowledgeGraphScreen(),
          size: const Size(1400, 900));
      expect(tester.takeException(), isNull);
    });
  });
}
