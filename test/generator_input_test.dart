import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/generator_input.dart';

void main() {
  group('GeneratorInputText', () {
    test('default value is the configured initial', () {
      const f = GeneratorInputText(
        id: 'notes',
        label: 'Notes',
        initial: 'hello',
      );
      expect(f.defaultValue, 'hello');
    });

    test('required + blank fails validation', () {
      const f = GeneratorInputText(
        id: 'goal',
        label: 'Goal',
        required: true,
      );
      expect(validateGeneratorField(f, '').isValid, isFalse);
      expect(validateGeneratorField(f, '   ').isValid, isFalse);
      expect(validateGeneratorField(f, 'something').isValid, isTrue);
    });

    test('optional + blank passes validation', () {
      const f = GeneratorInputText(id: 'notes', label: 'Notes');
      expect(validateGeneratorField(f, '').isValid, isTrue);
      expect(validateGeneratorField(f, null).isValid, isTrue);
    });
  });

  group('GeneratorInputInt', () {
    test('default value is clamped into [min..max]', () {
      const a = GeneratorInputInt(
        id: 'p', label: 'P', min: 1, max: 6, initial: 99,
      );
      expect(a.defaultValue, 6);
      const b = GeneratorInputInt(
        id: 'p', label: 'P', min: 2, max: 6, initial: 1,
      );
      expect(b.defaultValue, 2);
    });

    test('value outside [min..max] fails validation', () {
      const f = GeneratorInputInt(
        id: 'p', label: 'P', min: 1, max: 6,
      );
      expect(validateGeneratorField(f, 0).isValid, isFalse);
      expect(validateGeneratorField(f, 7).isValid, isFalse);
      expect(validateGeneratorField(f, 3).isValid, isTrue);
    });
  });

  group('GeneratorInputEnum', () {
    test('default value is the configured initial when present', () {
      const f = GeneratorInputEnum(
        id: 'goal',
        label: 'Goal',
        options: [
          GeneratorEnumOption(value: 'a', label: 'A'),
          GeneratorEnumOption(value: 'b', label: 'B'),
        ],
        initial: 'b',
      );
      expect(f.defaultValue, 'b');
    });

    test('default value falls back to the first option when initial is null',
        () {
      const f = GeneratorInputEnum(
        id: 'goal',
        label: 'Goal',
        options: [
          GeneratorEnumOption(value: 'a', label: 'A'),
          GeneratorEnumOption(value: 'b', label: 'B'),
        ],
      );
      expect(f.defaultValue, 'a');
    });

    test('default value is null when there are no options', () {
      const f = GeneratorInputEnum(
        id: 'goal',
        label: 'Goal',
        options: [],
      );
      expect(f.defaultValue, isNull);
    });
  });

  group('GeneratorInputDate', () {
    test('default value is null', () {
      const f = GeneratorInputDate(id: 'd', label: 'Date');
      expect(f.defaultValue, isNull);
    });
  });

  group('GeneratorInputAxisRef', () {
    test('default value is null', () {
      const f = GeneratorInputAxisRef(id: 'a', label: 'Axis');
      expect(f.defaultValue, isNull);
    });
  });

  group('FieldValidation', () {
    test('FieldValidation.ok has no error', () {
      expect(const FieldValidation.ok().isValid, isTrue);
      expect(const FieldValidation.ok().error, isNull);
    });

    test('FieldValidation.error wraps a message', () {
      const v = FieldValidation.error('msg');
      expect(v.isValid, isFalse);
      expect(v.error, 'msg');
    });
  });
}
