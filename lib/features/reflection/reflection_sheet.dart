import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/personal_knowledge_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// Result returned by the Reflection sheet. `null` if the user dismissed
/// without saving (the task should still complete with default XP).
class ReflectionResult {
  const ReflectionResult({
    required this.status,
    required this.outcome,
    required this.difficulties,
    this.actualMinutes,
  });

  final ReflectionStatus status;
  final String outcome;
  final String difficulties;
  final int? actualMinutes;
}

/// Optional post-completion reflection sheet. Triggered when completing a
/// task that looks "substantial enough" to be worth reflecting on (see
/// [shouldOfferReflection]). Always skippable — we never block completion
/// on the user filling in fields.
Future<ReflectionResult?> showReflectionSheet(
  BuildContext context, {
  required Entry task,
}) async {
  return showModalBottomSheet<ReflectionResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _ReflectionSheet(task: task),
    ),
  );
}

/// Heuristic for whether a task is "big enough" that we want to ask the
/// user how it went. Anything with non-trivial XP (proxy for effort) or
/// substantive description qualifies.
///
/// Until [estimatedMinutes] lands as a first-class field on [Entry], we
/// proxy it via XP — XP roughly tracks effort in the existing scoring
/// scheme.
bool shouldOfferReflection(Entry task) {
  if (task.xp >= 25) return true;
  if (task.body.trim().length >= 60) return true;
  return false;
}

/// Toggle a task's completion state. When transitioning to "done" and the
/// task qualifies via [shouldOfferReflection], offer the user the reflection
/// sheet first; if they fill it in, the resulting status feeds into the
/// XP-adjustment factor inside the repository call.
Future<void> toggleTaskWithReflection(
  BuildContext context,
  WidgetRef ref,
  Entry task,
) async {
  final repo = await ref.read(repositoryProvider.future);
  // Re-opening a completed task: just flip, no questions.
  if (task.isCompleted) {
    await repo.toggleTaskComplete(task);
    return;
  }
  ReflectionResult? result;
  if (shouldOfferReflection(task) && context.mounted) {
    result = await showReflectionSheet(context, task: task);
  }
  await repo.toggleTaskComplete(
    task,
    reflectionStatus: result?.status,
  );
  if (result != null) {
    await repo.saveReflection(
      entryId: task.id,
      status: result.status,
      outcome: result.outcome,
      difficulties: result.difficulties,
      actualMinutes: result.actualMinutes,
    );
    // Feed the reflection into the personal knowledge base so it shows up
    // in future LLM prompts.
    await PersonalKnowledgeService().recordReflection(
      taskTitle: task.title,
      status: result.status,
      outcome: result.outcome,
      difficulties: result.difficulties,
    );
  }
}

class _ReflectionSheet extends ConsumerStatefulWidget {
  const _ReflectionSheet({required this.task});

  final Entry task;

  @override
  ConsumerState<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<_ReflectionSheet> {
  ReflectionStatus _status = ReflectionStatus.normal;
  final _outcomeCtrl = TextEditingController();
  final _difficultiesCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill from any existing reflection so re-opening edits in place
    // instead of starting blank.
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = await ref.read(repositoryProvider.future);
    final existing = await repo.getReflection(widget.task.id);
    if (!mounted || existing == null) return;
    setState(() {
      _status = existing.status;
      _outcomeCtrl.text = existing.outcome;
      _difficultiesCtrl.text = existing.difficulties;
      if (existing.actualMinutes != null) {
        _minutesCtrl.text = existing.actualMinutes!.toString();
      }
    });
  }

  @override
  void dispose() {
    _outcomeCtrl.dispose();
    _difficultiesCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    Navigator.of(context).pop(
      ReflectionResult(
        status: _status,
        outcome: _outcomeCtrl.text.trim(),
        difficulties: _difficultiesCtrl.text.trim(),
        actualMinutes: minutes,
      ),
    );
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Как прошло?',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Status chips. Single-select; default is normal.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ReflectionStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _outcomeCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Что получилось / результат',
                  hintText: 'Можно пропустить',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _difficultiesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Что мешало / сложности',
                  hintText: 'Можно пропустить',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Сколько потратил, мин',
                  hintText: 'Можно пропустить',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skip,
                      child: const Text('Пропустить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Сохранить'),
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
}
