import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/data/models.dart';
import 'package:noetica/features/tools/manifest/generator_form_view.dart';
import 'package:noetica/services/builtin_generators.dart';
import 'package:noetica/services/generator_input.dart';

void main() {
  Widget wrap({
    required List<GeneratorInputField> fields,
    required GeneratorFormValues values,
    required void Function(String, Object?) onChanged,
    List<LifeAxis> axes = const [],
    Map<String, String> errors = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GeneratorFormView(
            fields: fields,
            values: values,
            onChanged: onChanged,
            axes: axes,
            errors: errors,
          ),
        ),
      ),
    );
  }

  testWidgets('renders one ChoiceChip per enum option', (tester) async {
    const field = GeneratorInputEnum(
      id: 'goal',
      label: 'Цель',
      options: [
        GeneratorEnumOption(value: 'a', label: 'A'),
        GeneratorEnumOption(value: 'b', label: 'B'),
        GeneratorEnumOption(value: 'c', label: 'C'),
      ],
      initial: 'a',
    );
    final values = <String, Object?>{'goal': 'a'};
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: values,
      onChanged: (id, v) => values[id] = v,
    ));
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('tapping an enum chip emits onChanged with the new value',
      (tester) async {
    const field = GeneratorInputEnum(
      id: 'goal',
      label: 'Цель',
      options: [
        GeneratorEnumOption(value: 'a', label: 'A'),
        GeneratorEnumOption(value: 'b', label: 'B'),
      ],
      initial: 'a',
    );
    String? captured;
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'goal': 'a'},
      onChanged: (_, v) => captured = v as String?,
    ));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(captured, 'b');
  });

  testWidgets('renders one ChoiceChip per int between min and max',
      (tester) async {
    const field = GeneratorInputInt(
      id: 'p',
      label: 'Порций',
      min: 1,
      max: 4,
    );
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'p': 1},
      onChanged: (_, __) {},
    ));
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('renders multiline TextField for multiline text fields',
      (tester) async {
    const field = GeneratorInputText(
      id: 'notes',
      label: 'Notes',
      multiline: true,
      minLines: 2,
      maxLines: 4,
    );
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'notes': ''},
      onChanged: (_, __) {},
    ));
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.maxLines, 4);
    expect(tf.minLines, 2);
  });

  testWidgets('renders a calendar button for date fields', (tester) async {
    const field = GeneratorInputDate(id: 'd', label: 'Дата');
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'d': null},
      onChanged: (_, __) {},
    ));
    // OutlinedButton.icon constructs a private internal subclass, so
    // we look for the icon + label instead, which is what the user
    // actually sees.
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.text('Дата'), findsOneWidget);
  });

  testWidgets('axis field is hidden when no axes are available',
      (tester) async {
    const field = GeneratorInputAxisRef(id: 'a', label: 'Ось');
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {},
      onChanged: (_, __) {},
    ));
    expect(find.text('Ось'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('axis field renders a dropdown when axes are available',
      (tester) async {
    const field = GeneratorInputAxisRef(id: 'a', label: 'Ось');
    final axes = <LifeAxis>[
      LifeAxis(
        id: 'body',
        name: 'Тело',
        symbol: 'B',
        position: 0,
        createdAt: DateTime.now(),
      ),
      LifeAxis(
        id: 'mind',
        name: 'Разум',
        symbol: 'M',
        position: 1,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'a': null},
      axes: axes,
      onChanged: (_, __) {},
    ));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('errors map propagates to the rendered field', (tester) async {
    const field = GeneratorInputInt(
      id: 'p',
      label: 'Порций',
      min: 1,
      max: 4,
    );
    await tester.pumpWidget(wrap(
      fields: const [field],
      values: const {'p': 1},
      errors: const {'p': 'oops'},
      onChanged: (_, __) {},
    ));
    expect(find.text('oops'), findsOneWidget);
  });

  group('autoSelectAxisId', () {
    test('returns null when there are no axes', () {
      expect(autoSelectAxisId(axes: const []), isNull);
    });

    test('returns the first axis when no hint is provided', () {
      final axes = <LifeAxis>[
        LifeAxis(
          id: 'mind',
          name: 'Разум',
          symbol: 'M',
          position: 0,
          createdAt: DateTime.now(),
        ),
        LifeAxis(
          id: 'body',
          name: 'Тело',
          symbol: 'B',
          position: 1,
          createdAt: DateTime.now(),
        ),
      ];
      expect(autoSelectAxisId(axes: axes), 'mind');
    });

    test('returns the first matching axis on hint substring', () {
      final axes = <LifeAxis>[
        LifeAxis(
          id: 'mind',
          name: 'Разум',
          symbol: 'M',
          position: 0,
          createdAt: DateTime.now(),
        ),
        LifeAxis(
          id: 'body',
          name: 'Тело',
          symbol: 'B',
          position: 1,
          createdAt: DateTime.now(),
        ),
      ];
      expect(autoSelectAxisId(axes: axes, hint: 'тело'), 'body');
    });
  });

  group('menuWeekInputs sanity', () {
    test('menuWeekInputs() returns the documented schema', () {
      final fs = menuWeekInputs();
      expect(fs.map((f) => f.id), [
        'goal',
        'servings',
        'start_date',
        'axis_id',
        'restrictions',
        'notes',
      ]);
    });
  });
}
