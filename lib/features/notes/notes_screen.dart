import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_card.dart';

/// "Заметки" tab — fast capture + searchable list.
/// Filters entries by kind == note, ordered reverse chronological.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _quickCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _quickBusy = false;
  String _query = '';

  @override
  void dispose() {
    _quickCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final text = _quickCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _quickBusy = true);
    try {
      final repo = await ref.read(repositoryProvider.future);
      await repo.createEntry(
        title: text,
        body: '',
        kind: EntryKind.note,
      );
      _quickCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить заметку: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _quickBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entriesAsync = ref.watch(entriesProvider);
    final axesAsync = ref.watch(axesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: palette.line),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.add, size: 18, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _quickCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _quickAdd(),
                      decoration: const InputDecoration(
                        hintText: 'Быстрая заметка…',
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward,
                      color: palette.fg,
                      size: 20,
                    ),
                    onPressed: _quickBusy ? null : _quickAdd,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.search, size: 18, color: palette.muted),
                hintText: 'Поиск',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (entries) {
                final axes = axesAsync.valueOrNull ?? const <LifeAxis>[];
                final axesById = {for (final a in axes) a.id: a};
                final notes = entries
                    .where((e) => e.kind == EntryKind.note)
                    .where((e) => _matches(e, _query))
                    .toList();

                if (notes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _query.isEmpty
                                ? 'Заметок пока нет'
                                : 'Ничего не найдено',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _query.isEmpty
                                ? 'Запиши мысль одной строкой выше или открой полный редактор кнопкой «+».'
                                : 'Попробуй другой запрос.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      EntryCard(entry: notes[i], axesById: axesById),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _matches(Entry e, String q) {
  if (q.isEmpty) return true;
  return e.title.toLowerCase().contains(q) ||
      e.body.toLowerCase().contains(q);
}
