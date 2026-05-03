import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../services/coach_api.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../dashboard/widgets/dashboard_stats.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  bool _loading = false;
  MorningPlan? _morning;
  EveningReflection? _evening;
  String? _error;

  bool get _isMorning {
    final hour = DateTime.now().hour;
    return hour < 14;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final api = CoachApi(auth: authService);
      final profileAsync = ref.read(profileProvider);
      final profile = profileAsync.valueOrNull;
      final entries = ref.read(entriesProvider).valueOrNull ?? [];
      final scores = ref.read(scoresProvider).valueOrNull ?? [];
      final stats = DashboardStats.from(entries);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final activeTasks = entries
          .where((e) =>
              e.kind == EntryKind.task && e.completedAt == null)
          .map((e) => e.title)
          .take(8)
          .toList();

      final completedToday = entries
          .where((e) =>
              e.kind == EntryKind.task &&
              e.completedAt != null &&
              e.completedAt!.isAfter(todayStart))
          .map((e) => e.title)
          .take(10)
          .toList();

      final entriesToday = entries
          .where((e) => e.createdAt.isAfter(todayStart))
          .length;

      if (_isMorning) {
        final plan = await api.generateMorningPlan(
          name: profile?.name ?? '',
          aspiration: profile?.aspiration ?? '',
          axes: scores.map((s) => s.axis.name).toList(),
          activeTasks: activeTasks,
          streak: stats.streak,
        );
        if (!mounted) return;
        setState(() {
          _morning = plan;
          _loading = false;
        });
      } else {
        final reflection = await api.generateEveningReflection(
          name: profile?.name ?? '',
          completedToday: completedToday,
          remaining: activeTasks.take(5).toList(),
          entriesToday: entriesToday,
          streak: stats.streak,
        );
        if (!mounted) return;
        setState(() {
          _evening = reflection;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMorning ? 'Утренний план' : 'Вечерний разбор'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _generate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(palette)
              : _morning != null
                  ? _buildMorning(palette)
                  : _evening != null
                      ? _buildEvening(palette)
                      : const SizedBox.shrink(),
    );
  }

  Widget _buildError(NoeticaPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: palette.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              'Не удалось получить совет',
              style: TextStyle(
                color: palette.fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: palette.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _generate,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorning(NoeticaPalette palette) {
    final plan = _morning!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          plan.greeting,
          style: TextStyle(
            color: palette.fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _CoachCard(
          palette: palette,
          icon: Icons.center_focus_strong,
          title: 'Фокус дня',
          content: plan.focus,
        ),
        const SizedBox(height: 12),
        _CoachCard(
          palette: palette,
          icon: Icons.checklist,
          title: 'План на сегодня',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < plan.tasks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.line, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          plan.tasks[i],
                          style: TextStyle(
                            color: palette.fg,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CoachCard(
          palette: palette,
          icon: Icons.local_fire_department,
          title: 'Мотивация',
          content: plan.motivation,
        ),
      ],
    );
  }

  Widget _buildEvening(NoeticaPalette palette) {
    final reflection = _evening!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Итоги дня',
          style: TextStyle(
            color: palette.fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _CoachCard(
          palette: palette,
          icon: Icons.summarize,
          title: 'Резюме',
          content: reflection.summary,
        ),
        if (reflection.wins.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CoachCard(
            palette: palette,
            icon: Icons.emoji_events,
            title: 'Что получилось',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reflection.wins
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('+ ', style: TextStyle(
                            color: palette.fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          )),
                          Expanded(
                            child: Text(
                              w,
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (reflection.improvements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CoachCard(
            palette: palette,
            icon: Icons.trending_up,
            title: 'Что улучшить',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reflection.improvements
                  .map(
                    (imp) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('~ ', style: TextStyle(
                            color: palette.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          )),
                          Expanded(
                            child: Text(
                              imp,
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _CoachCard(
          palette: palette,
          icon: Icons.nightlight_round,
          title: 'На завтра',
          content: reflection.encouragement,
        ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.palette,
    required this.icon,
    required this.title,
    this.content,
    this.child,
  });

  final NoeticaPalette palette;
  final IconData icon;
  final String title;
  final String? content;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.fg, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content != null)
            Text(
              content!,
              style: TextStyle(
                color: palette.fg,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
