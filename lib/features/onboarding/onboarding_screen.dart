import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

class _AxisDraft {
  _AxisDraft({required this.name, required this.symbol, this.description = ''});
  String name;
  String symbol;
  String description;
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
            if (_drafts.any(
                (d) => d.name.toLowerCase() == p['name']!.toLowerCase())) {
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
    if (clean.length < 3 || clean.length > 8) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      const uuid = Uuid();
      final axes = <LifeAxis>[];
      for (var i = 0; i < clean.length; i++) {
        axes.add(LifeAxis(
          id: uuid.v4(),
          name: clean[i].name.trim(),
          symbol:
              clean[i].symbol.trim().isEmpty ? '·' : clean[i].symbol.trim(),
          position: i,
          createdAt: DateTime.now(),
        ));
      }
      final migrated = await repo.replaceAxesWithMigration(axes);
      await markOnboarded();
      ref.invalidate(onboardedProvider);
      if (mounted && migrated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Перенесено $migrated связей с задачами на новые ветви',
            ),
          ),
        );
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    : (_generating ? 'AI придумывает оси…' : 'Твои личные оси'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.seedInterests.isEmpty
                    ? 'От 3 до 8 направлений, по которым ты хочешь расти. К ним будут привязываться задачи и заметки. Их можно изменить позже.'
                    : (_generationError != null
                        ? 'Не удалось связаться с AI: $_generationError. Ниже — запасные оси, отредактируй как хочешь.'
                        : (_generating
                            ? 'Из ${widget.seedInterests.length} твоих направлений AI рисует персональную пентаграмму…'
                            : 'Сгенерировано на ${_model.isEmpty ? "AI" : _model}. Переименуй, убери лишние, добавь свои. От 3 до 8.')),
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
                    label: Text(_generating
                        ? 'Генерирую…'
                        : 'Перегенерировать оси'),
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
                          onRemove: _drafts.length > 3
                              ? () => _removeAxis(i)
                              : null,
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
                  child: Text(_saving ? '...' : 'Создать пентаграмму'),
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
