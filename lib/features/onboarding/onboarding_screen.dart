import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

class _AxisDraft {
  _AxisDraft({required this.name, required this.symbol});
  String name;
  String symbol;
}

const _presets = <Map<String, String>>[
  {'name': 'Тело', 'symbol': '◐'},
  {'name': 'Ум', 'symbol': '◇'},
  {'name': 'Дело', 'symbol': '■'},
  {'name': 'Связи', 'symbol': '◯'},
  {'name': 'Душа', 'symbol': '✦'},
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final List<_AxisDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drafts = _presets
        .map((p) => _AxisDraft(name: p['name']!, symbol: p['symbol']!))
        .toList();
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
    final clean =
        _drafts.where((d) => d.name.trim().isNotEmpty).toList();
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
      await repo.replaceAxes(axes);
      await markOnboarded();
      ref.invalidate(onboardedProvider);
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
                'Опиши свои оси роста',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'От 3 до 8 направлений, по которым ты хочешь расти. К ним будут привязываться задачи и заметки. Их можно изменить позже.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
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
                  onPressed: _saving ? null : _finish,
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
      child: Row(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
    );
  }
}
