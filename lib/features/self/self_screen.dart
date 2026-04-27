import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../services/levels.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_glyph.dart';
import '../roadmap/roadmap_screen.dart';
import '../settings/settings_screen.dart';
import '../home/home_shell.dart';
import 'axes_editor_screen.dart';
import 'axis_detail_sheet.dart';
import 'epoch_ceremony.dart';
import 'pentagon_painter.dart';

class SelfScreen extends ConsumerStatefulWidget {
  const SelfScreen({super.key});

  @override
  ConsumerState<SelfScreen> createState() => _SelfScreenState();
}

class _SelfScreenState extends ConsumerState<SelfScreen> {
  bool _rearmInFlight = false;

  /// Which эпоха the user is currently *viewing*. `null` means the
  /// live current эпоха (the default — full editing UI). Any other
  /// integer addresses an entry in `profile.epochArchive`, in which
  /// case we render a read-only retrospective view of that эпоха.
  int? _viewedEpoch;

  /// Page transition direction for the slide animation between
  /// epochs. +1 means we're going to a *newer* эпоха (i.e. tapping a
  /// chip to the right of the current one), −1 means *older*. We
  /// drive this with each chip tap so the new content slides in from
  /// the correct side.
  int _slideDir = 1;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scoresAsync = ref.watch(scoresProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final streakAsync = ref.watch(streakProvider);
    final levelAsync = ref.watch(levelStatsProvider);
    final axisLevelsAsync = ref.watch(axisLevelStatsProvider);
    final hasName = profile != null && profile.name.isNotEmpty;

    // Re-arm logic only — the ceremony itself is no longer a modal.
    // The inline overlay decides on its own whether to be visible
    // based on (pentagonFull && epochAckedAt == null). What we still
    // need to do here is *clear* the ack once any axis dips below 95
    // again, so the next refill re-arms the overlay naturally.
    final scores = scoresAsync.valueOrNull;
    if (profile != null && scores != null && scores.length >= 3) {
      final isFull = EpochCeremony.pentagonFull(scores);
      if (!isFull && profile.epochAckedAt != null && !_rearmInFlight) {
        _rearmInFlight = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final svc = ref.read(profileServiceProvider);
          await svc.save(profile.copyWith(
            clearEpochAckedAt: true,
            updatedAt: DateTime.now(),
          ));
          if (mounted) _rearmInFlight = false;
        });
      }
    }

    final canPop = Navigator.of(context).canPop();
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      appBar: AppBar(
        // When pushed (e.g. tapped from the mini-Древо on the dashboard) we
        // want a real back button so the user isn't stranded — don't paint
        // the brand glyph in that case, AppBar will auto-imply the leading.
        leading: canPop
            ? null
            : const Padding(
                padding: EdgeInsets.only(left: 16, top: 12, bottom: 12),
                child: BrandGlyph(size: 24),
              ),
        leadingWidth: canPop ? null : 48,
        title: Text(hasName ? profile.name : 'Я'),
        actions: [
          IconButton(
            tooltip: 'Ветви',
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AxesEditorScreen(),
                ),
              );
            },
          ),
          // On desktop, Settings is a sidebar tab — no need to duplicate
          // it in the AppBar. On mobile it's the primary way in.
          if (isMobile)
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: scoresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (scores) {
          // Build the chip strip. We always show it if at least one
          // эпоха has been completed (archive non-empty) — otherwise
          // a single chip "Эпоха 1 (сейчас)" is just clutter.
          final archive = profile?.epochArchive ?? const <EpochSnapshot>[];
          final currentEpoch = profile?.currentEpoch ?? 1;
          // Clamp the viewed эпоха to a valid one — if profile changes
          // (e.g. after a sync) and our selection is no longer in the
          // archive, fall back to current.
          final selected = _viewedEpoch != null &&
                  (_viewedEpoch == currentEpoch ||
                      archive.any((s) => s.epoch == _viewedEpoch))
              ? _viewedEpoch
              : null;

          // Pick which body widget AnimatedSwitcher will render.
          // We key by the selected эпоха number so AnimatedSwitcher
          // sees a "different" subtree and triggers the slide.
          Widget body;
          if (selected == null || selected == currentEpoch) {
            body = _CurrentEpochBody(
              key: ValueKey<int>(currentEpoch),
              palette: palette,
              profile: profile,
              scores: scores,
              level: levelAsync.valueOrNull,
              streak: streakAsync.valueOrNull ?? 0,
              axisLevels: axisLevelsAsync.valueOrNull,
              onClearAck: () async {
                if (profile == null) return;
                final svc = ref.read(profileServiceProvider);
                await svc.save(profile.copyWith(
                  clearEpochAckedAt: true,
                  updatedAt: DateTime.now(),
                ));
              },
              onAckDismiss: () async {
                if (profile == null || profile.epochAckedAt != null) return;
                final svc = ref.read(profileServiceProvider);
                await svc.save(profile.copyWith(
                  epochAckedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
              },
              onOpenRoadmap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RoadmapScreen()),
              ),
            );
          } else {
            final snap = archive.firstWhere(
              (s) => s.epoch == selected,
              orElse: () => archive.last,
            );
            body = _PastEpochBody(
              key: ValueKey<int>(snap.epoch),
              palette: palette,
              snapshot: snap,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (currentEpoch > 1 || archive.isNotEmpty)
                _EpochStrip(
                  palette: palette,
                  archive: archive,
                  currentEpoch: currentEpoch,
                  selected: selected ?? currentEpoch,
                  onSelect: (e) {
                    final cur = selected ?? currentEpoch;
                    setState(() {
                      _slideDir = e > cur ? 1 : -1;
                      _viewedEpoch = e == currentEpoch ? null : e;
                    });
                  },
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final inFromRight = (child.key as ValueKey<int>?)?.value ==
                            (selected ?? currentEpoch);
                    // Newer эпоха should slide in from the right when
                    // the user moves forward in time, from the left
                    // when they move back. _slideDir captures that.
                    final dir = inFromRight ? _slideDir : -_slideDir;
                    final offset = Tween<Offset>(
                      begin: Offset(dir.toDouble() * 0.18, 0),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Live current-эпоха view — pentagon + axis tiles + plan button.
/// Extracted out of `_SelfScreenState.build` so AnimatedSwitcher can
/// cross-fade with [_PastEpochBody] when the user chips between
/// epochs.
class _CurrentEpochBody extends ConsumerWidget {
  const _CurrentEpochBody({
    super.key,
    required this.palette,
    required this.profile,
    required this.scores,
    required this.level,
    required this.streak,
    required this.axisLevels,
    required this.onClearAck,
    required this.onAckDismiss,
    required this.onOpenRoadmap,
  });

  final NoeticaPalette palette;
  final UserProfile? profile;
  final List<AxisScore> scores;
  final LevelStats? level;
  final int streak;
  final Map<String, LevelStats>? axisLevels;
  final VoidCallback onClearAck;
  final VoidCallback onAckDismiss;
  final VoidCallback onOpenRoadmap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24 + kFloatingTabBarReserve),
      children: [
        _ProfileHeader(
          level: level,
          streak: streak,
          aspiration: profile?.aspiration ?? '',
          epoch: profile?.currentEpoch ?? 1,
          tier: profile?.epochTier ?? 1,
        ),
        const SizedBox(height: 16),
        if (profile != null &&
            scores.length >= 3 &&
            EpochCeremony.pentagonFull(scores) &&
            profile!.epochAckedAt != null)
          _TransitionReadyBanner(palette: palette, onTap: onClearAck),
        const SizedBox(height: 8),
        if (scores.length < 3)
          _EmptyAxes()
        else ...[
          SizedBox(
            height: 320,
            child: profile == null
                ? _DrevoCanvas(scores: scores)
                : EpochOverlay(
                    profile: profile!,
                    visible: EpochCeremony.pentagonFull(scores) &&
                        profile!.epochAckedAt == null,
                    onDismissed: onAckDismiss,
                    child: _DrevoCanvas(scores: scores),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            'ДРЕВО · ВЕТКИ',
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in scores)
            _AxisTile(
              score: s,
              levelStats: axisLevels?[s.axis.id],
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onOpenRoadmap,
            icon: const Icon(Icons.auto_awesome),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Сгенерировать план'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Очки начисляются за выполнение задач, привязанных к осям. Со временем затухают — пентаграмма отражает тебя за последний месяц.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

/// Read-only retrospective of a closed эпоха. Renders the same Древо
/// pentagon + axis tiles, but using the snapshot's frozen scores and
/// axis names — so the user can compare "where I was" to where they
/// are now without leaving the «Я» screen.
class _PastEpochBody extends StatelessWidget {
  const _PastEpochBody({
    super.key,
    required this.palette,
    required this.snapshot,
  });

  final NoeticaPalette palette;
  final EpochSnapshot snapshot;

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    // Rebuild AxisScore objects from the snapshot so the existing
    // pentagon painter / axis-tile widgets work without modification.
    final scores = <AxisScore>[
      for (final a in snapshot.axes)
        AxisScore(
          axis: a,
          value: snapshot.scores[a.id] ?? 0,
          rawXp: 0,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          20, 12, 20, 24 + kFloatingTabBarReserve),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: palette.muted),
                  const SizedBox(width: 8),
                  Text(
                    'ЭПОХА ${snapshot.epoch} · АРХИВ',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_fmt(snapshot.startedAt)} — ${_fmt(snapshot.endedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.fg),
              ),
              const SizedBox(height: 4),
              Text(
                'Древо этой эпохи на момент перехода. Только просмотр.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (scores.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Архив этой эпохи пустой — она завершилась до того, '
              'как мы начали записывать историю. Будущие переходы '
              'сохранятся целиком.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
          )
        else ...[
          SizedBox(
            // IgnorePointer + read-only painter — no axis sheets, no
            // tap handling. We still get the lovely grow / breath
            // animations the live canvas uses.
            height: 320,
            child: IgnorePointer(child: _DrevoCanvas(scores: scores)),
          ),
          const SizedBox(height: 24),
          Text(
            'ВЕТВИ ТОЙ ЭПОХИ',
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in scores)
            _AxisTile(score: s, levelStats: null, readOnly: true),
        ],
      ],
    );
  }
}

/// Horizontal chip strip that lists every эпоха the user has lived in
/// (1..currentEpoch). Tapping a chip switches the body. Epochs that
/// pre-date the archive feature are still listed but marked
/// "архив пуст" so the user understands why they can't drill in.
class _EpochStrip extends StatelessWidget {
  const _EpochStrip({
    required this.palette,
    required this.archive,
    required this.currentEpoch,
    required this.selected,
    required this.onSelect,
  });

  final NoeticaPalette palette;
  final List<EpochSnapshot> archive;
  final int currentEpoch;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final available = <int>{
      for (final s in archive) s.epoch,
      currentEpoch,
    };
    final all = [for (var i = 1; i <= currentEpoch; i++) i];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            for (final e in all) ...[
              _EpochChip(
                palette: palette,
                epoch: e,
                isCurrent: e == currentEpoch,
                isSelected: e == selected,
                hasData: available.contains(e),
                onTap: available.contains(e) ? () => onSelect(e) : null,
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpochChip extends StatelessWidget {
  const _EpochChip({
    required this.palette,
    required this.epoch,
    required this.isCurrent,
    required this.isSelected,
    required this.hasData,
    required this.onTap,
  });

  final NoeticaPalette palette;
  final int epoch;
  final bool isCurrent;
  final bool isSelected;
  final bool hasData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected
        ? palette.bg
        : (hasData ? palette.fg : palette.muted);
    final bg = isSelected ? palette.fg : Colors.transparent;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isSelected ? palette.fg : palette.line,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasData) ...[
              Icon(Icons.lock_outline, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              isCurrent
                  ? 'Эпоха $epoch · сейчас'
                  : (hasData ? 'Эпоха $epoch' : 'Эпоха $epoch · нет данных'),
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.level,
    required this.streak,
    required this.aspiration,
    required this.epoch,
    this.tier = 1,
  });

  final LevelStats? level;
  final int streak;
  final String aspiration;
  final int epoch;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = level;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BigNumber(
                label: 'ЭПОХА',
                value: tier > 1 ? 'Э$epoch.$tier' : 'Э$epoch',
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: 'УРОВЕНЬ',
                value: l == null ? '—' : 'L${l.level}',
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: 'XP',
                value: l == null ? '—' : '${l.totalXp}',
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: 'СТРИК',
                value: streak == 0 ? '—' : '$streak д.',
              ),
            ],
          ),
          if (l != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: l.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'до L${l.level + 1}: ${l.xpForLevel - l.xpIntoLevel} xp',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
          if (aspiration.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '«$aspiration»',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted, fontStyle: FontStyle.italic),
            ),
          ],
          if (streak == 0 && l != null && l.totalXp > 0) ...[
            const SizedBox(height: 12),
            _StreakBreakBanner(),
          ],
        ],
      ),
    );
  }
}

class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: palette.fg,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Small tappable banner that surfaces after the user dismissed the
/// overlay once. It gently indicates "you've got a transition waiting"
/// and re-opens the overlay on tap — no autoreopening on every build,
/// no autohiding either.
class _TransitionReadyBanner extends StatelessWidget {
  const _TransitionReadyBanner({required this.palette, required this.onTap});
  final NoeticaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.fg, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: palette.fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Готов к переходу — тапни, чтобы открыть',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: palette.fg),
          ],
        ),
      ),
    );
  }
}

class _StreakBreakBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.refresh, size: 18, color: palette.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Стрик прервался. Закрой одну задачу сегодня — начнём заново.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAxes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.workspaces_outline, size: 32, color: palette.muted),
          const SizedBox(height: 12),
          Text(
            'Древо вырастает от 3 ветвей. Добавь хотя бы 3 ветви, чтобы '
            'увидеть его.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({
    required this.score,
    this.levelStats,
    this.readOnly = false,
  });
  final AxisScore score;
  final LevelStats? levelStats;

  /// Suppresses the level/XP badges + footer when rendering an
  /// archived эпоха (we don't have those numbers for the past).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = score.value.clamp(0.0, 100.0) / 100.0;
    final ls = levelStats;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score.axis.symbol,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              score.axis.name,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ls != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: palette.line),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'L${ls.level}',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.fg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Э${epochFromXp(ls.totalXp)}',
                                style: TextStyle(
                                  color: palette.bg,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      score.value.round().toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.muted,
                            fontFeatures: const [],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: v),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: palette.line,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.fg),
                    ),
                  ),
                ),
                if (ls != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${ls.totalXp} XP · до L${ls.level + 1}: '
                    '${ls.xpAtNextLevel - ls.totalXp}',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Древо: every time `scores` changes (new task completed,
/// reflection submitted, etc.) the polygon tweens out from 0 → its new
/// size, giving the user a visceral "ветка выросла" cue. Tap on a
/// branch label to open the per-axis detail sheet.
class _DrevoCanvas extends ConsumerStatefulWidget {
  const _DrevoCanvas({required this.scores});
  final List<AxisScore> scores;

  @override
  ConsumerState<_DrevoCanvas> createState() => _DrevoCanvasState();
}

class _DrevoCanvasState extends ConsumerState<_DrevoCanvas>
    with TickerProviderStateMixin {
  // One-shot grow animation, replayed when scores change. We use
  // easeOutBack for a slight spring overshoot so the polygon visibly
  // springs into place instead of merely settling.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  // Continuous idle "breathing" — slow oscillation in radius (~±2%) so the
  // tree never feels frozen. Loops indefinitely.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Short reaction pulse fired every time a score increases. Drives a
  // small overshoot that overlays on top of the steady-state shape.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  int? _highlight;

  @override
  void didUpdateWidget(covariant _DrevoCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay the grow animation only when the actual axis values changed
    // — not on every parent rebuild — so casual scrolling doesn't jitter
    // the canvas.
    var changed = oldWidget.scores.length != widget.scores.length;
    var increased = false;
    if (!changed) {
      for (var i = 0; i < oldWidget.scores.length; i++) {
        final delta = widget.scores[i].value - oldWidget.scores[i].value;
        if (delta.abs() > 0.01) changed = true;
        if (delta > 0.01) increased = true;
      }
    }
    if (changed) {
      _grow
        ..reset()
        ..forward();
    }
    if (increased) {
      _pulse
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _breath.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            // Build a one-shot painter to reuse its hit-test math.
            final probe = PentagonPainter(
              scores: widget.scores,
              fg: palette.fg,
              muted: palette.muted,
              line: palette.line,
              bg: palette.bg,
            );
            final hit = probe.hitTestAxis(d.localPosition, size);
            if (hit == null) return;
            setState(() => _highlight = hit);
            showAxisDetailSheet(
              context,
              ref,
              score: widget.scores[hit],
            ).whenComplete(() {
              if (mounted) setState(() => _highlight = null);
            });
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_grow, _breath, _pulse]),
            builder: (_, __) {
              final grow = Curves.easeOutBack.transform(_grow.value).clamp(0.0, 1.05);
              final breath = 1 + 0.018 *
                  math.sin(_breath.value * 2 * math.pi);
              final pulse = _pulse.isAnimating
                  ? 1 +
                      0.06 *
                          math.sin(_pulse.value * math.pi) *
                          (1 - _pulse.value)
                  : 1.0;
              final progress = grow * breath * pulse;
              return CustomPaint(
                painter: PentagonPainter(
                  scores: widget.scores,
                  fg: palette.fg,
                  muted: palette.muted,
                  line: palette.line,
                  bg: palette.bg,
                  progress: progress.toDouble(),
                  highlightedAxisIndex: _highlight,
                  bloomedAxes:
                      EpochCeremony.bloomedAxes(widget.scores),
                  bloomPulse: _breath.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        );
      },
    );
  }
}
