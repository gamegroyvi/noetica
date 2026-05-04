import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/backend_urls_service.dart';
import '../../services/notifications.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/onboarding_chat_screen.dart';
import 'backends_screen.dart';

/// Single-screen settings: profile, notifications, axes, data, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifEnabled = true;
  TimeOfDay _morning = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _evening = const TimeOfDay(hour: 21, minute: 0);
  bool _coachNotifEnabled = false;
  bool _loadingNotif = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final svc = NotificationsService.instance;
    final enabled = await svc.isEnabled();
    final time = await svc.morningTime();
    final eveningTime = await svc.eveningTime();
    final coachOn = await svc.isCoachEnabled();
    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _morning = TimeOfDay(hour: time.hour, minute: time.minute);
      _evening = TimeOfDay(hour: eveningTime.hour, minute: eveningTime.minute);
      _coachNotifEnabled = coachOn;
      _loadingNotif = false;
    });
  }

  Future<void> _toggleNotif(bool v) async {
    setState(() => _notifEnabled = v);
    await NotificationsService.instance.setEnabled(v);
  }

  Future<void> _testNow() async {
    await NotificationsService.instance.showImmediate(
      title: 'Тест: сейчас',
      body: 'Если ты это видишь — сейчас уведомления работают.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отправлено. Должно прилететь сразу.')),
    );
  }

  Future<void> _testIn30() async {
    await NotificationsService.instance.scheduleTest(
      delay: const Duration(seconds: 30),
      title: 'Тест: +30 сек',
      body: 'Запланировано на 30 секунд назад. Можно сворачивать приложение.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запланировано на через 30 секунд. Можно сворачивать.'),
      ),
    );
  }

  Future<void> _testIn5Min() async {
    await NotificationsService.instance.scheduleTest(
      delay: const Duration(minutes: 5),
      title: 'Тест: +5 мин',
      body: 'Запланировано пять минут назад. Если пришло — планировщик жив.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запланировано через 5 минут. Закрывай приложение и жди.'),
      ),
    );
  }

  Future<void> _pickMorning() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _morning,
      builder: (ctx, child) => child!,
    );
    if (picked == null) return;
    setState(() => _morning = picked);
    await NotificationsService.instance.setMorningTime(picked.hour, picked.minute);
  }

  Future<void> _pickEvening() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _evening,
      builder: (ctx, child) => child!,
    );
    if (picked == null) return;
    setState(() => _evening = picked);
    await NotificationsService.instance.setEveningTime(picked.hour, picked.minute);
    await NotificationsService.instance.scheduleCoachReminders();
  }

  Future<void> _exportJson() async {
    try {
      final repo = await ref.read(repositoryProvider.future);
      final axes = await repo.listAxes();
      final entries = await repo.listEntries();
      final profile = ref.read(profileProvider).valueOrNull;
      final payload = {
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile?.toJson(),
        'axes': axes.map((a) => a.toMap()).toList(),
        'entries': entries
            .map((e) => {
                  ...e.toMap(),
                  'axisIds': e.axisIds,
                })
            .toList(),
      };
      final text = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экспорт скопирован в буфер обмена.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать: $e')),
      );
    }
  }

  Future<void> _wipeAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Стереть все данные?'),
        content: const Text(
          'Удалятся профиль, оси, задачи, заметки и настройки. Действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Стереть'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = await ref.read(repositoryProvider.future);
      await repo.replaceAxes(const []);
      final entries = await repo.listEntries();
      for (final e in entries) {
        await repo.deleteEntry(e.id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await NotificationsService.instance.cancelAll();
      // Force the app back to onboarding by invalidating the relevant
      // providers — `app.dart` will route to questionnaire.
      ref.invalidate(profileProvider);
      ref.invalidate(onboardedProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось стереть: $e')),
      );
    }
  }

  Future<void> _regenerateAxes() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          seedInterests: profile.interests,
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => OnboardingChatScreen(
          existing: profile,
          onDone: () => navigator.pop(),
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Синхронизация: pull → push…')),
    );
    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.pull();
      await sync.pushPending();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final current = sync.currentStatus;
      if (current.phase == SyncPhase.error) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Синхронизация не завершилась: ${current.lastError ?? 'ошибка'}',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Готово. Локальные и облачные данные сверены.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Локальные данные останутся на устройстве. Чтобы они снова '
          'синхронизировались, войдите тем же Google-аккаунтом.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выйти: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = ref.watch(profileProvider).valueOrNull;
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(title: 'Аккаунт'),
          if (session != null) ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(session.user.name.isNotEmpty
                  ? session.user.name
                  : session.user.email),
              subtitle: Text(
                session.user.email,
                style: TextStyle(color: palette.muted),
              ),
              trailing: TextButton(
                onPressed: _signOut,
                child: const Text('Выйти'),
              ),
            ),
            // Manual "force sync now" trigger — useful when the user
            // logs in on a second device and wants to confirm their
            // data actually pulls from the cloud, instead of waiting
            // for the implicit bootstrap on next app launch.
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Синхронизировать сейчас'),
              subtitle: Text(
                'Стянуть данные с облака и отправить локальные изменения',
                style: TextStyle(color: palette.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _syncNow,
            ),
          ]
          else
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Не выполнен вход'),
              subtitle: Text(
                'Перезапустите приложение, чтобы войти.',
                style: TextStyle(color: palette.muted),
              ),
            ),
          const Divider(height: 1),
          const _SectionHeader(title: 'Профиль'),
          ListTile(
            title: Text(profile?.name.isNotEmpty == true
                ? profile!.name
                : 'Без имени'),
            subtitle: Text(profile?.aspiration.isNotEmpty == true
                ? profile!.aspiration
                : 'Цель не указана'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editProfile,
          ),
          const Divider(height: 1),
          const _SectionHeader(title: 'Оси роста'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Перегенерировать оси'),
            subtitle: Text(
              profile == null || profile.interests.isEmpty
                  ? 'Добавь интересы в профиле, чтобы AI собрал оси'
                  : 'AI пересоберёт оси по ${profile.interests.length} интересам',
              style: TextStyle(color: palette.muted),
            ),
            onTap: profile == null || profile.interests.isEmpty
                ? null
                : _regenerateAxes,
          ),
          const Divider(height: 1),
          const _SectionHeader(title: 'Уведомления'),
          if (_loadingNotif)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (!NotificationsService.instance.supported)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Уведомления здесь не поддерживаются'),
              subtitle: Text(
                NotificationsService.instance.platformNote,
                style: TextStyle(color: palette.muted),
              ),
            )
          else ...[
            SwitchListTile(
              title: const Text('Локальные уведомления'),
              subtitle: const Text(
                'За 1 день, утром, и через час после дедлайна',
              ),
              value: _notifEnabled,
              onChanged: _toggleNotif,
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Утреннее напоминание'),
              subtitle: Text(
                _morning.format(context),
                style: TextStyle(color: palette.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: _notifEnabled,
              onTap: _notifEnabled ? _pickMorning : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              title: const Text('AI-коуч напоминания'),
              subtitle: const Text(
                'Утренний план и вечерний разбор',
              ),
              value: _coachNotifEnabled,
              onChanged: _notifEnabled
                  ? (v) async {
                      setState(() => _coachNotifEnabled = v);
                      await NotificationsService.instance.setCoachEnabled(v);
                    }
                  : null,
            ),
            if (_coachNotifEnabled)
              ListTile(
                leading: const Icon(Icons.nightlight_round),
                title: const Text('Вечерний разбор'),
                subtitle: Text(
                  _evening.format(context),
                  style: TextStyle(color: palette.muted),
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: _notifEnabled,
                onTap: _notifEnabled ? _pickEvening : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                NotificationsService.instance.platformNote,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
            // Debug-grade test buttons. Useful for verifying that the
            // platform actually delivers a notification (especially after
            // first install on Windows where the user must accept the
            // toast registration). All three slots use the same code path
            // as production scheduling.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _notifEnabled ? _testNow : null,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Тест: сейчас'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _notifEnabled ? _testIn30 : null,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Тест: +30 сек'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _notifEnabled ? _testIn5Min : null,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Тест: +5 мин'),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          const _SectionHeader(title: 'Бэкенд'),
          _BackendActiveTile(),
          _SyncStatusTile(),
          const Divider(height: 1),
          const _SectionHeader(title: 'Данные'),
          _TrustDataTile(palette: palette),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Экспорт в JSON'),
            subtitle: Text(
              'Полный дамп профиля, осей и записей в буфер обмена',
              style: TextStyle(color: palette.muted),
            ),
            onTap: _exportJson,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Стереть все данные'),
            subtitle: Text(
              'Возврат к экрану онбординга',
              style: TextStyle(color: palette.muted),
            ),
            onTap: _wipeAll,
          ),
          const Divider(height: 1),
          const _SectionHeader(title: 'О приложении'),
          ListTile(
            title: const Text('noetica'),
            subtitle: Text(
              'v0.1.0 — minimalist growth tracker',
              style: TextStyle(color: palette.muted),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Исходный код'),
            subtitle: Text(
              'github.com/gamegroyvi/noetica',
              style: TextStyle(color: palette.muted),
            ),
          ),
          // Debug panel is always visible pre-release — the user
          // explicitly asked for an easy way to test эпоха-related
          // flows without having to actually fill the pentagon over
          // weeks of real usage.
          const Divider(height: 1),
          const _SectionHeader(title: '⚙ Разработчик'),
          _DebugEpochPanel(),
        ],
      ),
    );
  }
}

/// Compact summary tile showing the currently active backend. Tapping
/// opens [BackendsScreen] where the user can add/remove/switch URLs.
class _BackendActiveTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stateAsync = ref.watch(backendUrlsStateProvider);
    final state = stateAsync.valueOrNull;
    final active = state?.endpoints.firstWhere(
      (e) => e.id == state.activeId,
      orElse: () => state.endpoints.isEmpty
          ? const BackendEndpoint(id: '', name: '—', url: '—')
          : state.endpoints.first,
    );
    final count = state?.endpoints.length ?? 0;
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(active?.name ?? 'Загрузка…'),
      subtitle: Text(
        active == null
            ? 'Подгружаем список бэкендов…'
            : '${active.url}\n$count бэкенд${_ru(count)} сохранено',
        style: TextStyle(color: palette.muted),
      ),
      isThreeLine: active != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BackendsScreen()),
        );
      },
    );
  }

  // 1 бэкенд, 2 бэкенда, 5 бэкендов — quick pluralisation matching
  // the rest of the app's microcopy. We don't pull in `intl` for this
  // because the project already uses ad-hoc Russian strings.
  String _ru(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'а';
    return 'ов';
  }
}

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final phase = status?.phase ?? SyncPhase.idle;
    final busy = status?.isBusy ?? false;
    final isError = phase == SyncPhase.error;
    final subtitle = isError
        ? 'Ошибка: ${status?.lastError ?? 'не удалось синхронизировать'}'
        : status?.lastSuccessAt == null
            ? 'Синхронизация запустится после входа в Google'
            : 'Последний успех: ${_formatTime(context, status!.lastSuccessAt!)}';
    return ListTile(
      leading: Icon(
        isError ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
      ),
      title: Text(_phaseLabel(phase)),
      subtitle: Text(subtitle, style: TextStyle(color: palette.muted)),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }

  String _phaseLabel(SyncPhase phase) {
    switch (phase) {
      case SyncPhase.pulling:
        return 'Синхронизация: получаем облако';
      case SyncPhase.pushing:
        return 'Синхронизация: отправляем изменения';
      case SyncPhase.done:
        return 'Синхронизация в порядке';
      case SyncPhase.error:
        return 'Синхронизация требует внимания';
      case SyncPhase.idle:
        return 'Синхронизация готова';
    }
  }

  String _formatTime(BuildContext context, DateTime value) {
    final t = TimeOfDay.fromDateTime(value);
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')} '
        '${t.format(context)}';
  }
}

class _TrustDataTile extends StatelessWidget {
  const _TrustDataTile({required this.palette});

  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('Приватность и хранение'),
      subtitle: Text(
        'Данные сначала хранятся локально. После входа в Google включается '
        'облачная синхронизация; AI получает только контекст запроса.',
        style: TextStyle(color: palette.muted),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Как Noetica работает с данными',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              const _TrustBullet(
                icon: Icons.storage_outlined,
                text: 'Профиль, оси, задачи и заметки живут на устройстве.',
              ),
              const _TrustBullet(
                icon: Icons.cloud_sync_outlined,
                text: 'Cloud sync включается после входа и синхронизирует '
                    'изменения между устройствами.',
              ),
              const _TrustBullet(
                icon: Icons.auto_awesome_outlined,
                text: 'AI-запросы отправляют только нужный для генерации '
                    'контекст: цель, оси, задачи и выбранные заметки.',
              ),
              const SizedBox(height: 12),
              Text(
                'Полный экспорт доступен ниже: можно забрать JSON-дамп и '
                'стереть локальные данные в любой момент.',
                style: TextStyle(color: context.palette.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustBullet extends StatelessWidget {
  const _TrustBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: palette.muted,
          fontSize: 11,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dev-only controls for fiddling with эпоха-state without having to
/// actually fill the pentagon over weeks. Ships in pre-release builds
/// so the user (and reviewers) can exercise the overlay / ceremony
/// paths on demand.
class _DebugEpochPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DebugEpochPanel> createState() =>
      _DebugEpochPanelState();
}

class _DebugEpochPanelState extends ConsumerState<_DebugEpochPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() body, String toast) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toast)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fill every axis with synthetic completed tasks until every score
  /// is ≥95. Uses the same path as a real task completion so XP /
  /// levels move consistently — we just bulk-spawn entries dated to
  /// now().
  Future<void> _fillAll() async {
    final repo = await ref.read(repositoryProvider.future);
    final axes = await repo.listAxes();
    final now = DateTime.now();
    for (final a in axes) {
      // 5 × 40 xp synthetic tasks on each axis saturates the decay
      // window so the score pegs to ~100.
      for (var i = 0; i < 5; i++) {
        final created = await repo.createEntry(
          title: '[debug] filler ${i + 1} · ${a.symbol}',
          body: 'auto-filler для тестирования эпох',
          kind: EntryKind.task,
          axisIds: [a.id],
          axisWeights: {a.id: 1.0},
          xp: 40,
        );
        await repo.upsertEntry(created.copyWith(
          completedAt: now.subtract(Duration(minutes: i * 5)),
          updatedAt: now,
        ));
      }
    }
    ref.invalidate(entriesProvider);
    ref.invalidate(scoresProvider);
  }

  Future<void> _clearAck() async {
    final svc = ref.read(profileServiceProvider);
    final profile = await svc.load();
    if (profile == null) return;
    await svc.save(profile.copyWith(
      clearEpochAckedAt: true,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(profileProvider);
  }

  Future<void> _bumpEpoch() async {
    final svc = ref.read(profileServiceProvider);
    final profile = await svc.load();
    if (profile == null) return;
    await svc.save(profile.copyWith(
      currentEpoch: profile.currentEpoch + 1,
      epochTier: 1,
      epochStartedAt: DateTime.now(),
      epochAckedAt: DateTime.now(),
      epochRefreshedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(profileProvider);
    ref.invalidate(scoresProvider);
  }

  Future<void> _reset() async {
    final svc = ref.read(profileServiceProvider);
    final profile = await svc.load();
    if (profile == null) return;
    await svc.save(profile.copyWith(
      currentEpoch: 1,
      epochTier: 1,
      clearEpochStartedAt: true,
      clearEpochAckedAt: true,
      clearEpochRefreshedAt: true,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(profileProvider);
    ref.invalidate(scoresProvider);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget tile(IconData icon, String title, String subtitle,
            Future<void> Function() action, String toast) =>
        ListTile(
          leading: Icon(icon, color: palette.fg),
          title: Text(title),
          subtitle: Text(subtitle, style: TextStyle(color: palette.muted)),
          enabled: !_busy,
          onTap: () => _run(action, toast),
        );
    return Column(
      children: [
        tile(
          Icons.bolt,
          'Заполнить все оси до 100%',
          'Создаёт синтетические задачи, чтобы пентагон встал на пик',
          _fillAll,
          'Готово. Открой «Я» — оверлей должен появиться.',
        ),
        tile(
          Icons.refresh,
          'Сбросить ack эпохи',
          'Обнуляет epochAckedAt — оверлей снова пустит при пике',
          _clearAck,
          'Ack сброшен.',
        ),
        tile(
          Icons.arrow_upward,
          'Форсировать +1 эпоху',
          'currentEpoch + 1, tier → 1, ack/refresh = now',
          _bumpEpoch,
          'Эпоха увеличена.',
        ),
        tile(
          Icons.restore,
          'Сбросить эпоху на 1',
          'Полный откат прогрессии до Эпохи 1',
          _reset,
          'Сброс до Эпохи 1.',
        ),
      ],
    );
  }
}
