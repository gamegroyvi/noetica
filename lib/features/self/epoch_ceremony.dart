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

  /// Controls the bottom-sheet card slide-in (and the scrim alpha).
  /// Reverses on dismiss / commit so the card slides back down before
  /// the tree exit completes.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  bool _committing = false;
  _EpochPath _path = _EpochPath.none;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _enter.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant EpochOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _enter.forward(from: 0);
      } else {
        _enter.reverse();
      }
    }
  }

  @override
  void dispose() {
    _exit.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _commitNewEpoch() async {
    if (_committing) return;
    setState(() {
      _committing = true;
      _path = _EpochPath.newEpoch;
    });
    // Slide the card away first so the tree's "explode outward"
    // animation isn't fighting it for attention.
    unawaited(_enter.reverse());
    await _exit.forward();
    if (!mounted) return;
    final now = DateTime.now();
    final updated = widget.profile.copyWith(
      currentEpoch: widget.profile.currentEpoch + 1,
      epochStartedAt: now,
      epochTier: 1,
      epochRefreshedAt: now,
      epochAckedAt: now,
      updatedAt: now,
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
    unawaited(_enter.reverse());
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
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, _) {
        return Stack(
          fit: StackFit.passthrough,
          children: [
            // Animated tree — per-path morph during exit so «Новая
            // эпоха» feels expansive (расцветает) and «Углубиться»
            // feels concentrative (сжимается + вспышка).
            _buildTreeMorph(palette),
            if (widget.visible || _enter.isAnimating || _enter.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !widget.visible,
                  child: _buildOverlay(palette),
                ),
              ),
          ],
        );
      },
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

  Widget _buildOverlay(NoeticaPalette palette) {
    final entry = Curves.easeOutCubic.transform(_enter.value);
    // Dim the tree while overlay is up. Ease the scrim away during
    // exit so it doesn't linger after the morph completes.
    final scrimAlpha = (entry * 0.66) * (1 - _exit.value);
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: Container(color: Colors.black.withOpacity(scrimAlpha)),
        ),
        // Bottom-sheet style card. Slides up on enter, slides down on
        // dismiss / commit. Always anchored to the bottom so it can't
        // run off the top of small phone screens.
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionalTranslation(
            translation: Offset(0, 1 - entry),
            child: SafeArea(
              top: false,
              child: _EpochOverlayCard(
                palette: palette,
                profile: widget.profile,
                onNewEpoch: _commitNewEpoch,
                onGoDeeper: _commitGoDeeper,
                onDismiss: _dismiss,
                committing: _committing,
              ),
            ),
          ),
        ),
      ],
    );
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
