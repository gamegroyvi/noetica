import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/body_utils.dart';
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: palette.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.edit_note, size: 20, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _quickCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _quickAdd(),
                      // Strip ALL borders from the inner field — the
                      // outer DecoratedBox draws the only visible frame.
                      decoration: InputDecoration(
                        hintText: 'Быстрая заметка…',
                        hintStyle: TextStyle(color: palette.muted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward,
                      color: _quickBusy ? palette.muted : palette.fg,
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
                    .where((e) =>
                        !e.tags.any((t) => t.startsWith('menu/')))
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

                // Notes are reverse-chronological (newest first), so for
                // index `i > 0` the visual gap between notes[i-1] (above,
                // newer) and notes[i] (below, older) is the time between
                // their createdAt's. We render a small "+ 4 ч" label
                // between them like a chat timeline.
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: notes.length * 2 - 1,
                  itemBuilder: (_, i) {
                    if (i.isOdd) {
                      final newer = notes[i ~/ 2];
                      final older = notes[i ~/ 2 + 1];
                      return GapDivider(
                        from: older.createdAt,
                        to: newer.createdAt,
                      );
                    }
                    final note = notes[i ~/ 2];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: EntryCard(entry: note, axesById: axesById),
                    );
                  },
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
      bodyToPlainText(e.body).toLowerCase().contains(q);
}
