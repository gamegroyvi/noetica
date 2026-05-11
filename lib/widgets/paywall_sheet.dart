import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';

/// Feature identifier passed to the paywall so the copy can explain
/// *which* limit the user hit. Add new cases as premium-gated features
/// grow.
enum PaywallFeature {
  axes('Больше осей роста', 'Бесплатный план ограничен ${FreeLimits.maxAxes} осями.'),
  tasks('Больше задач', 'Бесплатный план ограничен ${FreeLimits.maxActiveTasks} активными задачами.'),
  aiGeneration('Безлимитный AI', 'На бесплатном плане — ${FreeLimits.aiGenerationsPerWeek} AI-генерация в неделю.'),
  memoir('Полная история', 'Бесплатный план показывает только последние ${FreeLimits.memoirDays} дней.'),
  sync('Синхронизация', 'Синхронизация между устройствами доступна в Premium.');

  const PaywallFeature(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// Bottom sheet that explains the value of Premium and invites the user
/// to subscribe. Currently shows a placeholder CTA; the real ЮКасса
/// checkout flow plugs in once the backend endpoint is live.
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key, required this.feature});

  final PaywallFeature feature;

  static Future<void> show(BuildContext context, PaywallFeature feature) {
    AnalyticsService.instance.track(AnalyticsEvents.paywallShown, {
      'feature': feature.name,
    });
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => PaywallSheet(feature: feature),
    );
  }

  static const _benefits = <(IconData, String, String)>[
    (Icons.all_inclusive, 'Безлимитные оси и задачи', 'Расти без ограничений'),
    (Icons.auto_awesome, 'AI без лимитов', 'Генерируй планы, меню, тренировки сколько угодно'),
    (Icons.sync, 'Синхронизация', 'Все данные на всех устройствах'),
    (Icons.history, 'Полная история', 'Мемуар без срока давности'),
    (Icons.bolt, 'Приоритетная поддержка', 'Мы ответим быстрее'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium, size: 48, color: palette.fg),
            const SizedBox(height: 12),
            Text(
              'Noetica Premium',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              feature.subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 24),
            for (final (icon, title, sub) in _benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.line),
                      ),
                      child: Icon(icon, size: 18, color: palette.fg),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            sub,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Pricing row
            Row(
              children: [
                Expanded(
                  child: _PriceCard(
                    label: 'Месяц',
                    price: '299 \u20BD',
                    note: '',
                    palette: palette,
                    theme: theme,
                    selected: false,
                    onTap: () => _onPurchase(context, 'monthly'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriceCard(
                    label: 'Год',
                    price: '1 990 \u20BD',
                    note: '−44%',
                    palette: palette,
                    theme: theme,
                    selected: true,
                    onTap: () => _onPurchase(context, 'yearly'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriceCard(
                    label: 'Навсегда',
                    price: '4 990 \u20BD',
                    note: 'Early bird',
                    palette: palette,
                    theme: theme,
                    selected: false,
                    onTap: () => _onPurchase(context, 'lifetime'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _onPurchase(context, 'yearly'),
                child: const Text('Оформить подписку'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                AnalyticsService.instance.track(AnalyticsEvents.paywallDismissed, {
                  'feature': feature.name,
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'Не сейчас',
                style: TextStyle(color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPurchase(BuildContext context, String plan) {
    AnalyticsService.instance.track(AnalyticsEvents.purchaseStarted, {
      'plan': plan,
      'feature': feature.name,
    });
    // TODO: integrate ЮКасса checkout flow.
    // For now show a placeholder snackbar.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Оплата скоро будет доступна!'),
        ),
      );
    Navigator.of(context).pop();
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.label,
    required this.price,
    required this.note,
    required this.palette,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final String note;
  final NoeticaPalette palette;
  final ThemeData theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.fg : palette.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? palette.bg : palette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? palette.bg : palette.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                note,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? palette.bg.withValues(alpha: 0.7) : palette.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
