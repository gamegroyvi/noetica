import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import 'axes_editor_screen.dart';

/// Helpers around the "pentagon full → эпоха threshold" concept.
///
/// There's no modal anymore — [EpochOverlay] is an inline widget that
/// the «Я» screen stacks on top of the Древо when the user hits the
/// threshold. The old `EpochCeremony.show()` entrypoint was removed
/// per user feedback ("нахер убери эту мерзкую модалку на совсем") —
/// ceremony lives on top of the tree, not as a separate route.
class EpochCeremony {
  EpochCeremony._();

  /// Returns true iff every axis in [scores] is at or above the "full"
  /// threshold (95 out of 100). We use 95 (not 100) so the overlay
  /// isn't blocked by rounding + 30-day decay jitter at the top of
  /// the pentagon.
  static bool pentagonFull(List<AxisScore> scores) {
    if (scores.length < 3) return false;
    for (final s in scores) {
      if (s.value < 95) return false;
    }
    return true;
  }

  /// Count of axes at or above the bloom threshold (95). Drives the
  /// per-axis glow + the cross-link UI on the pentagon.
  static Set<int> bloomedAxes(List<AxisScore> scores) {
    final out = <int>{};
    for (var i = 0; i < scores.length; i++) {
      if (scores[i].value >= 95) out.add(i);
    }
    return out;
  }
}

/// Which decisive path the user picked. Drives the tree exit animation
/// so «Новая эпоха» (расцветает наружу) and «Углубиться» (сжимается
/// внутрь, потом вспышка) feel visibly distinct — instead of both
/// looking like "tree just disappears".
enum _EpochPath { none, newEpoch, goDeeper }

/// Inline overlay placed on top of the Древо canvas. Dims the tree,
/// floats a bottom-sheet card with two actions:
///
///   * **Новая эпоха** — tree explodes outward and fades (rotation +
///     scale up). Then bumps `currentEpoch`, resets the tier, routes
///     to the axes editor.
///
///   * **Углубиться** — tree contracts to a tight glowing point
///     (scale down + bright flash), then fades. Stamps
///     `epochRefreshedAt` and bumps `epochTier`.
///
/// The action card slides up from the bottom of the screen (bottom-
/// sheet style) so it always fits on phones. Tap the scrim above the
/// card to dismiss without touching the profile.
class EpochOverlay extends ConsumerStatefulWidget {
  const EpochOverlay({
    super.key,
    required this.profile,
    required this.child,
    required this.visible,
    this.onDismissed,
  });

  /// The current profile (for epoch labels + copyWith patches).
  final UserProfile profile;

  /// The Древо canvas (or whatever) we overlay.
  final Widget child;

  /// Whether the overlay should be currently shown. When this flips
  /// from true to false the [onDismissed] callback lets the parent
  /// persist the ack so the overlay doesn't re-appear on rebuild.
  final bool visible;

  /// Called when the user dismisses the overlay via scrim tap / swipe
  /// (i.e. not via a decisive action). Parent typically persists
  /// `epochAckedAt = now` here so we don't nag again this cycle.
  final VoidCallback? onDismissed;

  @override
  ConsumerState<EpochOverlay> createState() => _EpochOverlayState();
}

class _EpochOverlayState extends ConsumerState<EpochOverlay>
    with TickerProviderStateMixin {
  /// Controls the one-time *exit* animation — tree morphs (per-path)
  /// then fades. Runs when the user commits to either path.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _committing = false;
  bool _sheetOpen = false;
  /// The actual ModalRoute backing our bottom sheet — captured the
  /// frame after [showModalBottomSheet] starts. We hold on to it so
  /// that:
  ///   * external programmatic dismiss in didUpdateWidget can pop
  ///     *exactly* this route (instead of "whatever's on top of root
  ///     navigator", which used to occasionally pop HomeShell);
  ///   * tap handlers on the sheet ignore late taps that would
  ///     otherwise pop a different route after the sheet was already
  ///     dismissed (double-tap on «Новая эпоха» / «Углубиться»).
  ModalRoute<void>? _sheetRoute;
  _EpochPath _path = _EpochPath.none;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
    }
  }

  @override
  void didUpdateWidget(covariant EpochOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (widget.visible && !_sheetOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
      } else if (!widget.visible && _sheetOpen && _sheetRoute != null) {
        // Programmatic dismiss — pop *our* sheet specifically. The
        // earlier version called `Navigator.maybePop(rootNavigator)`
        // which on Android could happily pop the wrong route (e.g. the
        // HomeShell underneath if the sheet was already closing) and
        // leave the user staring at the onboarding screen.
        final route = _sheetRoute;
        if (route != null && route.isActive) {
          Navigator.of(context, rootNavigator: true).removeRoute(route);
        }
      }
    }
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  /// Show the epoch card as a real Material 3 modal bottom sheet pinned
  /// to the bottom of the viewport (not the inline 320 px Древо box).
  /// Buttons inside pop the sheet, then we run the per-path morph on
  /// the inline tree underneath.
  Future<void> _openSheet() async {
    if (!mounted || _sheetOpen) return;
    _sheetOpen = true;
    // `safePop` only pops if our sheet is still the topmost route.
    // Without this guard, a late or duplicate tap on a button would
    // pop the route *behind* the sheet (HomeShell / SelfScreen) once
    // the sheet had already dismissed itself, leaving the user staring
    // at onboarding or a black screen.
    void safePop(BuildContext ctx) {
      final route = _sheetRoute;
      if (route == null || !route.isActive || !route.isCurrent) return;
      Navigator.of(ctx).pop();
    }
    final future = showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        // Capture the route the very first frame the sheet builds. We
        // can't grab it before showModalBottomSheet runs the builder,
        // and grabbing it later via Navigator queries is unreliable on
        // tear-down.
        _sheetRoute ??= ModalRoute.of(ctx) as ModalRoute<void>?;
        return SafeArea(
          top: false,
          child: _EpochOverlayCard(
            palette: context.palette,
            profile: widget.profile,
            onNewEpoch: () {
              if (_committing) return;
              safePop(ctx);
              _commitNewEpoch();
            },
            onGoDeeper: () {
              if (_committing) return;
              safePop(ctx);
              _commitGoDeeper();
            },
            onDismiss: () {
              if (_committing) return;
              safePop(ctx);
            },
            committing: false,
          ),
        );
      },
    );
    await future;
    _sheetOpen = false;
    _sheetRoute = null;
    // If the sheet was swiped/scrim-dismissed without committing, treat
    // it as an explicit "dismiss for now" so the parent can ack it.
    if (mounted && !_committing && _path == _EpochPath.none) {
      _dismiss();
    }
  }

  Future<void> _commitNewEpoch() async {
    if (_committing) return;
    setState(() {
      _committing = true;
      _path = _EpochPath.newEpoch;
    });
    await _exit.forward();
    if (!mounted) return;
    final now = DateTime.now();

    // Freeze the эпоха the user is leaving (its axes, final scores,
    // boundaries) into the archive so the «Я» screen can show a
    // read-only retrospective view of it later. Read straight from
    // the providers — they're guaranteed to be loaded by now since
    // the user just hit pentagonFull(scores).
    final axes = ref.read(axesProvider).valueOrNull ?? const <LifeAxis>[];
    final scoresList =
        ref.read(scoresProvider).valueOrNull ?? const <AxisScore>[];
    final liveAxes = [for (final a in axes) if (!a.isDeleted) a];
    final scoresMap = <String, double>{
      for (final s in scoresList) s.axis.id: s.value,
    };
    final snapshot = EpochSnapshot(
      epoch: widget.profile.currentEpoch,
      tier: widget.profile.epochTier,
      axes: liveAxes,
      scores: scoresMap,
      startedAt: widget.profile.epochStartedAt ?? widget.profile.updatedAt,
      endedAt: now,
    );
    final newArchive = [...widget.profile.epochArchive, snapshot];

    final updated = widget.profile.copyWith(
      currentEpoch: widget.profile.currentEpoch + 1,
      epochStartedAt: now,
      epochTier: 1,
      epochRefreshedAt: now,
      epochAckedAt: now,
      updatedAt: now,
      epochArchive: newArchive,
    );
    await ref.read(profileServiceProvider).save(updated);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AxesEditorScreen()),
    );
    if (mounted) {
      _exit.reverse();
      setState(() {
        _committing = false;
        _path = _EpochPath.none;
      });
    }
  }

  Future<void> _commitGoDeeper() async {
    if (_committing) return;
    setState(() {
      _committing = true;
      _path = _EpochPath.goDeeper;
    });
    await _exit.forward();
    if (!mounted) return;
    final now = DateTime.now();
    final updated = widget.profile.copyWith(
      epochTier: widget.profile.epochTier + 1,
      epochRefreshedAt: now,
      epochAckedAt: now,
      updatedAt: now,
    );
    await ref.read(profileServiceProvider).save(updated);
    if (mounted) {
      _exit.reverse();
      setState(() {
        _committing = false;
        _path = _EpochPath.none;
      });
    }
  }

  void _dismiss() {
    if (_committing) return;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _exit,
      builder: (context, _) => _buildTreeMorph(palette),
    );
  }

  Widget _buildTreeMorph(NoeticaPalette palette) {
    final exit = _exit.value;
    switch (_path) {
      case _EpochPath.none:
        // No commit pressed → tree pristine.
        return widget.child;
      case _EpochPath.newEpoch:
        // BLOOM-OUT: tree scales up, rotates a touch, fades. Reads as
        // "let it scatter, start fresh".
        final t = Curves.easeInQuart.transform(exit);
        final scale = 1.0 + 0.85 * t;
        final rot = 0.22 * t; // ~13°
        final opacity = (1 - t * 1.15).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: widget.child,
            ),
          ),
        );
      case _EpochPath.goDeeper:
        // CONDENSE: tree shrinks to a glowing pip + flash, then fades.
        // Reads as "concentrate, drill in".
        final t = Curves.easeInOutCubic.transform(exit);
        final scale = (1.0 - 0.92 * t).clamp(0.04, 1.0);
        // Flash is a brief overlay glow that peaks at ~0.55, fades by
        // 0.85, gone by 1.0. Layered as a radial vignette via Opacity
        // on a Container with the foreground colour.
        final flash = (() {
          if (t < 0.35) return 0.0;
          if (t < 0.55) return (t - 0.35) / 0.20;
          if (t < 0.85) return 1.0 - (t - 0.55) / 0.30;
          return 0.0;
        })();
        final opacity = (1 - (t * 1.1)).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: widget.child,
              ),
            ),
            if (flash > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220 * (1 - 0.4 * (t - 0.35).clamp(0.0, 1.0)),
                      height: 220 * (1 - 0.4 * (t - 0.35).clamp(0.0, 1.0)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            palette.fg.withOpacity(0.85 * flash),
                            palette.fg.withOpacity(0.18 * flash),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

}

class _EpochOverlayCard extends StatelessWidget {
  const _EpochOverlayCard({
    required this.palette,
    required this.profile,
    required this.onNewEpoch,
    required this.onGoDeeper,
    required this.onDismiss,
    required this.committing,
  });

  final NoeticaPalette palette;
  final UserProfile profile;
  final VoidCallback onNewEpoch;
  final VoidCallback onGoDeeper;
  final VoidCallback onDismiss;
  final bool committing;

  @override
  Widget build(BuildContext context) {
    final nextEpoch = profile.currentEpoch + 1;
    final nextTier = profile.epochTier + 1;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: palette.fg.withOpacity(0.85), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: palette.fg.withOpacity(0.22),
              blurRadius: 36,
              spreadRadius: 1,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag-handle visual cue so it reads as a bottom sheet on
            // phones (matches Material 3 sheets in the rest of the
            // app).
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: palette.muted.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ЭПОХА ${profile.currentEpoch} · ПИК',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Отложить',
                  onPressed: committing ? null : onDismiss,
                  icon: const Icon(Icons.close),
                  color: palette.muted,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ты заполнил древо.',
              style: TextStyle(
                color: palette.fg,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Два пути дальше — можешь обновить сам набор осей и '
              'начать Эпоху $nextEpoch с чистого листа, либо остаться '
              'в текущем фокусе и взять следующий, более трудный '
              'тир задач.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _PathTile(
              palette: palette,
              icon: Icons.refresh,
              title: 'Новая эпоха',
              subtitle:
                  'Перерисовать ветви — Эпоха $nextEpoch. XP и уровень остаются.',
              onTap: committing ? null : onNewEpoch,
              filled: true,
            ),
            const SizedBox(height: 10),
            _PathTile(
              palette: palette,
              icon: Icons.trending_up,
              title: 'Углубиться',
              subtitle:
                  'Тир $nextTier в той же Эпохе — задачи станут сложнее, древо обнулится.',
              onTap: committing ? null : onGoDeeper,
              filled: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  const _PathTile({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.filled,
  });

  final NoeticaPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? palette.fg : palette.surface;
    final fg = filled ? palette.bg : palette.fg;
    final sub = filled ? palette.bg.withOpacity(0.7) : palette.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: palette.fg, width: 1.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: sub,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}
