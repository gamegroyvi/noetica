import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../services/roadmap_api.dart';
import '../../theme/app_theme.dart';

/// Goal → AI plan → preview → batch import flow.
class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

enum _Stage { input, loading, preview, error }

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  final _goalCtrl = TextEditingController();
  _Stage _stage = _Stage.input;
  int _horizonDays = 30;
  int _taskCount = 6;
  RoadmapResult? _result;
  List<bool>? _picked;
  String? _error;
  bool _importing = false;

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final goal = _goalCtrl.text.trim();
    if (goal.length < 3) return;
    final api = ref.read(roadmapApiProvider);
    final profile = ref.read(profileProvider).valueOrNull;
    final axes = ref.read(axesProvider).valueOrNull ?? const [];
    if (axes.length < 3) {
      setState(() {
        _stage = _Stage.error;
        _error = 'Нужно минимум 3 оси, чтобы построить план.';
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      final knowledge = await PersonalKnowledgeService().load();
      final result = await api.generate(
        goal: goal,
        profile: profile,
        axes: axes,
        knowledge: knowledge,
        horizonDays: _horizonDays,
        taskCount: _taskCount,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _picked = List<bool>.filled(result.tasks.length, true);
        _stage = _Stage.preview;
      });
    } on RoadmapApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = '$e';
      });
    }
  }

  Future<void> _import() async {
    final result = _result;
    final picked = _picked;
    if (result == null || picked == null) return;
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      var imported = 0;
      for (var i = 0; i < result.tasks.length; i++) {
        if (!picked[i]) continue;
        final t = result.tasks[i];
        await repo.createEntry(
          title: t.title,
          body: t.body,
          kind: EntryKind.task,
          dueAt: t.dueAt,
          xp: t.xp,
          axisIds: t.axisIds,
          axisWeights: t.axisWeights,
        );
        imported++;
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано задач: $imported')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = 'Не удалось импортировать: $e';
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasAxes =
        (ref.watch(axesProvider).valueOrNull ?? const <LifeAxis>[]).length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сгенерировать план'),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey(_stage),
            child: switch (_stage) {
              _Stage.input => _buildInput(palette, hasAxes),
              _Stage.loading => _buildLoading(palette),
              _Stage.preview => _buildPreview(palette),
              _Stage.error => _buildError(palette),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInput(NoeticaPalette palette, bool hasAxes) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Опиши цель',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Чем конкретнее — тем точнее план. Например: «Хочу пробежать полумарафон через 3 месяца, текущая форма средняя».',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _goalCtrl,
          maxLines: 5,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Чего хочешь достичь?',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        _Section(label: 'Горизонт', palette: palette),
        const SizedBox(height: 8),
        _SegmentedRow(
          options: const [
            ('Неделя', 7),
            ('Месяц', 30),
            ('Квартал', 90),
          ],
          value: _horizonDays,
          onChanged: (v) => setState(() => _horizonDays = v),
        ),
        const SizedBox(height: 20),
        _Section(label: 'Кол-во задач', palette: palette),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _taskCount.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                label: '$_taskCount',
                onChanged: (v) => setState(() => _taskCount = v.round()),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$_taskCount',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              hasAxes && _goalCtrl.text.trim().length >= 3 ? _generate : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Сгенерировать'),
          ),
        ),
        if (!hasAxes) ...[
          const SizedBox(height: 12),
          Text(
            'Нужно хотя бы 3 оси. Добавь их на вкладке «Я».',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }

  Widget _buildLoading(NoeticaPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: palette.fg,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Думаю над планом…',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Это занимает 5–15 секунд',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(NoeticaPalette palette) {
    final result = _result!;
    final picked = _picked!;
    final axes = ref.watch(axesProvider).valueOrNull ?? const <LifeAxis>[];
    final byId = {for (final a in axes) a.id: a};
    final pickedCount = picked.where((b) => b).length;

    return Column(
      children: [
        if (result.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              result.summary,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: result.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = result.tasks[i];
              final on = picked[i];
              return _DraftCard(
                draft: t,
                included: on,
                axesById: byId,
                onTap: () => setState(() => _picked![i] = !on),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                Text(
                  'model: ${result.model}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _importing
                            ? null
                            : () => setState(() {
                                  _stage = _Stage.input;
                                  _result = null;
                                  _picked = null;
                                }),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Перегенерировать'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed:
                            (_importing || pickedCount == 0) ? null : _import,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _importing
                                ? 'Импортирую…'
                                : 'Импортировать ($pickedCount)',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(NoeticaPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: palette.fg, size: 36),
          const SizedBox(height: 16),
          Text(
            'Не получилось',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Что-то пошло не так',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => setState(() => _stage = _Stage.input),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Назад'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.palette});
  final String label;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: palette.muted,
            letterSpacing: 1.4,
          ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<(String, int)> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (final (label, v) in options)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: EdgeInsets.only(right: v == options.last.$2 ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: v == value ? palette.fg : palette.surface,
                  border: Border.all(color: palette.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: v == value ? palette.bg : palette.fg,
                          fontWeight: v == value
                              ? FontWeight.w600
                              : FontWeight.w400,
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

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.included,
    required this.axesById,
    required this.onTap,
  });

  final RoadmapDraft draft;
  final bool included;
  final Map<String, LifeAxis> axesById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: included ? palette.surface : palette.bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  color: included ? palette.fg : Colors.transparent,
                  border: Border.all(color: palette.fg, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: included
                    ? Icon(Icons.check, size: 16, color: palette.bg)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: included ? palette.fg : palette.muted,
                            decoration: included
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                    ),
                    if (draft.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        draft.body,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: palette.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          text: '+${draft.xp} XP',
                          palette: palette,
                          highlighted: true,
                        ),
                        for (final id in draft.axisIds)
                          if (axesById[id] != null)
                            _Pill(
                              text:
                                  '${axesById[id]!.symbol}  ${axesById[id]!.name}',
                              palette: palette,
                            ),
                        if (draft.dueAt != null)
                          _Pill(
                            text: _formatDue(draft.dueAt!),
                            palette: palette,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDue(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(due.year, due.month, due.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'сегодня';
    if (diff == 1) return 'завтра';
    if (diff <= 7) return 'через $diff дн.';
    return 'до ${due.day}.${due.month.toString().padLeft(2, '0')}';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.palette,
    this.highlighted = false,
  });
  final String text;
  final NoeticaPalette palette;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? palette.fg : Colors.transparent,
        border: Border.all(color: palette.fg, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? palette.bg : palette.fg,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
