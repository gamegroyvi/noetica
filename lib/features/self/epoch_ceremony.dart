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

/// Inline overlay placed on top of the Древо canvas. Dims the tree,
/// floats a card with two actions:
///
///   * **Новая эпоха** — runs a one-time exit animation (tree shrinks
///     to the center and fades), bumps `currentEpoch`, resets the
///     tier, then routes to the axes editor.
///
///   * **Углубиться** — runs the same animation, stamps
///     `epochRefreshedAt` so the pentagon resets visually, bumps
///     `epochTier` to signal "harder tasks under the same axes".
///
/// Tap the scrim to dismiss — the overlay just slides away without
/// touching the profile, so the user can come back to it. A tiny
/// chip in the Self screen header will still indicate that the
/// threshold is reached so they aren't accidentally locked out.
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
  /// Controls the one-time *exit* animation — tree shrinks to center
  /// + fades. Runs when the user commits to either path. Completion
  /// triggers the side-effect (navigate / save profile).
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Controls the entry animation for the overlay card — a quick
  /// settle from slightly scaled-up + dimmed to normal.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  bool _committing = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _enter.forward();
  }

  @override
  void didUpdateWidget(covariant EpochOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _enter.forward(from: 0);
    } else if (!widget.visible && old.visible) {
      _enter.reverse();
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
    setState(() => _committing = true);
    await _exit.forward();
    if (!mounted) return;
    final now = DateTime.now();
    final updated = widget.profile.copyWith(
      currentEpoch: widget.profile.currentEpoch + 1,
      epochTier: 1,
      epochStartedAt: now,
      // Stamp ack so the overlay doesn't re-open against the fresh
      // scores (they take a cycle to drop).
      epochAckedAt: now,
      // Also refresh so the pentagon visually resets under the new
      // axes the user is about to draw.
      epochRefreshedAt: now,
      updatedAt: now,
    );
    await ref.read(profileServiceProvider).save(updated);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AxesEditorScreen()),
    );
    if (mounted) {
      _exit.reverse();
      setState(() => _committing = false);
    }
  }

  Future<void> _commitGoDeeper() async {
    if (_committing) return;
    setState(() => _committing = true);
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
      setState(() => _committing = false);
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
        final exit = Curves.easeInCubic.transform(_exit.value);
        final treeScale = 1 - 0.55 * exit;
        final treeOpacity = 1 - exit;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            // Animated tree — shrinks + fades during the exit ritual
            // so the user visually sees "древо сжалось, пора расти
            // заново".
            Opacity(
              opacity: treeOpacity,
              child: Transform.scale(
                scale: treeScale,
                child: widget.child,
              ),
            ),
            if (widget.visible || _enter.isAnimating)
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

  Widget _buildOverlay(NoeticaPalette palette) {
    final entry = Curves.easeOutCubic.transform(_enter.value);
    // Dim the tree while overlay is up. At full exit we ease the
    // scrim away so the user doesn't see it lingering after commit.
    final scrimAlpha = (entry * 0.66) * (1 - _exit.value);
    final cardOpacity = (entry * (1 - _exit.value)).clamp(0.0, 1.0);
    final cardScale = 0.94 + 0.06 * entry;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: Container(color: Colors.black.withOpacity(scrimAlpha)),
        ),
        Center(
          child: Opacity(
            opacity: cardOpacity,
            child: Transform.scale(
              scale: cardScale,
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
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.fg, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: palette.fg.withOpacity(0.18),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
