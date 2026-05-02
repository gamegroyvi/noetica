import 'package:flutter/foundation.dart';

/// Declarative input field for a generator manifest.
///
/// Each subclass corresponds to one piece of UI a manifest can request
/// from the user (chips / stepper / date picker / dropdown / text
/// area). The `id` is what `GeneratorFormState` uses as a map key, so
/// it must be unique within a manifest.
///
/// This schema is the **persistence shape** — it's what user-authored
/// manifests will eventually serialise to YAML / JSON. Adding new
/// fields therefore needs care: prefer optional named parameters with
/// safe defaults so old manifests keep loading.
@immutable
sealed class GeneratorInputField {
  const GeneratorInputField({
    required this.id,
    required this.label,
    this.help,
    this.required = false,
  });

  final String id;
  final String label;

  /// Optional one-liner shown under the label as a hint.
  final String? help;

  /// When true, the form considers the field invalid if it's blank.
  final bool required;

  /// The "natural" empty / starting value for this field. The form
  /// view seeds its state with this when no override is provided.
  Object? get defaultValue;
}

/// Plain text input. `multiline` switches between single-line and a
/// 3–4 row textarea (e.g. dietary restrictions, freeform notes).
class GeneratorInputText extends GeneratorInputField {
  const GeneratorInputText({
    required super.id,
    required super.label,
    super.help,
    super.required,
    this.placeholder,
    this.multiline = false,
    this.initial = '',
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String? placeholder;
  final bool multiline;
  final String initial;
  final int minLines;
  final int maxLines;

  @override
  String get defaultValue => initial;
}

/// Integer field. `presentation` tells the form view whether to render
/// chips (best for small fixed ranges like portions 1–6) or a stepper
/// / numeric text field (long ranges).
enum IntInputPresentation { chips, stepper }

class GeneratorInputInt extends GeneratorInputField {
  const GeneratorInputInt({
    required super.id,
    required super.label,
    super.help,
    super.required,
    required this.min,
    required this.max,
    this.step = 1,
    this.initial = 1,
    this.presentation = IntInputPresentation.chips,
  })  : assert(min <= max, 'min must be <= max'),
        assert(step > 0, 'step must be positive');

  final int min;
  final int max;
  final int step;
  final int initial;
  final IntInputPresentation presentation;

  @override
  int get defaultValue => initial.clamp(min, max);
}

/// Single-choice enum field (chips by default, dropdown for long
/// option lists).
enum EnumInputPresentation { chips, dropdown }

@immutable
class GeneratorEnumOption {
  const GeneratorEnumOption({required this.value, required this.label});
  final String value;
  final String label;
}

class GeneratorInputEnum extends GeneratorInputField {
  const GeneratorInputEnum({
    required super.id,
    required super.label,
    super.help,
    super.required,
    required this.options,
    this.initial,
    this.presentation = EnumInputPresentation.chips,
  });

  final List<GeneratorEnumOption> options;
  final String? initial;
  final EnumInputPresentation presentation;

  @override
  String? get defaultValue =>
      initial ?? (options.isNotEmpty ? options.first.value : null);
}

/// Single-date field (e.g. start date). Returns ISO yyyy-MM-dd.
class GeneratorInputDate extends GeneratorInputField {
  const GeneratorInputDate({
    required super.id,
    required super.label,
    super.help,
    super.required,
    this.daysBefore = 7,
    this.daysAfter = 60,
  });

  /// How many days into the past / future the date picker accepts,
  /// relative to "today" at form-render time.
  final int daysBefore;
  final int daysAfter;

  @override
  String? get defaultValue => null;
}

/// Reference to a `LifeAxis`. The form view turns this into a
/// dropdown of the user's existing axes; no axes → field is hidden.
class GeneratorInputAxisRef extends GeneratorInputField {
  const GeneratorInputAxisRef({
    required super.id,
    required super.label,
    super.help,
    super.required,
    this.preferAxisHint,
  });

  /// Optional hint for auto-selection. Currently the form view
  /// auto-selects the first axis whose name / symbol contains the
  /// hint substring (case-insensitive); falls back to the first
  /// axis. Future implementations may use a richer "tag" mechanism.
  final String? preferAxisHint;

  @override
  String? get defaultValue => null;
}

/// Validation result for a single field. `isValid` is the gate; the
/// `error` (if any) is human-readable.
@immutable
class FieldValidation {
  const FieldValidation.ok() : error = null;
  const FieldValidation.error(this.error);

  final String? error;

  bool get isValid => error == null;
}

FieldValidation validateGeneratorField(
  GeneratorInputField field,
  Object? value,
) {
  if (field.required) {
    if (value == null) {
      return const FieldValidation.error('Поле обязательно');
    }
    if (value is String && value.trim().isEmpty) {
      return const FieldValidation.error('Поле обязательно');
    }
  }
  if (value is int && field is GeneratorInputInt) {
    if (value < field.min || value > field.max) {
      return FieldValidation.error(
        'Должно быть от ${field.min} до ${field.max}',
      );
    }
  }
  return const FieldValidation.ok();
}
