import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/features/dashboard/dashboard_screen.dart';
import 'package:noetica/features/home/home_shell.dart';

/// Renders the dashboard at narrow + wide widths to make sure the new
/// layout code paths don't throw or overflow during build. We don't
/// override the Riverpod providers — the dashboard handles loading
/// states gracefully (CircularProgressIndicator) and the test only
/// needs to confirm the widget tree builds without exceptions.
void main() {
  testWidgets('DashboardScreen builds at mobile width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(380 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('DashboardScreen builds at desktop width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeShell builds at desktop width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
