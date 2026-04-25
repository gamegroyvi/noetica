import 'package:flutter/foundation.dart';

/// Lifetime level math. Pure: no I/O, no DB.
///
/// Lifetime XP is the sum of `xp` over all completed tasks (no decay window;
/// the pentagon already shows the 30-day decay, but the user level should be
/// permanent reward — completing things should always feel like "you grew",
/// not "you grew briefly and then lost it").
///
/// Thresholds (cumulative XP needed to *enter* a level):
///   L1 = 0
///   L2 = 100
///   L3 = 250
///   L4 = 500
///   L5 = 1000
///   L6+: previous + (level × 500), so L6 = 1500, L7 = 2500, L8 = 4000, ...
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

/// Cumulative XP at the *start* of each level, L1..L5.
/// L5 onwards uses [_spanForLevel].
const List<int> _kFixedStarts = [0, 100, 250, 500, 1000];

/// Span needed to cross from level [n] to level [n+1].
/// For L1..L4 the span is read from [_kFixedStarts]; for L≥5 we use a
/// gentle linear curve so progress stays meaningful at high levels.
int _spanForLevel(int level) {
  // L≥5: span(n) = (n - 3) * 500 → L5=1000, L6=1500, L7=2000, ...
  return (level - 3) * 500;
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

  // L5 and beyond: linear span growth.
  var level = _kFixedStarts.length; // 5
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
