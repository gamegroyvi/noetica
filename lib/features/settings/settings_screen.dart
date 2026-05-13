import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../services/backend_urls_service.dart';
import '../../services/notifications.dart';
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
  bool _showDebug = false;

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
      title: 'Test: now',
      body: 'If you see this — notifications work.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context)!.snackSyncDone)),  // reusing sync done
    );
  }

  Future<void> _testIn30() async {
    await NotificationsService.instance.scheduleTest(
      delay: const Duration(seconds: 30),
      title: 'Test: +30s',
      body: 'Scheduled 30 seconds ago. You can minimize the app.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.snackSyncDone),
      ),
    );
  }

  Future<void> _testIn5Min() async {
    await NotificationsService.instance.scheduleTest(
      delay: const Duration(minutes: 5),
      title: 'Test: +5min',
      body: 'Scheduled 5 minutes ago. If received — scheduler is alive.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.snackSyncDone),
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

  Map<String, dynamic> _buildExportPayload(
    List<LifeAxis> axes,
    List<Entry> entries,
    dynamic profile,
  ) {
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
      'profile': profile?.toJson(),
      'axes': axes.map((a) => a.toMap()).toList(),
      'entries': entries
          .map((e) => {
                ...e.toMap(),
                'axisIds': e.axisIds,
              })
          .toList(),
    };
  }

  Future<void> _exportJson() async {
    try {
      final repo = await ref.read(repositoryProvider.future);
      final axes = await repo.listAxes();
      final entries = await repo.listEntries();
      final profile = ref.read(profileProvider).valueOrNull;
      final payload = _buildExportPayload(axes, entries, profile);
      final text = const JsonEncoder.withIndent('  ').convert(payload);

      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/noetica-export-$stamp.json');
      await file.writeAsString(text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.snackExportSaved(file.path)),
          action: SnackBarAction(
            label: S.of(context)!.snackCopy,
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.snackExportError('$e'))),
      );
    }
  }

  Future<void> _importJson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context)!.dialogImportTitle),
        content: Text(S.of(context)!.dialogImportBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(context)!.dialogPasteClipboard),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text == null || clip!.text!.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.snackClipboardEmpty)),
        );
        return;
      }
      final data = jsonDecode(clip.text!) as Map<String, dynamic>;
      final repo = await ref.read(repositoryProvider.future);
      var imported = 0;

      final entriesList = data['entries'] as List<dynamic>? ?? [];
      for (final raw in entriesList) {
        final map = raw as Map<String, dynamic>;
        final entry = Entry.fromMap(map);
        await repo.upsertEntry(entry);
        imported++;
      }

      ref.invalidate(entriesProvider);
      ref.invalidate(scoresProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.snackImportSuccess(imported))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.snackImportError('$e'))),
      );
    }
  }

  Future<void> _wipeAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context)!.dialogEraseTitle),
        content: Text(S.of(context)!.dialogEraseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(context)!.dialogErase),
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
        SnackBar(content: Text(S.of(context)!.snackEraseError('$e'))),
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
      SnackBar(content: Text(S.of(context)!.snackSyncing)),
    );
    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.pull();
      await sync.pushPending();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(S.of(context)!.snackSyncDone)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(S.of(context)!.snackSyncError('$e'))),
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context)!.dialogLogoutTitle),
        content: Text(S.of(context)!.dialogLogoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(context)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(context)!.settingsLogout),
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
        SnackBar(content: Text(S.of(context)!.snackLogoutError('$e'))),
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
        title: Text(S.of(context)!.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: S.of(context)!.sectionAccount),
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
                child: Text(S.of(context)!.settingsLogout),
              ),
            ),
            // Manual "force sync now" trigger — useful when the user
            // logs in on a second device and wants to confirm their
            // data actually pulls from the cloud, instead of waiting
            // for the implicit bootstrap on next app launch.
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(S.of(context)!.settingsSyncNow),
              subtitle: Text(
                S.of(context)!.settingsSyncHint,
                style: TextStyle(color: palette.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _syncNow,
            ),
          ]
          else
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(S.of(context)!.settingsNotLoggedIn),
              subtitle: Text(
                S.of(context)!.settingsNotLoggedInHint,
                style: TextStyle(color: palette.muted),
              ),
            ),
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionProfile),
          ListTile(
            title: Text(profile?.name.isNotEmpty == true
                ? profile!.name
                : S.of(context)!.settingsNoName),
            subtitle: Text(profile?.aspiration.isNotEmpty == true
                ? profile!.aspiration
                : S.of(context)!.settingsNoGoal),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editProfile,
          ),
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionAxes),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(S.of(context)!.settingsRegenAxes),
            subtitle: Text(
              profile == null || profile.interests.isEmpty
                  ? S.of(context)!.settingsRegenAxesNoInterests
                  : S.of(context)!.settingsRegenAxesHint(profile.interests.length),
              style: TextStyle(color: palette.muted),
            ),
            onTap: profile == null || profile.interests.isEmpty
                ? null
                : _regenerateAxes,
          ),
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionNotifications),
          if (_loadingNotif)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (!NotificationsService.instance.supported)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(S.of(context)!.settingsNotificationsUnsupported),
              subtitle: Text(
                NotificationsService.instance.platformNote,
                style: TextStyle(color: palette.muted),
              ),
            )
          else ...[
            SwitchListTile(
              title: Text(S.of(context)!.settingsLocalNotifications),
              subtitle: Text(
                S.of(context)!.settingsLocalNotificationsHint,
              ),
              value: _notifEnabled,
              onChanged: _toggleNotif,
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(S.of(context)!.settingsMorningReminder),
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
              title: Text(S.of(context)!.settingsCoachReminders),
              subtitle: Text(
                S.of(context)!.settingsCoachRemindersHint,
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
                title: Text(S.of(context)!.settingsEveningReview),
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
            if (_showDebug)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _notifEnabled ? _testNow : null,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Test: now'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _notifEnabled ? _testIn30 : null,
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Test: +30s'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _notifEnabled ? _testIn5Min : null,
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Test: +5min'),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionBackend),
          _BackendActiveTile(),
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionData),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(S.of(context)!.settingsExportJson),
            subtitle: Text(
              S.of(context)!.settingsExportJsonHint,
              style: TextStyle(color: palette.muted),
            ),
            onTap: _exportJson,
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(S.of(context)!.settingsImportJson),
            subtitle: Text(
              S.of(context)!.settingsImportJsonHint,
              style: TextStyle(color: palette.muted),
            ),
            onTap: _importJson,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: Text(S.of(context)!.settingsEraseAll),
            subtitle: Text(
              S.of(context)!.settingsEraseAllHint,
              style: TextStyle(color: palette.muted),
            ),
            onTap: _wipeAll,
          ),
          const Divider(height: 1),
          _SectionHeader(title: S.of(context)!.sectionAbout),
          GestureDetector(
            onLongPress: () => setState(() => _showDebug = !_showDebug),
            child: ListTile(
              title: const Text('noetica'),
              subtitle: Text(
                S.of(context)!.settingsVersion,
                style: TextStyle(color: palette.muted),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(S.of(context)!.settingsSourceCode),
            subtitle: Text(
              'github.com/gamegroyvi/noetica',
              style: TextStyle(color: palette.muted),
            ),
          ),
          // Debug panel — hidden by default. Long-press "О приложении"
          // row to toggle.
          if (_showDebug) ...[
            const Divider(height: 1),
            _SectionHeader(title: S.of(context)!.sectionDeveloper),
            _DebugEpochPanel(),
          ],
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
      title: Text(active?.name ?? S.of(context)!.loadingBackends),
      subtitle: Text(
        active == null
            ? S.of(context)!.loadingBackendsHint
            : '${active.url}\n$count backend(s)',
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
        SnackBar(content: Text('Error: $e')),
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
    final svc = await ref.read(profileServiceProvider.future);
    final profile = await svc.load();
    if (profile == null) return;
    await svc.save(profile.copyWith(
      clearEpochAckedAt: true,
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(profileProvider);
  }

  Future<void> _bumpEpoch() async {
    final svc = await ref.read(profileServiceProvider.future);
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
    final svc = await ref.read(profileServiceProvider.future);
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
