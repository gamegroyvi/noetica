import 'package:flutter/foundation.dart';

/// Lifetime level math. Pure: no I/O, no DB.
///
/// Lifetime XP is the sum of `xp` over all completed tasks (no decay window;
/// the pentagon already shows the 30-day decay, but the user level should be
/// permanent reward — completing things should always feel like "you grew",
/// not "you grew briefly and then lost it").
///
/// Thresholds (cumulative XP needed to *enter* a level):
///   L1 =    0
///   L2 =  100
///   L3 =  250
///   L4 =  450
///   L5 =  700
///   L6 = 1000
///   L7+: span(level) = 50 + level × 50.
/// So the curve gets steadily harder as the user climbs (no plateau), but
/// the early ramps are softer than v1 — getting to L4 is now reachable in
/// a few good weeks instead of a couple of months. Matches the
/// "возрастающие пороги" answer in docs/redesign-v2.md.
@immutable
class LevelStats {
  const LevelStats({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
    required this.xpAtLevelStart,
    required this.xpAtNextLevel,
  });

  final int totalXp;
  final int level;

  /// Progress from this level's start toward the next level (0..xpForLevel).
  final int xpIntoLevel;

  /// XP needed to span from this level's start to the next.
  final int xpForLevel;

  final int xpAtLevelStart;
  final int xpAtNextLevel;

  /// 0..1 progress to next level.
  double get progress => xpForLevel == 0 ? 1.0 : xpIntoLevel / xpForLevel;
}

/// Cumulative XP at the *start* of each level, L1..L6.
/// L6 onwards uses [_spanForLevel].
const List<int> _kFixedStarts = [0, 100, 250, 450, 700, 1000];

/// Span needed to cross from level [n] to level [n+1].
/// For L1..L5 the span is read from [_kFixedStarts]; for L≥6 we use the
/// "50 + level*50" growth curve.
int _spanForLevel(int level) {
  // L≥6: L6 → 350, L7 → 400, L8 → 450, ...
  return 50 + level * 50;
}

LevelStats levelStatsFor(int totalXp) {
  if (totalXp < 0) totalXp = 0;

  // Levels 1..4 read straight from the fixed table.
  for (var i = 0; i < _kFixedStarts.length - 1; i++) {
    final start = _kFixedStarts[i];
    final next = _kFixedStarts[i + 1];
    if (totalXp < next) {
      return LevelStats(
        totalXp: totalXp,
        level: i + 1,
        xpIntoLevel: totalXp - start,
        xpForLevel: next - start,
        xpAtLevelStart: start,
        xpAtNextLevel: next,
      );
    }
  }

  // L6 and beyond: span = 50 + level * 50.
  var level = _kFixedStarts.length; // 6
  var start = _kFixedStarts.last; // 1000
  while (true) {
    final span = _spanForLevel(level);
    final next = start + span;
    if (totalXp < next) {
      return LevelStats(
        totalXp: totalXp,
        level: level,
        xpIntoLevel: totalXp - start,
        xpForLevel: span,
        xpAtLevelStart: start,
        xpAtNextLevel: next,
      );
    }
    start = next;
    level += 1;
  }
}
