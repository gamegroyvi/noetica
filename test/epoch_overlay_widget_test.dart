import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/data/profile.dart';
import 'package:noetica/features/self/epoch_ceremony.dart';
import 'package:noetica/theme/app_theme.dart' as t;

/// Renders [EpochOverlay] directly so we can smoke-test the two
/// entry/exit paths without standing up a full Scaffold + providers.
Widget _harness({
  required UserProfile profile,
  required bool visible,
  required Widget child,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: t.AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 700,
            child: EpochOverlay(
              profile: profile,
              visible: visible,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const _sentinelKey = Key('tree-sentinel');
  const _tree = Center(
    key: _sentinelKey,
    child: Text('tree'),
  );

  UserProfile build({
    int epoch = 1,
    int tier = 1,
  }) =>
      UserProfile(
        name: 'Ира',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 0,
        updatedAt: DateTime(2024),
        currentEpoch: epoch,
        epochTier: tier,
      );

  testWidgets(
    'child tree is always visible; overlay card only appears when visible=true',
    (tester) async {
      await tester.pumpWidget(_harness(
        profile: build(),
        visible: false,
        child: _tree,
      ));
      expect(find.byKey(_sentinelKey), findsOneWidget);
      expect(find.text('Ты заполнил древо.'), findsNothing);

      await tester.pumpWidget(_harness(
        profile: build(),
        visible: true,
        child: _tree,
      ));
      // Enter animation settles quickly; pumpAndSettle is bounded by
      // the overlay's internal 380ms controller.
      await tester.pumpAndSettle();
      expect(find.byKey(_sentinelKey), findsOneWidget);
      expect(find.text('Ты заполнил древо.'), findsOneWidget);
      expect(find.text('Новая эпоха'), findsOneWidget);
      expect(find.text('Углубиться'), findsOneWidget);
    },
  );

  testWidgets('label for Новая эпоха includes the next epoch number',
      (tester) async {
    await tester.pumpWidget(_harness(
      profile: build(epoch: 4),
      visible: true,
      child: _tree,
    ));
    await tester.pumpAndSettle();
    // Subtitle references "Эпоха 5" (current + 1).
    expect(
      find.textContaining('Эпоха 5'),
      findsOneWidget,
    );
  });

  testWidgets('Углубиться tile references the next tier number',
      (tester) async {
    await tester.pumpWidget(_harness(
      profile: build(epoch: 2, tier: 2),
      visible: true,
      child: _tree,
    ));
    await tester.pumpAndSettle();
    // Tier bumps from 2 to 3.
    expect(find.textContaining('Тир 3'), findsOneWidget);
  });

  testWidgets('scrim tap invokes onDismissed', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: t.AppTheme.dark(),
          home: Scaffold(
            body: EpochOverlay(
              profile: build(),
              visible: true,
              onDismissed: () => dismissed++,
              child: _tree,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Tap in a corner far from the centered card so only the scrim
    // (top-level GestureDetector beneath the card) handles it.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(dismissed, greaterThanOrEqualTo(1));
  });
}
