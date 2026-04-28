import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_chat_screen.dart';

const _kMinAxes = 3;
const _kMaxAxes = 8;

const _symbolPresets = <String>[
  '◐', '◇', '■', '◯', '✦', '✎', '₽', '⌂', '☼', '◢', '✚', '◈', '⌘', '∞', '✺',
];

class AxesEditorScreen extends ConsumerStatefulWidget {
  const AxesEditorScreen({super.key});

  @override
  ConsumerState<AxesEditorScreen> createState() => _AxesEditorScreenState();
}

class _DraftAxis {
  _DraftAxis({
    required this.id,
    required this.name,
    required this.symbol,
    required this.createdAt,
    this.isNew = false,
  });

  String id;
  String name;
  String symbol;
  DateTime createdAt;
  bool isNew;
}

class _AxesEditorScreenState extends ConsumerState<AxesEditorScreen> {
  final _uuid = const Uuid();
  late List<_DraftAxis> _drafts;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final axes = ref.read(axesProvider).valueOrNull;
    if (axes != null) {
      _drafts = axes
          .map((a) => _DraftAxis(
                id: a.id,
                name: a.name,
                symbol: a.symbol,
                createdAt: a.createdAt,
              ))
          .toList();
      _hydrated = true;
    }
  }

  bool get _isValid {
    if (_drafts.length < _kMinAxes) return false;
    final names = <String>{};
    for (final d in _drafts) {
      final name = d.name.trim();
      if (name.isEmpty || d.symbol.trim().isEmpty) return false;
      if (!names.add(name.toLowerCase())) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      final now = DateTime.now();
      final newAxes = <LifeAxis>[
        for (var i = 0; i < _drafts.length; i++)
          LifeAxis(
            id: _drafts[i].id,
            name: _drafts[i].name.trim(),
            symbol: _drafts[i].symbol.trim(),
            position: i,
            createdAt: _drafts[i].isNew ? now : _drafts[i].createdAt,
          ),
      ];
      await repo.replaceAxes(newAxes);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _add() {
    if (_drafts.length >= _kMaxAxes) return;
    HapticFeedback.selectionClick();
    setState(() {
      _drafts.add(
        _DraftAxis(
          id: _uuid.v4(),
          name: '',
          symbol: '◯',
          createdAt: DateTime.now(),
          isNew: true,
        ),
      );
    });
  }

  void _remove(int i) {
    if (_drafts.length <= _kMinAxes) return;
    HapticFeedback.selectionClick();
    setState(() => _drafts.removeAt(i));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _drafts.removeAt(oldIndex);
      _drafts.insert(newIndex, item);
    });
  }

  Future<void> _editAxis(int i) async {
    final draft = _drafts[i];
    final result = await showModalBottomSheet<_DraftAxis>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AxisEditSheet(draft: draft),
    );
    if (result == null) return;
    setState(() {
      _drafts[i] = result;
    });
  }

  /// Re-generate the entire branch set via the LLM. Asks the user for a
  /// short "что хочешь изменить?" hint so re-runs don't always converge
  /// on the same answer (we also pass a random variation seed so even
  /// no-hint regen produces a fresh look). The current drafts are
  /// replaced with the AI's output — user can still edit / save.
  Future<void> _regenerateBranches() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала пройди онбординг.')),
      );
      return;
    }
    final hint = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _RegenHintDialog(),
    );
    if (hint == null) return; // user cancelled
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    messenger.showSnackBar(
      const SnackBar(content: Text('AI рисует новые ветви…')),
    );
    try {
      final api = ref.read(axesApiProvider);
      final knowledge = await PersonalKnowledgeService().load();
      final seed = math.Random().nextInt(1 << 31);
      final result = await api.generate(
        profile: profile,
        interests: profile.interests,
        knowledge: knowledge,
        count: math.max(_kMinAxes, _drafts.length).clamp(_kMinAxes, _kMaxAxes),
        regenHint: hint.isEmpty ? null : hint,
        variationSeed: seed,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      setState(() {
        _drafts = [
          for (final a in result.axes)
            _DraftAxis(
              id: _uuid.v4(),
              name: a.name,
              symbol: a.symbol,
              createdAt: DateTime.now(),
              isNew: true,
            ),
        ];
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось перегенерировать: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Re-run the onboarding chat — collects fresh interests, levels, pain
  /// points etc. and saves them to the profile. Does NOT touch the
  /// existing branches; the user can hit «Перегенерировать» right after
  /// to redraw with the new inputs.
  Future<void> _reOnboard() async {
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
    if (!mounted) return;
    // Suggest immediate regen so the new answers actually shape the tree.
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
            'Профиль обновлён. Хочешь сразу перегенерировать ветви?'),
        action: SnackBarAction(
          label: 'Да',
          onPressed: _regenerateBranches,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!_hydrated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ветви')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ветви'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'regen':
                  _regenerateBranches();
                  break;
                case 'reonboard':
                  _reOnboard();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'regen',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome),
                  title: Text('Перегенерировать ветви'),
                  subtitle: Text('AI перерисует набор с новыми вводными'),
                ),
              ),
              PopupMenuItem(
                value: 'reonboard',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh),
                  title: Text('Пройти онбординг заново'),
                  subtitle: Text(
                      'Обновить интересы, боли, цели и пересобрать ветви'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _isValid && !_saving ? _save : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Сохранить'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Перетаскивай, переименовывай, добавляй или удаляй (от $_kMinAxes до $_kMaxAxes). '
                'Чтобы AI перерисовал ветви с нуля — Меню → «Perveгенерировать».',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drafts.length,
              onReorder: _reorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, i) {
                final d = _drafts[i];
                return _AxisRow(
                  key: ValueKey(d.id),
                  index: i,
                  draft: d,
                  canRemove: _drafts.length > _kMinAxes,
                  onTap: () => _editAxis(i),
                  onRemove: () => _remove(i),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: OutlinedButton.icon(
                onPressed: _drafts.length >= _kMaxAxes ? null : _add,
                icon: const Icon(Icons.add),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_drafts.length >= _kMaxAxes
                      ? 'Максимум $_kMaxAxes ветвей'
                      : 'Добавить ветвь'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final _DraftAxis draft;
  final bool canRemove;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasName = draft.name.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.drag_indicator,
                      color: palette.muted,
                      size: 22,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    draft.symbol,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasName ? draft.name : 'Без названия',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: hasName ? palette.fg : palette.muted,
                          fontStyle: hasName ? null : FontStyle.italic,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: canRemove ? 'Удалить' : 'Минимум 3 ветви',
                  onPressed: canRemove ? onRemove : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: canRemove ? palette.fg : palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisEditSheet extends StatefulWidget {
  const _AxisEditSheet({required this.draft});
  final _DraftAxis draft;

  @override
  State<_AxisEditSheet> createState() => _AxisEditSheetState();
}

class _AxisEditSheetState extends State<_AxisEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _symbol;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
    _symbol = TextEditingController(text: widget.draft.symbol);
  }

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    super.dispose();
  }

  void _save() {
    final n = _name.text.trim();
    final s = _symbol.text.trim();
    if (n.isEmpty || s.isEmpty) return;
    Navigator.of(context).pop(
      _DraftAxis(
        id: widget.draft.id,
        name: n,
        symbol: s.characters.take(2).toString(),
        createdAt: widget.draft.createdAt,
        isNew: widget.draft.isNew,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Ось',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.draft.name.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Например: Тело',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symbol,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Символ',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _symbolPresets)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _symbol.text = s);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _symbol.text == s
                            ? palette.fg
                            : Colors.transparent,
                        border: Border.all(color: palette.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _symbol.text == s ? palette.bg : palette.fg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _name.text.trim().isEmpty ||
                        _symbol.text.trim().isEmpty
                    ? null
                    : _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Готово'),
                ),
              ),
            ),
            SizedBox(height: 12 + mq.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Lightweight dialog that asks the user *what* they want to be
/// different in the regenerated set. Empty input is allowed (we then
/// rely on the variation seed alone). The dialog returns `null` on
/// cancel, or the trimmed hint string on confirm.
class _RegenHintDialog extends StatefulWidget {
  const _RegenHintDialog();

  @override
  State<_RegenHintDialog> createState() => _RegenHintDialogState();
}

class _RegenHintDialogState extends State<_RegenHintDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Перегенерировать ветви'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI составит новый набор. Опиши, что хочешь изменить '
            '(тон, акцент, жизненные сферы) — или оставь поле '
            'пустым, и тогда просто получится другой случайный '
            'вариант на тех же интересах.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'например: больше про здоровье и творчество, '
                  'меньше про работу',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Перегенерировать'),
        ),
      ],
    );
  }
}
