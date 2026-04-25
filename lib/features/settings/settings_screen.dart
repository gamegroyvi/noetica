import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers.dart';
import '../../services/notifications.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/questionnaire_screen.dart';

/// Single-screen settings: profile, notifications, axes, data, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifEnabled = true;
  TimeOfDay _morning = const TimeOfDay(hour: 8, minute: 0);
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
    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _morning = TimeOfDay(hour: time.hour, minute: time.minute);
      _loadingNotif = false;
    });
  }

  Future<void> _toggleNotif(bool v) async {
    setState(() => _notifEnabled = v);
    await NotificationsService.instance.setEnabled(v);
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
        builder: (_) => QuestionnaireScreen(
          existing: profile,
          onDone: () => navigator.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
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
          else if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Уведомления доступны только в Android-сборке'),
              subtitle: Text(
                'В web-версии напоминаний нет — установи APK на телефон.',
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
          ],
          const Divider(height: 1),
          const _SectionHeader(title: 'Данные'),
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
