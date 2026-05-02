import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../../services/user_manifest.dart';
import '../../../theme/app_theme.dart';

/// Authoring UI for a user-owned generator. Surfaces a deliberately
/// narrow editing surface for v1 (per `noetica-user-agents-design.md`):
/// authors fill out a name, description, two prompt templates, the
/// label of the single freeform input the runtime will show their
/// users, and pick an icon. Custom input fields, axis links, ladder
/// strategies and import targets are intentionally hidden — they will
/// surface in later PRs as the editor matures, and the underlying
/// model already supports them through `UserManifest.toGenerator`.
class ManifestEditorScreen extends ConsumerStatefulWidget {
  const ManifestEditorScreen({super.key, this.existing});

  /// Pass an existing manifest to edit it; pass null to create.
  final UserManifest? existing;

  @override
  ConsumerState<ManifestEditorScreen> createState() =>
      _ManifestEditorScreenState();
}

class _ManifestEditorScreenState
    extends ConsumerState<ManifestEditorScreen> {
  late UserManifest _draft;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _promptSystem;
  late final TextEditingController _promptUser;
  late final TextEditingController _intentLabel;
  late final TextEditingController _intentPlaceholder;
  late final TextEditingController _maxItems;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.existing ?? blankUserManifest();
    _title = TextEditingController(text: _draft.title);
    _description = TextEditingController(text: _draft.description);
    _promptSystem = TextEditingController(text: _draft.promptSystem);
    _promptUser = TextEditingController(text: _draft.promptUser);
    _intentLabel = TextEditingController(text: _draft.intentLabel);
    _intentPlaceholder =
        TextEditingController(text: _draft.intentPlaceholder);
    _maxItems = TextEditingController(text: _draft.maxItems.toString());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _promptSystem.dispose();
    _promptUser.dispose();
    _intentLabel.dispose();
    _intentPlaceholder.dispose();
    _maxItems.dispose();
    super.dispose();
  }

  UserManifest _collect() {
    return _draft.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      promptSystem: _promptSystem.text,
      promptUser: _promptUser.text,
      intentLabel: _intentLabel.text.trim(),
      intentPlaceholder: _intentPlaceholder.text.trim(),
      notesEnabled: _draft.notesEnabled,
      iconKey: _draft.iconKey,
      maxItems: int.tryParse(_maxItems.text.trim()) ?? _draft.maxItems,
    );
  }

  Future<void> _save() async {
    final collected = _collect();
    final err = collected.validate();
    if (err != null) {
      _toast(err);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(userManifestStoreProvider).save(collected);
      if (!mounted) return;
      Navigator.of(context).pop(collected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Сохранено: «${collected.title}»'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить инструмент?'),
            content: Text('«${existing.title}» исчезнет из каталога. '
                'Уже импортированные задачи останутся.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(userManifestStoreProvider).delete(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Удалено: «${existing.title}»'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Не удалось удалить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? 'Редактировать инструмент'
            : 'Новый инструмент'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionHeader('Что это за инструмент', palette: palette,
                theme: theme),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Например, «План подготовки к ЕГЭ»',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Короткое описание',
                hintText: 'Зачем этот инструмент. Покажется в карточке.',
              ),
            ),
            const SizedBox(height: 16),
            _IconPicker(
              selected: _draft.iconKey,
              onSelected: (k) => setState(() {
                _draft = _draft.copyWith(iconKey: k);
              }),
              palette: palette,
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              'Что AI должен делать',
              palette: palette,
              theme: theme,
              hint: 'Системный промпт описывает «характер» AI и правила. '
                  'Используй {intent} и {notes} в пользовательском промпте — '
                  'они подставятся из ответов пользователя.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptSystem,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                labelText: 'Системный промпт',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptUser,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Пользовательский промпт',
                alignLabelWithHint: true,
                hintText: 'Используй {intent}{notes} как плейсхолдеры.',
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              'О чём спрашивать пользователя',
              palette: palette,
              theme: theme,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _intentLabel,
              decoration: const InputDecoration(
                labelText: 'Подпись поля ввода',
                hintText: 'Например, «К чему хочешь подготовиться?»',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _intentPlaceholder,
              decoration: const InputDecoration(
                labelText: 'Подсказка внутри поля (опционально)',
                hintText: 'Например, «опиши свободно»',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Добавить поле «Доп. пожелания»'),
              subtitle: Text(
                'Будет передано в промпт как {notes}.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              value: _draft.notesEnabled,
              onChanged: (v) => setState(() {
                _draft = _draft.copyWith(notesEnabled: v);
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxItems,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сколько задач максимум',
                helperText: '1–30. Сервер обрежет, если LLM сгенерирует больше.',
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Что произойдёт после «Сохранить»: инструмент '
                      'появится в каталоге Ассистента в секции «Мои '
                      'инструменты». Каждый запуск — задачи на сегодня '
                      '(5 XP за каждую). В будущих версиях появится '
                      'выбор: задачи / заметки, лесенка по дням, '
                      'привязка к оси.',
                      style: TextStyle(color: palette.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
    this.title, {
    required this.palette,
    required this.theme,
    this.hint,
  });

  final String title;
  final NoeticaPalette palette;
  final ThemeData theme;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: TextStyle(color: palette.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.onSelected,
    required this.palette,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final entries = kUserManifestIcons.entries.toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          InkWell(
            onTap: () => onSelected(entry.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.key == selected
                    ? palette.fg.withValues(alpha: 0.08)
                    : palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: entry.key == selected
                      ? palette.fg
                      : palette.line,
                  width: entry.key == selected ? 1.5 : 1,
                ),
              ),
              child: Icon(entry.value, size: 22, color: palette.fg),
            ),
          ),
      ],
    );
  }
}
