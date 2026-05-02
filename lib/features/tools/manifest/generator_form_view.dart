import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../services/generator_input.dart';

/// Snapshot of the form state. Keys are field ids; values are typed
/// (String / int / DateTime / null) according to the field schema.
typedef GeneratorFormValues = Map<String, Object?>;

/// Universal renderer for a list of `GeneratorInputField` descriptors.
/// Stateless — the parent owns the values map and updates it through
/// `onChanged`. This keeps it composable into any flow that needs to
/// collect manifest inputs (the bespoke MenuGeneratorScreen, the
/// generic GeneratorScreen, the in-app authoring preview, etc).
class GeneratorFormView extends StatelessWidget {
  const GeneratorFormView({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
    required this.axes,
    this.errors = const {},
  });

  final List<GeneratorInputField> fields;
  final GeneratorFormValues values;
  final void Function(String id, Object? value) onChanged;
  final List<LifeAxis> axes;

  /// Optional per-field error text. Keys missing from this map render
  /// without an error.
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          _renderField(context, fields[i]),
        ],
      ],
    );
  }

  Widget _renderField(BuildContext context, GeneratorInputField field) {
    return switch (field) {
      GeneratorInputText() => _TextFieldView(
          field: field,
          value: values[field.id] as String? ?? field.defaultValue,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      GeneratorInputInt() => _IntFieldView(
          field: field,
          value: values[field.id] as int? ?? field.defaultValue,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      GeneratorInputEnum() => _EnumFieldView(
          field: field,
          value: values[field.id] as String? ?? field.defaultValue,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      GeneratorInputDate() => _DateFieldView(
          field: field,
          value: values[field.id] as DateTime?,
          error: errors[field.id],
          onChanged: (v) => onChanged(field.id, v),
        ),
      GeneratorInputAxisRef() => _AxisFieldView(
          field: field,
          value: values[field.id] as String?,
          error: errors[field.id],
          axes: axes,
          onChanged: (v) => onChanged(field.id, v),
        ),
    };
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.field, this.error});

  final GeneratorInputField field;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (field.help != null) ...[
          const SizedBox(height: 4),
          Text(
            field.help!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _TextFieldView extends StatefulWidget {
  const _TextFieldView({
    required this.field,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  final GeneratorInputText field;
  final String? value;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFieldView> createState() => _TextFieldViewState();
}

class _TextFieldViewState extends State<_TextFieldView> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _ctrl.addListener(() {
      if (_ctrl.text != (widget.value ?? '')) {
        widget.onChanged(_ctrl.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TextFieldView old) {
    super.didUpdateWidget(old);
    final external = widget.value ?? '';
    if (external != _ctrl.text) {
      // Sync external resets (e.g. parent clears the form) without
      // fighting the user's keyboard typing.
      _ctrl.text = external;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          minLines: f.multiline ? f.minLines : 1,
          maxLines: f.multiline ? f.maxLines : 1,
          decoration: InputDecoration(
            labelText: f.label,
            hintText: f.placeholder,
            helperText: f.help,
            border: const OutlineInputBorder(),
            errorText: widget.error,
          ),
        ),
      ],
    );
  }
}

class _IntFieldView extends StatelessWidget {
  const _IntFieldView({
    required this.field,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  final GeneratorInputInt field;
  final int value;
  final String? error;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(field: field, error: error),
        const SizedBox(height: 8),
        if (field.presentation == IntInputPresentation.chips)
          _chips(context)
        else
          _stepper(context),
      ],
    );
  }

  Widget _chips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var v = field.min; v <= field.max; v += field.step)
          ChoiceChip(
            label: Text(v.toString()),
            selected: value == v,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }

  Widget _stepper(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > field.min
              ? () => onChanged((value - field.step).clamp(field.min, field.max))
              : null,
        ),
        Expanded(
          child: Center(
            child: Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < field.max
              ? () => onChanged((value + field.step).clamp(field.min, field.max))
              : null,
        ),
      ],
    );
  }
}

class _EnumFieldView extends StatelessWidget {
  const _EnumFieldView({
    required this.field,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  final GeneratorInputEnum field;
  final String? value;
  final String? error;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(field: field, error: error),
        const SizedBox(height: 8),
        if (field.presentation == EnumInputPresentation.chips)
          _chips()
        else
          _dropdown(),
      ],
    );
  }

  Widget _chips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in field.options)
          ChoiceChip(
            label: Text(opt.label),
            selected: value == opt.value,
            onSelected: (_) => onChanged(opt.value),
          ),
      ],
    );
  }

  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        for (final opt in field.options)
          DropdownMenuItem(value: opt.value, child: Text(opt.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateFieldView extends StatelessWidget {
  const _DateFieldView({
    required this.field,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  final GeneratorInputDate field;
  final DateTime? value;
  final String? error;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final picked = value ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(field: field, error: error),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_format(picked)),
          onPressed: () => _pick(context),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(Duration(days: field.daysBefore)),
      lastDate: now.add(Duration(days: field.daysAfter)),
    );
    if (result != null) onChanged(result);
  }

  String _format(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _AxisFieldView extends StatelessWidget {
  const _AxisFieldView({
    required this.field,
    required this.value,
    required this.error,
    required this.axes,
    required this.onChanged,
  });

  final GeneratorInputAxisRef field;
  final String? value;
  final String? error;
  final List<LifeAxis> axes;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (axes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(field: field, error: error),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final a in axes)
              DropdownMenuItem(
                value: a.id,
                child: Text('${a.symbol} ${a.name}'),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Picks the axis whose name / symbol best matches `hint` (case-insensitive
/// substring), or falls back to the first axis. Mirrors the existing
/// MenuGeneratorScreen behaviour and is exposed so the universal
/// runtime can do the same auto-selection on form load.
String? autoSelectAxisId({
  required List<LifeAxis> axes,
  String? hint,
}) {
  if (axes.isEmpty) return null;
  if (hint == null || hint.isEmpty) return axes.first.id;
  final h = hint.toLowerCase();
  for (final a in axes) {
    if (a.name.toLowerCase().contains(h) ||
        a.symbol.toLowerCase().contains(h)) {
      return a.id;
    }
  }
  return axes.first.id;
}
