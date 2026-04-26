import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import 'axes_editor_screen.dart';

/// Modal ceremony that fires when the user first fills every axis on
/// the pentagon to its cap in the current эпоха. Offers two branches:
///
///   * **Начать Эпоху N+1** — bumps `currentEpoch` on the user profile
///     and pushes the axes editor so they can redraw their tree from
///     scratch (new branches, new focus). Nothing is deleted — old XP
///     and history remain, but the visual pentagon starts fresh.
///
///   * **Остаться в Эпохе N** — marks the current epoch as
///     acknowledged so we stop nagging. Progression continues through
///     per-axis эпохи (`epochFromXp`).
///
/// The dialog animates in with a pseudo-3D rotateY flip so it feels
/// ceremonial, not just another Material alert.
class EpochCeremony {
  EpochCeremony._();

  /// Returns true iff every axis in [scores] is at or above the
  /// "full" threshold (95 out of 100). We intentionally use 95 instead
  /// of 100 so the ceremony isn't blocked by rounding + 30-day decay
  /// jitter at the very top of the pentagon.
  static bool pentagonFull(List<AxisScore> scores) {
    if (scores.length < 3) return false;
    for (final s in scores) {
      if (s.value < 95) return false;
    }
    return true;
  }

  /// Show the ceremony modally. The caller should invoke this at most
  /// once per pentagon-full transition — [UserProfile.epochAckedAt] is
  /// the guardrail that prevents re-opening on every rebuild.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile profile,
  }) async {
    final palette = context.palette;
    final nextEpoch = profile.currentEpoch + 1;

    final startNew = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Эпоха',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, a1, a2, child) {
        // Pseudo-3D flip: rotateY swings from ~90° to 0° while scale
        // animates from 0.7× to 1×. Combined with an opacity fade it
        // reads as "the pentagon folds into a new form".
        final t = Curves.easeOutCubic.transform(a1.value);
        final rotY = (1 - t) * 1.15; // ~66° → 0°
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016) // perspective
                ..rotateY(rotY)
                ..scale(0.7 + 0.3 * t),
              child: _EpochCeremonyCard(
                palette: palette,
                currentEpoch: profile.currentEpoch,
                nextEpoch: nextEpoch,
              ),
            ),
          ),
        );
      },
    );

    // Either path also needs to record `epochAckedAt` so we don't
    // re-open the dialog on the next rebuild.
    final now = DateTime.now();
    if (startNew == true) {
      // Clear epochAckedAt on entering the new epoch so the ceremony
      // can fire again once the pentagon is refilled in эпоха N+1 —
      // otherwise the dialog would be a once-per-lifetime event.
      final updated = profile.copyWith(
        currentEpoch: nextEpoch,
        epochStartedAt: now,
        clearEpochAckedAt: true,
        updatedAt: now,
      );
      await ref.read(profileServiceProvider).save(updated);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AxesEditorScreen()),
        );
      }
    } else if (startNew == false) {
      final updated = profile.copyWith(
        epochAckedAt: now,
        updatedAt: now,
      );
      await ref.read(profileServiceProvider).save(updated);
    }
    // `null` (barrier-dismissed) intentionally does nothing, so the
    // user gets another chance on next load.
  }
}

class _EpochCeremonyCard extends StatelessWidget {
  const _EpochCeremonyCard({
    required this.palette,
    required this.currentEpoch,
    required this.nextEpoch,
  });

  final NoeticaPalette palette;
  final int currentEpoch;
  final int nextEpoch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.fg, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: palette.fg.withOpacity(0.18),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ЭПОХА $currentEpoch · ЗАВЕРШЕНА',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Древо заполнено.\nЧто дальше?',
              style: TextStyle(
                color: palette.fg,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ты прошёл цикл: все оси на максимуме. Можно '
              'обновить набор ветвей и начать Эпоху $nextEpoch '
              'с новым фокусом, либо остаться здесь и качать '
              'текущие оси глубже — XP и уровень никуда не денутся.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.fg,
                      foregroundColor: palette.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Начать Эпоху $nextEpoch'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.fg,
                      side: BorderSide(color: palette.line),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Остаться'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
