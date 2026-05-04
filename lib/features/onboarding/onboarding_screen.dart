import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../roadmap/roadmap_screen.dart';

class _AxisDraft {
  _AxisDraft({required this.name, required this.symbol, this.description = ''});
  String name;
  String symbol;
  String description;
}

class _KickoffStep extends StatelessWidget {
  const _KickoffStep({
    required this.palette,
    required this.icon,
    required this.title,
    required this.body,
  });

  final NoeticaPalette palette;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _fallbackPresets = <Map<String, String>>[
  {'name': 'Тело', 'symbol': '◐'},
  {'name': 'Ум', 'symbol': '◇'},
  {'name': 'Дело', 'symbol': '■'},
  {'name': 'Связи', 'symbol': '◯'},
  {'name': 'Душа', 'symbol': '✦'},
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.seedInterests = const <String>[],
  });

  /// Free-form interest phrases from the questionnaire. When non-empty we
  /// ask the backend to design 3..7 personalised axes from them. When
  /// empty (legacy / first run without a profile) we fall back to a
  /// minimal generic preset that the user can edit by hand.
  final List<String> seedInterests;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final List<_AxisDraft> _drafts = [];
  bool _saving = false;
  bool _generating = false;
  String? _generationError;
  String _model = '';

  @override
  void initState() {
    super.initState();
    if (widget.seedInterests.isEmpty) {
      _drafts.addAll(_fallbackPresets
          .map((p) => _AxisDraft(name: p['name']!, symbol: p['symbol']!)));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateAxes());
    }
  }

  Future<void> _generateAxes() async {
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      final profile = ref.read(profileProvider).value;
      final knowledge = await PersonalKnowledgeService().load();
      final result = await ref.read(axesApiProvider).generate(
            profile: profile,
            interests: widget.seedInterests,
            knowledge: knowledge,
            count: 5,
          );
      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(result.axes.map((a) => _AxisDraft(
                name: a.name,
                symbol: a.symbol,
                description: a.description,
              )));
        if (_drafts.length < 3) {
          for (final p in _fallbackPresets) {
            if (_drafts.length >= 3) break;
            if (_drafts
                .any((d) => d.name.toLowerCase() == p['name']!.toLowerCase())) {
              continue;
            }
            _drafts.add(_AxisDraft(name: p['name']!, symbol: p['symbol']!));
          }
        }
        _model = result.model;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generationError = e.toString();
        if (_drafts.isEmpty) {
          _drafts.addAll(_fallbackPresets
              .map((p) => _AxisDraft(name: p['name']!, symbol: p['symbol']!)));
        }
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _maybeOfferRoadmapKickoff() async {
    final profile = ref.read(profileProvider).valueOrNull;
    final aspiration = profile?.aspiration.trim() ?? '';
    if (aspiration.isEmpty) return;
    if (!mounted) return;
    final palette = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Система готова',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Следующий шаг — превратить цель «$aspiration» в первые задачи. '
                'Так dashboard сразу покажет фокус дня, а не пустой экран.',
                style: TextStyle(color: palette.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              _KickoffStep(
                palette: palette,
                icon: Icons.auto_awesome,
                title: 'AI делает план',
                body:
                    'С учётом препятствий, времени, энергии и стиля поддержки.',
              ),
              const SizedBox(height: 8),
              _KickoffStep(
                palette: palette,
                icon: Icons.check_circle_outline,
                title: 'Ты импортируешь задачи',
                body: 'После этого верх dashboard станет “что делать сейчас”.',
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: palette.fg,
                  foregroundColor: palette.bg,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RoadmapScreen(
                      initialGoal: aspiration,
                      autoGenerate: true,
                      kickoffMode: true,
                    ),
                  ));
                },
                icon: const Icon(Icons.route_outlined),
                label: const Text('Сгенерировать первый план'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: palette.muted,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Позже, открыть dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addAxis() {
    if (_drafts.length >= 8) return;
    setState(() => _drafts.add(_AxisDraft(name: '', symbol: '·')));
  }

  void _removeAxis(int i) {
    if (_drafts.length <= 3) return;
    setState(() => _drafts.removeAt(i));
  }

  Future<void> _finish() async {
    final clean = _drafts.where((d) => d.name.trim().isNotEmpty).toList();
    if (clean.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполни хотя бы 3 оси, чтобы пентаграмма имела смысл'),
        ),
      );
      return;
    }
    if (clean.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Слишком много осей: оставь не больше 8, иначе будет хаос'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      const uuid = Uuid();
      final axes = <LifeAxis>[];
      for (var i = 0; i < clean.length; i++) {
        axes.add(LifeAxis(
          id: uuid.v4(),
          name: clean[i].name.trim(),
          symbol: clean[i].symbol.trim().isEmpty ? '·' : clean[i].symbol.trim(),
          position: i,
          createdAt: DateTime.now(),
        ));
      }
      final migrated = await repo.replaceAxesWithMigration(axes);
      await markOnboarded();
      ref.invalidate(onboardedProvider);
      if (!mounted) return;
      // When this screen is presented as a regeneration step (push from
      // Settings), the user expects "Сохранить" → close the dialog and
      // bounce back. Without this, the button looked broken because
      // tapping it just left them stuck on the same form. On the
      // first-run onboarding path we don't pop, AuthGate swaps to the
      // home shell automatically once `onboarded` flips.
      final wasPushed = Navigator.of(context).canPop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            migrated > 0
                ? 'Оси обновлены, перенесено $migrated связей с задачами'
                : 'Оси обновлены',
          ),
        ),
      );
      if (wasPushed) {
        Navigator.of(context).pop();
      } else {
        // First-run path: AuthGate is about to swap to the home shell.
        // Before it does, give the user the opportunity to immediately
        // turn their onboarding aspiration into a real task plan, so
        // they don't land on an empty dashboard with no idea what to
        // do next. Skip silently if they have no aspiration text.
        await _maybeOfferRoadmapKickoff();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить оси: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      // Show an AppBar with a real back button when this screen is
      // pushed from Settings (axis regeneration). Without it the user
      // ended up stuck on the "Сохранить" form with no way to abort,
      // which combined with the silent-fail validation made it look
      // like the button was broken.
      appBar: canPop
          ? AppBar(
              title: const Text('Перегенерация осей'),
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canPop)
                Text(
                  'noetica',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w300,
                      ),
                ),
              const SizedBox(height: 24),
              Text(
                widget.seedInterests.isEmpty
                    ? 'Опиши свои оси роста'
                    : (_generating
                        ? 'AI собирает твою систему…'
                        : 'Твоя система роста'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.seedInterests.isEmpty
                    ? 'От 3 до 8 направлений, по которым ты хочешь расти. К ним будут привязываться задачи и заметки. Их можно изменить позже.'
                    : (_generationError != null
                        ? 'Не удалось связаться с AI: $_generationError. Ниже — запасные оси, отредактируй как хочешь.'
                        : (_generating
                            ? 'Из твоей цели, контекста и препятствий AI делает 5 понятных направлений жизни…'
                            : 'Сгенерировано на ${_model.isEmpty ? "AI" : _model}. Оставь 3–8 направлений, которые реально хочется прокачивать.')),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted),
              ),
              if (widget.seedInterests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _generating ? null : _generateAxes,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                        _generating ? 'Генерирую…' : 'Перегенерировать оси'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _generating && _drafts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: palette.fg),
                            const SizedBox(height: 16),
                            Text(
                              'Это занимает 5–25 секунд',
                              style: TextStyle(color: palette.muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _AxisRow(
                          index: i,
                          draft: _drafts[i],
                          onChanged: () => setState(() {}),
                          onRemove:
                              _drafts.length > 3 ? () => _removeAxis(i) : null,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (_drafts.length < 8)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addAxis,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить ось'),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || _generating) ? null : _finish,
                  child: Text(
                    _saving ? '…' : (canPop ? 'Сохранить' : 'Создать систему'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({
    required this.index,
    required this.draft,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final _AxisDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: TextFormField(
                  initialValue: draft.symbol,
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    draft.symbol = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: draft.name,
                  decoration: InputDecoration(
                    hintText: 'Название оси (#${index + 1})',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: (v) {
                    draft.name = v;
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Удалить',
                ),
            ],
          ),
          if (draft.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 60),
              child: Text(
                draft.description,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
