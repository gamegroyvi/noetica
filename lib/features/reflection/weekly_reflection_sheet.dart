import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../services/weekly_reflection_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet that asks the user how the past week went. The questions
/// rely on chip-style multi-select to keep typing to a minimum, but every
/// section has an optional "своё" text input as a fallback.
///
/// On submit the answers are appended to `PersonalKnowledge.recentReflections`
/// so the next LLM roadmap call can use them as context.
class WeeklyReflectionSheet extends StatefulWidget {
  const WeeklyReflectionSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => const WeeklyReflectionSheet(),
    );
  }

  @override
  State<WeeklyReflectionSheet> createState() => _WeeklyReflectionSheetState();
}

class _WeeklyReflectionSheetState extends State<WeeklyReflectionSheet> {
  final List<String> _wins = [];
  final List<String> _losses = [];
  final List<String> _focusNext = [];
  int _mood = 0; // 1..5; 0 = unset

  final _winsCustom = TextEditingController();
  final _lossesCustom = TextEditingController();
  final _focusCustom = TextEditingController();
  bool _saving = false;

  static const _winOptions = <String>[
    'выполнил план',
    'новые привычки',
    'продвинулся в проекте',
    'отдых был',
    'дисциплина держалась',
    'разобрался в новой теме',
    'хорошие отношения',
  ];
  static const _lossOptions = <String>[
    'прокрастинация',
    'усталость',
    'отвлечения',
    'не уделил время важному',
    'выгорание',
    'болел',
    'конфликты',
  ];
  static const _focusOptions = <String>[
    'добить незавершённое',
    'новая привычка',
    'фокус на главном',
    'отдых',
    'учёба',
    'спорт',
    'отношения',
  ];

  @override
  void dispose() {
    _winsCustom.dispose();
    _lossesCustom.dispose();
    _focusCustom.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    HapticFeedback.selectionClick();
    try {
      final wins = [..._wins, _winsCustom.text.trim()].where((s) => s.isNotEmpty);
      final losses = [..._losses, _lossesCustom.text.trim()].where((s) => s.isNotEmpty);
      final focus = [..._focusNext, _focusCustom.text.trim()].where((s) => s.isNotEmpty);

      final summary = _summary(
        wins: wins.toList(),
        losses: losses.toList(),
        focusNext: focus.toList(),
        mood: _mood,
      );

      // Append to PersonalKnowledge.recentReflections via the service. We
      // reuse the same plumbing as the per-task reflection (status=normal)
      // so the LLM treats this as one more reflection line in CONTEXT.
      await PersonalKnowledgeService().recordReflection(
        taskTitle: 'Итог недели',
        status: ReflectionStatus.normal,
        outcome: summary,
        difficulties: '',
      );
      await WeeklyReflectionService.instance.markShownNow();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не сохранилось: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _snooze() async {
    await WeeklyReflectionService.instance.snoozeOneDay();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _summary({
    required List<String> wins,
    required List<String> losses,
    required List<String> focusNext,
    required int mood,
  }) {
    final parts = <String>[];
    if (wins.isNotEmpty) parts.add('+ ${wins.join(", ")}');
    if (losses.isNotEmpty) parts.add('- ${losses.join(", ")}');
    if (focusNext.isNotEmpty) parts.add('→ ${focusNext.join(", ")}');
    if (mood > 0) parts.add('самочувствие $mood/5');
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Итог недели',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Заглянем коротко: что было, что нет, и куда дальше.',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _Section(
                label: 'Что получилось',
                options: _winOptions,
                selected: _wins,
                custom: _winsCustom,
                onPick: (v) => setState(() => _toggle(_wins, v)),
                palette: palette,
              ),
              const SizedBox(height: 18),
              _Section(
                label: 'Что не получилось',
                options: _lossOptions,
                selected: _losses,
                custom: _lossesCustom,
                onPick: (v) => setState(() => _toggle(_losses, v)),
                palette: palette,
              ),
              const SizedBox(height: 18),
              _Section(
                label: 'Куда смотрю на следующую',
                options: _focusOptions,
                selected: _focusNext,
                custom: _focusCustom,
                onPick: (v) => setState(() => _toggle(_focusNext, v)),
                palette: palette,
              ),
              const SizedBox(height: 18),
              Text(
                'Самочувствие',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _mood = i),
                        child: Container(
                          margin: EdgeInsets.only(right: i == 5 ? 0 : 6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mood == i ? palette.fg : palette.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _mood == i ? palette.fg : palette.line,
                            ),
                          ),
                          child: Text(
                            '$i',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _mood == i ? palette.bg : palette.fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _snooze,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.fg,
                        side: BorderSide(color: palette.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Позже'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.fg,
                        foregroundColor: palette.bg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_saving ? '...' : 'Записать'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(List<String> bag, String v) {
    final idx =
        bag.indexWhere((e) => e.toLowerCase() == v.toLowerCase());
    if (idx >= 0) {
      bag.removeAt(idx);
    } else {
      bag.add(v);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.options,
    required this.selected,
    required this.custom,
    required this.onPick,
    required this.palette,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final TextEditingController custom;
  final ValueChanged<String> onPick;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    final selLower = selected.map((e) => e.toLowerCase()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              _Chip(
                label: opt,
                selected: selLower.contains(opt.toLowerCase()),
                onTap: () => onPick(opt),
                palette: palette,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: custom,
          decoration: InputDecoration(
            hintText: 'Своё (необязательно)',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.fg, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final NoeticaPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.fg : palette.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? palette.fg : palette.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.bg : palette.fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
