import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/levels.dart';

void main() {
  test('level thresholds: 0 → L1, 99 → L1, 100 → L2', () {
    expect(levelStatsFor(0).level, 1);
    expect(levelStatsFor(99).level, 1);
    expect(levelStatsFor(100).level, 2);
    expect(levelStatsFor(249).level, 2);
    expect(levelStatsFor(250).level, 3);
    expect(levelStatsFor(499).level, 3);
    expect(levelStatsFor(500).level, 4);
    expect(levelStatsFor(999).level, 4);
    expect(levelStatsFor(1000).level, 5);
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

  test('post-fixed-table levels keep advancing', () {
    // L5 starts at 1000, span 1000 → ends 2000. 1500 is mid-L5.
    final mid5 = levelStatsFor(1500);
    expect(mid5.level, 5);
    expect(mid5.xpAtLevelStart, 1000);
    expect(mid5.xpAtNextLevel, 2000);

    // L6 starts at 2000, span 1500 → ends 3500.
    final s6 = levelStatsFor(2000);
    expect(s6.level, 6);
    expect(s6.xpAtLevelStart, 2000);
    expect(s6.xpAtNextLevel, 3500);

    // L7 starts at 3500, span 2000 → ends 5500.
    final s7 = levelStatsFor(3500);
    expect(s7.level, 7);
    expect(s7.xpAtLevelStart, 3500);
    expect(s7.xpAtNextLevel, 5500);
  });

  test('clamps negative input', () {
    expect(levelStatsFor(-50).level, 1);
    expect(levelStatsFor(-50).totalXp, 0);
  });
}
