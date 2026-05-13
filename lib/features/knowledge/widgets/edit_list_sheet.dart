import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// Return type for the edit list sheet.
class EditResult {
  const EditResult({required this.value});
  final String value;
}

/// Simple reorderable list editor for PersonalKnowledge branch items.
class EditListSheet extends StatefulWidget {
  const EditListSheet({
    super.key,
    required this.title,
    required this.hint,
    required this.initial,
    required this.scrollController,
    this.maxItems = 12,
  });
  final String title;
  final String hint;
  final List<String> initial;
  final int maxItems;
  final ScrollController scrollController;

  @override
  State<EditListSheet> createState() => _EditListSheetState();
}

class _EditListSheetState extends State<EditListSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final item in widget.initial) TextEditingController(text: item),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (_controllers.length >= widget.maxItems) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _remove(int i) {
    setState(() {
      _controllers[i].dispose();
      _controllers.removeAt(i);
    });
  }

  void _save() {
    final items = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_controllers.length < widget.maxItems)
                  IconButton(
                    tooltip: S.of(context)!.editListAddItem,
                    icon: Icon(Icons.add, color: palette.fg),
                    onPressed: _add,
                  ),
                TextButton.icon(
                  onPressed: _save,
                  icon: Icon(Icons.check, color: palette.fg, size: 18),
                  label: Text(
                    S.of(context)!.axesDone,
                    style: TextStyle(color: palette.fg),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: _controllers.isEmpty
                ? _EmptyListCta(palette: palette, onAdd: _add)
                : ReorderableListView.builder(
                    scrollController: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: _controllers.length,
                    onReorder: (old, nw) {
                      setState(() {
                        final c = _controllers.removeAt(old);
                        _controllers.insert(nw > old ? nw - 1 : nw, c);
                      });
                    },
                    itemBuilder: (_, i) {
                      return Padding(
                        key: ValueKey(_controllers[i]),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.drag_indicator,
                                color: palette.muted, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _controllers[i],
                                style: TextStyle(
                                    color: palette.fg, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: widget.hint,
                                  hintStyle:
                                      TextStyle(color: palette.muted),
                                  filled: true,
                                  fillColor: palette.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: palette.muted, size: 18),
                              onPressed: () => _remove(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListCta extends StatelessWidget {
  const _EmptyListCta({required this.palette, required this.onAdd});
  final NoeticaPalette palette;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.add, color: palette.fg),
        label: Text(
          S.of(context)!.editListAddFirst,
          style: TextStyle(color: palette.fg),
        ),
      ),
    );
  }
}
