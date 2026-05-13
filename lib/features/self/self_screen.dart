import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
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
import 'epoch_ceremony.dart';
import 'widgets/axis_tile.dart';
import 'widgets/drevo_canvas.dart';

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
          final svc = await ref.read(profileServiceProvider.future);
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
        title: Text(hasName ? profile.name : S.of(context)!.tabSelf),
        actions: [
          IconButton(
            tooltip: S.of(context)!.selfBranchesTooltip,
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
              tooltip: S.of(context)!.selfSettingsTooltip,
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
                final svc = await ref.read(profileServiceProvider.future);
                await svc.save(profile.copyWith(
                  clearEpochAckedAt: true,
                  updatedAt: DateTime.now(),
                ));
              },
              onAckDismiss: () async {
                if (profile == null || profile.epochAckedAt != null) return;
                final svc = await ref.read(profileServiceProvider.future);
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
                ? DrevoCanvas(scores: scores)
                : EpochOverlay(
                    profile: profile!,
                    visible: EpochCeremony.pentagonFull(scores) &&
                        profile!.epochAckedAt == null,
                    onDismissed: onAckDismiss,
                    child: DrevoCanvas(scores: scores),
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            S.of(context)!.selfTreeBranches,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in scores)
            AxisTile(
              score: s,
              levelStats: axisLevels?[s.axis.id],
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onOpenRoadmap,
            icon: const Icon(Icons.auto_awesome),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(S.of(context)!.selfGeneratePlan),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.selfScoreExplain,
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
                    S.of(context)!.selfEpochArchive(snapshot.epoch),
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
                S.of(context)!.selfArchiveReadonly,
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
              S.of(context)!.selfArchiveEmpty,
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
            child: IgnorePointer(child: DrevoCanvas(scores: scores)),
          ),
          const SizedBox(height: 24),
          Text(
            S.of(context)!.selfArchiveBranches,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in scores)
            AxisTile(score: s, levelStats: null, readOnly: true),
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
                  ? '${S.of(context)!.selfEpoch(epoch)} · now'
                  : (hasData ? S.of(context)!.selfEpoch(epoch) : S.of(context)!.selfEpochNoData(epoch)),
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
                label: S.of(context)!.selfEpochLabel,
                value: tier > 1 ? S.of(context)!.selfEpochTierShort('$epoch', '$tier') : S.of(context)!.selfEpochShort('$epoch'),
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: S.of(context)!.selfLevelLabel,
                value: l == null ? '—' : 'L${l.level}',
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: 'XP',
                value: l == null ? '—' : '${l.totalXp}',
              ),
              const SizedBox(width: 20),
              _BigNumber(
                label: S.of(context)!.selfStreakLabel,
                value: streak == 0 ? '—' : S.of(context)!.selfStreakDays(streak),
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
              S.of(context)!.selfToNextLevel(l.level + 1, l.xpForLevel - l.xpIntoLevel),
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
                S.of(context)!.selfReadyTransition,
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
              S.of(context)!.selfStreakBroken,
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
            S.of(context)!.selfTreeHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
