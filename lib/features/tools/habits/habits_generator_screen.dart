import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../services/builtin_generators.dart';
import '../../../services/tools_api.dart';
import '../../../theme/app_theme.dart';
import '../manifest/generator_form_view.dart';

/// Stages the screen walks the user through. Mirrors the menu
/// generator's state machine, minus the lazy-recipe loading: once the
/// user imports the habits we drop them back at the catalog screen
/// because their challenge is already visible in Задачи (date-grouped
/// by `dueAt`) and there's nothing left to do here.
enum _Stage { form, generating, preview, importing }

/// «Микро-привычки» — second AI tool surfaced in «Ассистент». Walks
/// the user through:
///
/// 1. **Form** — pick intent / duration / axis / notes (manifest schema).
/// 2. **Generate** — POST `/tools/habits/generate` (~10–15s).
/// 3. **Preview** — list of N micro-actions; user can re-generate.
/// 4. **Import** — batch-create N task entries dated today..today+N-1
///    tagged `challenge/<id>`, then bounce back to the catalog.
class HabitsGeneratorScreen extends ConsumerStatefulWidget {
  const HabitsGeneratorScreen({super.key});

  @override
  ConsumerState<HabitsGeneratorScreen> createState() =>
      _HabitsGeneratorScreenState();
}

class _HabitsGeneratorScreenState extends ConsumerState<HabitsGeneratorScreen> {
  _Stage _stage = _Stage.form;
  String? _error;

  /// Form state, keyed by `GeneratorInputField.id` from the manifest.
  final GeneratorFormValues _values = {};

  HabitsPlan? _plan;

  String get _intent => ((_values['intent'] as String?) ?? '').trim();
  int get _durationDays => _values['duration_days'] as int? ?? 7;
  String? get _selectedAxisId => _values['axis_id'] as String?;
  String get _notes => ((_values['notes'] as String?) ?? '').trim();

  void _seedValuesFromManifest() {
    _values.clear();
    for (final f in habitsInputs()) {
      _values[f.id] = f.defaultValue;
    }
  }

  @override
  void initState() {
    super.initState();
    _seedValuesFromManifest();
  }

  // ----------------------------------------------------------- generate

  Future<void> _generate() async {
    if (_intent.length < 3) {
      setState(() => _error = 'Опиши, какую привычку хочешь освоить.');
      return;
    }
    setState(() {
      _stage = _Stage.generating;
      _error = null;
    });
    try {
      final api = ref.read(toolsApiProvider);
      final axes = ref.read(axesProvider).valueOrNull ?? const <LifeAxis>[];
      final selectedAxis = axes
          .where((a) => a.id == _selectedAxisId)
          .cast<LifeAxis?>()
          .firstWhere((_) => true, orElse: () => null);
      final axisHint = selectedAxis?.name ?? '';
      final plan = await api.generateHabits(
        intent: _intent,
        durationDays: _durationDays,
        axisHint: axisHint,
        notes: _notes,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.form;
      });
    }
  }

  // ------------------------------------------------------------- import

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _stage = _Stage.importing;
      _error = null;
    });
    try {
      final repo = await ref.read(repositoryProvider.future);
      final challengeId = const Uuid().v4();
      final challengeTag = 'challenge/$challengeId';
      final axisIds =
          _selectedAxisId == null ? const <String>[] : [_selectedAxisId!];

      final today = DateTime.now();
      // Anchor the first day at today; subsequent days roll forward by
      // 1 calendar day each. We pin time to 09:00 local so the task
      // shows up in "Сегодня" rather than as overdue if the user
      // imports late in the evening.
      final startDate = DateTime(today.year, today.month, today.day, 9, 0);

      for (final day in plan.days) {
        final dueAt = startDate.add(Duration(days: day.dayIndex - 1));
        final body = StringBuffer();
        if (day.why.isNotEmpty) {
          body.writeln(day.why);
          body.writeln();
        }
        body.writeln(
          '_День ${day.dayIndex} из ${plan.days.length} · '
          'челлендж «${plan.intent}»_',
        );
        await repo.createEntry(
          title: day.title,
          body: body.toString().trim(),
          kind: EntryKind.task,
          dueAt: dueAt,
          xp: 5,
          axisIds: axisIds,
          tags: [challengeTag, 'habit'],
        );
      }

      if (!mounted) return;
      // Hop back to the catalog. Tasks screen will show the new
      // entries grouped under "Сегодня" / "Завтра" / etc. without us
      // having to render an in-screen imported view.
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Челлендж «${plan.intent}» добавлен — ${plan.days.length} '
            'мини-задач в Задачах.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось импортировать челлендж: $e';
        _stage = _Stage.preview;
      });
    }
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Микро-привычки'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.form => _buildForm(palette),
          _Stage.generating =>
            _buildBusy(palette, 'AI подбирает крошечные шаги…'),
          _Stage.preview => _buildPreview(palette),
          _Stage.importing => _buildBusy(palette, 'Создаю задачи в Noetica…'),
        },
      ),
    );
  }

  Widget _buildForm(NoeticaPalette palette) {
    final theme = Theme.of(context);
    final axesAsync = ref.watch(axesProvider);
    final axes = axesAsync.valueOrNull ?? const <LifeAxis>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: TextStyle(color: palette.fg)),
          ),
        GeneratorFormView(
          fields: habitsInputs(),
          values: _values,
          axes: axes,
          onChanged: (id, v) => setState(() => _values[id] = v),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Что я создам', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _bullet(
                palette,
                '$_durationDays задач — по одной на день, от лёгкой к закрепляющей',
              ),
              _bullet(palette, 'Каждое действие ≤ 2 минут реального усилия'),
              _bullet(
                palette,
                'Появятся в Задачах в секциях «Сегодня» / «Завтра» / …',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Сгенерировать'),
          onPressed: _generate,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _bullet(NoeticaPalette palette, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 8),
              child: Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: palette.muted, shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: palette.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _buildBusy(NoeticaPalette palette, String label) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            Text(label, style: TextStyle(color: palette.muted)),
          ],
        ),
      );

  Widget _buildPreview(NoeticaPalette palette) {
    final plan = _plan!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.intent,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${plan.days.length} дней · по одной мини-задаче',
                      style: TextStyle(color: palette.muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Перегенерировать'),
                onPressed: _generate,
              ),
            ],
          ),
        ),
        if (plan.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              plan.summary,
              style: TextStyle(color: palette.muted, height: 1.4),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: plan.days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _DayCard(day: plan.days[i], palette: palette),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            icon: const Icon(Icons.playlist_add, size: 18),
            label: Text('Добавить ${plan.days.length} задач'),
            onPressed: _import,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.palette});

  final HabitDay day;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.line),
            ),
            child: Text(
              '${day.dayIndex}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (day.why.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    day.why,
                    style: TextStyle(color: palette.muted, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
