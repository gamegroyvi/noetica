import '../../../data/models.dart';

/// Lightweight aggregations for the dashboard. All time math is calendar
/// based to stay stable across DST transitions.
class DashboardStats {
  DashboardStats({
    required this.streak,
    required this.todayCompleted,
    required this.weekCompleted,
    required this.perDay,
    required this.heatmap,
    required this.totalXpToday,
    required this.totalXpWeek,
    required this.bestAxis,
    required this.bestAxisXp,
    required this.nextDeadline,
  });

  final int streak;
  final int todayCompleted;
  final int weekCompleted;

  /// Last 7 days of completed-task counts (oldest → today).
  final List<int> perDay;

  /// Last 91 days (13 weeks) of completed-task counts, oldest → today.
  final List<int> heatmap;

  final int totalXpToday;
  final int totalXpWeek;

  /// Axis ID with the highest XP earned in the past 7 days, or null.
  final String? bestAxis;
  final int bestAxisXp;

  /// Earliest future due date among non-completed tasks, or null.
  final DateTime? nextDeadline;

  factory DashboardStats.from(List<Entry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeDays = <DateTime>{};
    for (final e in entries) {
      activeDays.add(DateTime(
        e.createdAt.year,
        e.createdAt.month,
        e.createdAt.day,
      ));
    }
    var streak = 0;
    var cursor = today;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    const heatmapDays = 91;
    final perDay = List<int>.filled(7, 0);
    final heatmap = List<int>.filled(heatmapDays, 0);
    var totalXpToday = 0;
    var totalXpWeek = 0;
    final perAxisXpWeek = <String, int>{};
    DateTime? nextDeadline;

    for (final e in entries) {
      if (e.isTask && !e.isCompleted && e.dueAt != null && e.dueAt!.isAfter(now)) {
        if (nextDeadline == null || e.dueAt!.isBefore(nextDeadline)) {
          nextDeadline = e.dueAt;
        }
      }
      final completedAt = e.completedAt;
      if (completedAt == null) continue;
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      final diff = today.difference(day).inDays;
      if (diff >= 0 && diff < 7) {
        perDay[6 - diff] += 1;
      }
      if (diff >= 0 && diff < heatmapDays) {
        heatmap[heatmapDays - 1 - diff] += 1;
      }
      if (diff == 0) totalXpToday += e.xp;
      if (diff >= 0 && diff < 7) {
        totalXpWeek += e.xp;
        final ids = e.axisIds;
        if (ids.isNotEmpty) {
          final share = e.xp / ids.length;
          for (final id in ids) {
            perAxisXpWeek[id] =
                (perAxisXpWeek[id] ?? 0) + share.round();
          }
        }
      }
    }

    String? bestAxis;
    var bestAxisXp = 0;
    perAxisXpWeek.forEach((k, v) {
      if (v > bestAxisXp) {
        bestAxis = k;
        bestAxisXp = v;
      }
    });

    return DashboardStats(
      streak: streak,
      todayCompleted: perDay[6],
      weekCompleted: perDay.fold(0, (a, b) => a + b),
      perDay: perDay,
      heatmap: heatmap,
      totalXpToday: totalXpToday,
      totalXpWeek: totalXpWeek,
      bestAxis: bestAxis,
      bestAxisXp: bestAxisXp,
      nextDeadline: nextDeadline,
    );
  }
}
