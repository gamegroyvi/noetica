import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/levels.dart';

void main() {
  test('escalating thresholds: 0 → L1, 100 → L2, 250 → L3, 450 → L4, '
      '700 → L5, 1000 → L6', () {
    expect(levelStatsFor(0).level, 1);
    expect(levelStatsFor(99).level, 1);
    expect(levelStatsFor(100).level, 2);
    expect(levelStatsFor(249).level, 2);
    expect(levelStatsFor(250).level, 3);
    expect(levelStatsFor(449).level, 3);
    expect(levelStatsFor(450).level, 4);
    expect(levelStatsFor(699).level, 4);
    expect(levelStatsFor(700).level, 5);
    expect(levelStatsFor(999).level, 5);
    expect(levelStatsFor(1000).level, 6);
  });

  test('progress is 0..1 within current level', () {
    final s = levelStatsFor(150);
    expect(s.level, 2);
    expect(s.xpAtLevelStart, 100);
    expect(s.xpAtNextLevel, 250);
    expect(s.xpIntoLevel, 50);
    expect(s.xpForLevel, 150);
    expect(s.progress, closeTo(50 / 150, 1e-9));
  });

  test('post-fixed-table levels keep advancing with 50 + level*50 spans', () {
    // L6 starts at 1000, span = 50 + 6*50 = 350 → ends 1350.
    final s6 = levelStatsFor(1000);
    expect(s6.level, 6);
    expect(s6.xpAtLevelStart, 1000);
    expect(s6.xpAtNextLevel, 1350);

    // L7 starts at 1350, span = 50 + 7*50 = 400 → ends 1750.
    final s7 = levelStatsFor(1350);
    expect(s7.level, 7);
    expect(s7.xpAtLevelStart, 1350);
    expect(s7.xpAtNextLevel, 1750);

    // L8 starts at 1750, span = 50 + 8*50 = 450 → ends 2200.
    final s8 = levelStatsFor(1750);
    expect(s8.level, 8);
    expect(s8.xpAtLevelStart, 1750);
    expect(s8.xpAtNextLevel, 2200);
  });

  test('clamps negative input', () {
    expect(levelStatsFor(-50).level, 1);
    expect(levelStatsFor(-50).totalXp, 0);
  });

  group('эпохи', () {
    test('epoch starts at 1 for a freshly-created axis', () {
      expect(epochFromXp(0), 1);
      expect(epochFromXp(-10), 1);
    });

    test('advances once per kXpPerEpoch accumulated on an axis', () {
      expect(epochFromXp(kXpPerEpoch - 1), 1);
      expect(epochFromXp(kXpPerEpoch), 2);
      expect(epochFromXp(kXpPerEpoch * 2 - 1), 2);
      expect(epochFromXp(kXpPerEpoch * 2), 3);
    });

    test('xpToNextEpoch reports countdown to the next threshold', () {
      // Right at the start of эпоха 2 → full kXpPerEpoch to reach эпоха 3.
      expect(xpToNextEpoch(kXpPerEpoch), kXpPerEpoch);
      // Halfway through эпоха 1 → half of kXpPerEpoch left.
      expect(
        xpToNextEpoch(kXpPerEpoch ~/ 2),
        kXpPerEpoch - kXpPerEpoch ~/ 2,
      );
    });
  });
}
