import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models.dart';
import '../../../providers.dart';
import '../../../services/generator_input.dart';
import '../../../services/generator_manifest.dart';
import '../../../services/generator_run_spec.dart';
import '../../../theme/app_theme.dart';
import '../manifest/generator_form_view.dart';

/// Stages the universal runtime walks the user through.
enum _Stage { form, generating, preview, importing }

/// Universal runtime screen — drives any manifest that opts in via
/// non-empty `promptSystem` / `promptUser`. The flow is:
///
/// 1. **Form** — render `manifest.inputs` via `GeneratorFormView`.
/// 2. **Generate** — POST `/tools/run` with the manifest's prompt
///    template + form values; server renders `{key}` placeholders
///    and validates the JSON response.
/// 3. **Preview** — show items as cards (title + body + day-offset).
/// 4. **Import** — create N entries (tasks or notes) per
///    `manifest.importSpec`. Tags include `<manifest_id>` and
///    optionally `<tagPrefix>/<runId>` so future "delete this run"
///    actions stay scoped.
///
/// This is the screen user-authored manifests (PR #35+) will use
/// without changes — authors tweak the manifest, the runtime stays
/// the same.
class GeneratorRunScreen extends ConsumerStatefulWidget {
  const GeneratorRunScreen({required this.manifest, super.key});

  final GeneratorManifest manifest;

  @override
  ConsumerState<GeneratorRunScreen> createState() => _GeneratorRunScreenState();
}

class _GeneratorRunScreenState extends ConsumerState<GeneratorRunScreen> {
  _Stage _stage = _Stage.form;
  String? _error;
  final GeneratorFormValues _values = {};
  GeneratorRunResult? _result;

  @override
  void initState() {
    super.initState();
    _seedValuesFromManifest();
  }

  void _seedValuesFromManifest() {
    _values.clear();
    for (final f in widget.manifest.inputs) {
      _values[f.id] = f.defaultValue;
    }
  }

  // ---- input-map prep -----------------------------------------------------

  /// Convert form values into the `inputs` map sent to `/tools/run`.
  ///
  /// For each axis-ref input the backend gets two keys: the raw axis
  /// id (`{axis_id}`) AND a companion `{axis_id_name}` carrying the
  /// human-readable axis label, so authors can write either in their
  /// prompt template. Empty string when no axis was picked.
  Map<String, Object?> _buildInputs(List<LifeAxis> axes) {
    final out = <String, Object?>{};
    for (final field in widget.manifest.inputs) {
      final raw = _values[field.id];
      out[field.id] = _serialiseValue(raw);
      if (field is GeneratorInputAxisRef) {
        final id = (raw as String?)?.trim() ?? '';
        String name = '';
        if (id.isNotEmpty) {
          for (final a in axes) {
            if (a.id == id) {
              name = a.name;
              break;
            }
          }
        }
        out['${field.id}_name'] = name;
      }
    }
    return out;
  }

  Object? _serialiseValue(Object? raw) {
    // Backend accepts str | int | float | bool. Coerce DateTime to
    // ISO string and any other unknown to its toString.
    if (raw == null) return '';
    if (raw is DateTime) {
      return '${raw.year.toString().padLeft(4, '0')}-'
          '${raw.month.toString().padLeft(2, '0')}-'
          '${raw.day.toString().padLeft(2, '0')}';
    }
    if (raw is String || raw is int || raw is double || raw is bool) {
      return raw;
    }
    return raw.toString();
  }

  // ---- validation ---------------------------------------------------------

  String? _validateForm() {
    for (final f in widget.manifest.inputs) {
      final v = _values[f.id];
      final res = validateGeneratorField(f, v);
      if (!res.isValid) return res.error;
    }
    return null;
  }

  // ---- generate -----------------------------------------------------------

  Future<void> _generate() async {
    final formError = _validateForm();
    if (formError != null) {
      setState(() => _error = formError);
      return;
    }
    setState(() {
      _stage = _Stage.generating;
      _error = null;
    });
    try {
      final api = ref.read(toolsApiProvider);
      final axes = ref.read(axesProvider).valueOrNull ?? const <LifeAxis>[];
      final inputs = _buildInputs(axes);
      final result = await api.runGenerator(
        manifestId: widget.manifest.id,
        promptSystem: widget.manifest.promptSystem,
        promptUser: widget.manifest.promptUser,
        inputs: inputs,
        maxItems: widget.manifest.maxItems,
        temperature: widget.manifest.temperature,
      );
      if (!mounted) return;
      if (result.items.isEmpty) {
        setState(() {
          _error = 'AI не вернул ни одного пункта. Попробуй ещё раз.';
          _stage = _Stage.form;
        });
        return;
      }
      setState(() {
        _result = result;
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.form;
      });
    }
  }

  // ---- import -------------------------------------------------------------

  Future<void> _import() async {
    final result = _result;
    if (result == null) return;
    setState(() {
      _stage = _Stage.importing;
      _error = null;
    });
    try {
      final repo = await ref.read(repositoryProvider.future);
      final spec = widget.manifest.importSpec;
      final axes = ref.read(axesProvider).valueOrNull ?? const <LifeAxis>[];
      final runId = const Uuid().v4().substring(0, 8);
      final tags = <String>[
        widget.manifest.id,
        if (spec.tagPrefix.isNotEmpty) '${spec.tagPrefix}/$runId',
      ];

      // Resolve axis from the form's axis-ref input.
      final axisIdRaw = spec.axisIdInputId == null
          ? null
          : _values[spec.axisIdInputId] as String?;
      final axisIds = (axisIdRaw != null && axisIdRaw.isNotEmpty)
          ? [axisIdRaw]
          : const <String>[];

      // Pre-compute the schedule anchor — today at the manifest's
      // dueHour. We add Duration(days: …) per item below.
      final now = DateTime.now();
      final anchor = DateTime(
        now.year,
        now.month,
        now.day,
        spec.dueHourLocal,
      );

      for (var i = 0; i < result.items.length; i++) {
        final item = result.items[i];
        final dueAt = _computeDueAt(spec, anchor, i, item.dueOffsetDays);
        final entryKind = spec.importAs == GeneratorImportTarget.task
            ? EntryKind.task
            : EntryKind.note;
        await repo.createEntry(
          title: item.title.isEmpty
              ? '${widget.manifest.title} #${i + 1}'
              : item.title,
          body: _composeBody(item, i, result.items.length, axes, axisIdRaw),
          kind: entryKind,
          dueAt: dueAt,
          xp: spec.importAs == GeneratorImportTarget.task ? spec.xpPerItem : 0,
          axisIds: axisIds,
          tags: tags,
        );
      }

      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.manifest.title} — добавлено '
            '${result.items.length} ${_pluralItems(result.items.length, spec)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось импортировать: $e';
        _stage = _Stage.preview;
      });
    }
  }

  DateTime? _computeDueAt(
    GeneratorImportSpec spec,
    DateTime anchor,
    int index,
    int? llmOffset,
  ) {
    switch (spec.dueStrategy) {
      case GeneratorDueStrategy.none:
        return null;
      case GeneratorDueStrategy.today:
        return anchor;
      case GeneratorDueStrategy.ladder:
        return anchor.add(Duration(days: index));
      case GeneratorDueStrategy.respectOffset:
        final off = llmOffset ?? 0;
        return anchor.add(Duration(days: off));
    }
  }

  String _composeBody(
    GeneratorRunItem item,
    int index,
    int total,
    List<LifeAxis> axes,
    String? axisId,
  ) {
    final buf = StringBuffer();
    if (item.body.isNotEmpty) {
      buf.writeln(item.body);
      buf.writeln();
    }
    final footer = StringBuffer();
    footer.write(
      '_${widget.manifest.title} · ${index + 1} из ${total}_',
    );
    if (axisId != null) {
      for (final a in axes) {
        if (a.id == axisId) {
          footer.write(' · ось «${a.name}»');
          break;
        }
      }
    }
    buf.write(footer.toString());
    return buf.toString().trim();
  }

  String _pluralItems(int n, GeneratorImportSpec spec) {
    final last = n % 10;
    final lastTwo = n % 100;
    if (spec.importAs == GeneratorImportTarget.task) {
      if (lastTwo >= 11 && lastTwo <= 14) return 'задач';
      if (last == 1) return 'задача';
      if (last >= 2 && last <= 4) return 'задачи';
      return 'задач';
    } else {
      if (lastTwo >= 11 && lastTwo <= 14) return 'заметок';
      if (last == 1) return 'заметка';
      if (last >= 2 && last <= 4) return 'заметки';
      return 'заметок';
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manifest.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.form => _buildForm(palette),
          _Stage.generating =>
            _buildBusy(palette, 'AI подбирает шаги…'),
          _Stage.preview => _buildPreview(palette),
          _Stage.importing =>
            _buildBusy(palette, 'Создаю записи в Noetica…'),
        },
      ),
    );
  }

  Widget _buildForm(NoeticaPalette palette) {
    final theme = Theme.of(context);
    final axesAsync = ref.watch(axesProvider);
    final axes = axesAsync.valueOrNull ?? const <LifeAxis>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.manifest.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.manifest.description,
              style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
          ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: TextStyle(color: palette.fg)),
          ),
        if (widget.manifest.inputs.isNotEmpty)
          GeneratorFormView(
            fields: widget.manifest.inputs,
            values: _values,
            axes: axes,
            onChanged: (id, v) => setState(() => _values[id] = v),
          ),
        if (widget.manifest.bullets.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Что я создам', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                for (final b in widget.manifest.bullets) _bullet(palette, b),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Сгенерировать'),
          onPressed: _generate,
        ),
      ],
    );
  }

  Widget _buildBusy(NoeticaPalette palette, String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: palette.fg),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(color: palette.muted)),
        ],
      ),
    );
  }

  Widget _buildPreview(NoeticaPalette palette) {
    final theme = Theme.of(context);
    final result = _result!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              if (result.summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    result.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              for (var i = 0; i < result.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemCard(
                    palette: palette,
                    index: i + 1,
                    total: result.items.length,
                    item: result.items[i],
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: palette.fg),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Сгенерировать заново'),
                  onPressed: _generate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_task, size: 18),
                  label: Text('Добавить ${result.items.length}'),
                  onPressed: _import,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(NoeticaPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: palette.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: TextStyle(color: palette.fg))),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.palette,
    required this.index,
    required this.total,
    required this.item,
  });

  final NoeticaPalette palette;
  final int index;
  final int total;
  final GeneratorRunItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
              if (item.dueOffsetDays != null) ...[
                const SizedBox(width: 6),
                Text(
                  _offsetLabel(item.dueOffsetDays!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(color: palette.fg),
          ),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.body,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _offsetLabel(int offset) {
    if (offset == 0) return 'сегодня';
    if (offset == 1) return 'завтра';
    return 'через $offset дн.';
  }
}
