import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../data/models.dart';
import '../../../data/profile.dart';
import '../../../providers.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/body_utils.dart';
import '../../../utils/time_utils.dart';
import '../../entry/entry_editor_sheet.dart';
import '../../home/home_shell.dart';
import '../../pomodoro/pomodoro_sheet.dart';
import '../../reflection/reflection_sheet.dart';
import '../../tasks/tasks_screen.dart';

class DashGreeting extends StatelessWidget {
  const DashGreeting({
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: palette.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class DashSectionHeader extends StatelessWidget {
  const DashSectionHeader({
    required this.label,
    required this.palette,
    this.trailing,
    this.onTrailingTap,
  });

  final String label;
  final NoeticaPalette palette;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            onTap: onTrailingTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                trailing!,
                style: TextStyle(
                  color: onTrailingTap != null ? palette.fg : palette.muted,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NowFocusCard extends ConsumerWidget {
  const NowFocusCard({
    required this.task,
    required this.axesById,
    required this.palette,
  });

  final Entry? task;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: palette.muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                S.of(context)!.dashNoActiveTasks,
                style: TextStyle(color: palette.fg, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    final t = task!;
    final overdue = t.dueAt != null && t.dueAt!.isBefore(DateTime.now());
    final firstAxis =
        t.axisIds.isNotEmpty ? axesById[t.axisIds.first] : null;

    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: t),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: overdue ? palette.fg : palette.line,
            width: overdue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.title.isEmpty ? '—' : t.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (firstAxis != null) ...[
                  const SizedBox(width: 8),
                  Text(firstAxis.symbol,
                      style: TextStyle(color: palette.fg, fontSize: 18)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.dueAt != null
                  ? (overdue
                      ? S.of(context)!.dashboardOverdue(formatTimestamp(t.dueAt!))
                      : S.of(context)!.dashboardDueBy(formatTimestamp(t.dueAt!)))
                  : S.of(context)!.editorNoDeadline,
              style: TextStyle(
                color: overdue ? palette.fg : palette.muted,
                fontSize: 12,
                fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            // Primary: mark as done. Secondary: snooze the deadline in
            // case the user is acting on the task but not ready to
            // finish yet ("иду в качалку — дай ещё час"). Pomodoro /
            // focus timer is reachable from the AppBar icon; baking
            // it into the card as a primary CTA made no sense for the
            // majority of tasks (physical, chores, errands).
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        toggleTaskWithReflection(context, ref, t),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(S.of(context)!.dashDone),
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: palette.fg,
                      foregroundColor: palette.bg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _snoozeTask(context, ref, t),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(S.of(context)!.dashPostpone),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: palette.fg,
                      side: BorderSide(color: palette.line),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: S.of(context)!.dashFocusTimer,
                  onPressed: () => PomodoroSheet.show(context),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  color: palette.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _snoozeTask(
    BuildContext context,
    WidgetRef ref,
    Entry t,
  ) async {
    final palette = this.palette;
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        Widget opt(String label, Duration d) {
          return ListTile(
            dense: true,
            title: Text(label, style: TextStyle(color: palette.fg)),
            onTap: () => Navigator.of(context).pop(d),
          );
        }
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    S.of(context)!.dashPostponeBy,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              opt(S.of(context)!.dashboardPostpone15m, const Duration(minutes: 15)),
              opt(S.of(context)!.dashboardPostpone1h, const Duration(hours: 1)),
              opt(S.of(context)!.dashboardPostpone1d, const Duration(days: 1)),
              opt(S.of(context)!.dashboardPostpone3d, const Duration(days: 3)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    final base = t.dueAt ?? DateTime.now();
    final next = t.copyWith(
      dueAt: base.add(choice),
      updatedAt: DateTime.now(),
    );
    final repo = await ref.read(repositoryProvider.future);
    await repo.upsertEntry(next);
  }
}

class CompactTaskRow extends ConsumerWidget {
  const CompactTaskRow({
    required this.task,
    required this.axesById,
    required this.palette,
  });

  final Entry task;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue =
        task.dueAt != null && task.dueAt!.isBefore(DateTime.now());
    final firstAxis =
        task.axisIds.isNotEmpty ? axesById[task.axisIds.first] : null;

    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: task),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            InkWell(
              onTap: () => toggleTaskWithReflection(context, ref, task),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.fg, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title.isEmpty ? '—' : task.title,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.dueAt != null) ...[
              const SizedBox(width: 8),
              Text(
                _shortDue(task.dueAt!, S.of(context)!),
                style: TextStyle(
                  color: overdue ? palette.fg : palette.muted,
                  fontSize: 11,
                  fontWeight:
                      overdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
            if (firstAxis != null) ...[
              const SizedBox(width: 8),
              Text(firstAxis.symbol,
                  style: TextStyle(color: palette.fg, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

class CompactEntryRow extends ConsumerWidget {
  const CompactEntryRow({
    required this.entry,
    required this.axesById,
    required this.palette,
    this.useCompletedAt = false,
  });

  final Entry entry;
  final Map<String, LifeAxis> axesById;
  final NoeticaPalette palette;

  /// When true (e.g. in the "НЕДАВНО ЗАКРЫТО" strip) the row's subtitle
  /// shows the task's completion time instead of creation time, which
  /// is what the reader actually cares about in that context.
  final bool useCompletedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstAxis =
        entry.axisIds.isNotEmpty ? axesById[entry.axisIds.first] : null;
    final isTask = entry.isTask;
    return InkWell(
      onTap: () => showEntryEditor(context, ref, existing: entry),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                isTask
                    ? (entry.isCompleted
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank)
                    : Icons.short_text,
                size: 14,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty
                        ? (entry.body.isEmpty ? '—' : bodyToPlainText(entry.body))
                        : entry.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formatTimestamp(useCompletedAt
                        ? (entry.completedAt ?? entry.createdAt)
                        : entry.createdAt),
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (firstAxis != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(firstAxis.symbol,
                    style: TextStyle(color: palette.muted, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

String _shortDue(DateTime due, S tr) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final delta = dueDay.difference(today).inDays;
  final hh = due.hour.toString().padLeft(2, '0');
  final mm = due.minute.toString().padLeft(2, '0');
  if (delta == 0) return '$hh:$mm';
  if (delta == 1) return tr.dashboardTomorrow('$hh:$mm');
  if (delta == -1) return tr.dashboardYesterday('$hh:$mm');
  if (delta < 0) return '${-delta}d ago';
  if (delta < 7) return 'in $delta d';
  return '$dueDay'.substring(0, 10);
}

class AllTasksLink extends StatelessWidget {
  const AllTasksLink({required this.label, required this.palette});

  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 28),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
        ),
        child: Text(
          '$label →',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
      ),
    );
  }
}

class WeeklyBanner extends StatelessWidget {
  const WeeklyBanner({required this.palette, required this.onOpen});

  final NoeticaPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.fg, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, color: palette.fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.dashboardWeekPassed,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    S.of(context)!.dashboardReflectPrompt,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: palette.fg, size: 18),
          ],
        ),
      ),
    );
  }
}

/// First-run dashboard. Replaces the old "Здесь пока пусто" stub which
/// left the user staring at an empty screen with no obvious next step.
/// We now show a personalised greeting + three CTA cards that map 1:1
/// to the most useful first actions: generate a task plan from the
/// onboarding aspiration, explore the pentagon, or jot a free-form
/// note. The cards self-dismiss as soon as the user creates their first
/// entry (this whole widget only renders when `entries.isEmpty`).
class OnboardingHints extends StatelessWidget {
  const OnboardingHints({
    required this.palette,
    required this.profile,
    required this.onCreateEntry,
    required this.onOpenRoadmap,
    required this.onOpenKnowledge,
    required this.onOpenSelf,
  });

  final NoeticaPalette palette;
  final UserProfile? profile;
  final VoidCallback onCreateEntry;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenSelf;

  @override
  Widget build(BuildContext context) {
    final aspiration = profile?.aspiration.trim() ?? '';
    final name = profile?.name.trim() ?? '';
    final tr = S.of(context)!;
    final greeting = name.isEmpty ? tr.dashboardGreetingAnon : tr.dashboardGreeting(name);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24 + kFloatingTabBarReserve),
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          tr.dashboardOnboardingHint,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 22),
        HintCard(
          palette: palette,
          icon: Icons.auto_awesome,
          accent: const Color(0xFFA78BFA),
          title: tr.dashboardRoadmapTitle,
          subtitle: aspiration.isEmpty
              ? tr.dashboardRoadmapNoGoal
              : tr.dashboardRoadmapWithGoal(aspiration),
          ctaLabel: tr.dashboardGenerate,
          onPressed: onOpenRoadmap,
        ),
        const SizedBox(height: 12),
        HintCard(
          palette: palette,
          icon: Icons.account_tree_outlined,
          accent: const Color(0xFF60A5FA),
          title: tr.dashboardGraphTitle,
          subtitle: tr.dashboardGraphHint,
          ctaLabel: tr.dashboardOpenGraph,
          onPressed: onOpenKnowledge,
        ),
        const SizedBox(height: 12),
        HintCard(
          palette: palette,
          icon: Icons.edit_note_outlined,
          accent: const Color(0xFF34D399),
          title: tr.dashboardNoteTitle,
          subtitle: tr.dashboardNoteHint,
          ctaLabel: tr.dashboardCreate,
          onPressed: onCreateEntry,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onOpenSelf,
            icon: const Icon(Icons.radar_outlined, size: 16),
            label: Text(S.of(context)!.dashViewPentagram),
            style: TextButton.styleFrom(
              foregroundColor: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class HintCard extends StatelessWidget {
  const HintCard({
    required this.palette,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onPressed,
  });

  final NoeticaPalette palette;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.muted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(ctaLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
