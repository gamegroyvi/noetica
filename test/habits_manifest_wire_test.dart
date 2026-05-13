import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/l10n/generated/app_localizations_ru.dart';
import 'package:noetica/services/builtin_generators.dart';
import 'package:noetica/services/generator_input.dart';
import 'package:noetica/services/generator_manifest.dart';
import 'package:noetica/services/tools_api.dart';

void main() {
  final tr = SRu();

  group('micro-habits manifest <-> backend wire contract', () {
    test('manifest declares the field ids the screen reads', () {
      final ids = habitsInputs(tr).map((f) => f.id).toSet();
      expect(
        ids,
        containsAll(<String>{'intent', 'duration_days', 'axis_id', 'notes'}),
      );
    });

    test('duration range stays inside backend tolerance (3..30)', () {
      final f = habitsInputs(tr).firstWhere((f) => f.id == 'duration_days')
          as GeneratorInputInt;
      expect(f.min, greaterThanOrEqualTo(3));
      expect(f.max, lessThanOrEqualTo(30));
    });

    test('intent is required and multiline', () {
      final f = habitsInputs(tr).firstWhere((f) => f.id == 'intent')
          as GeneratorInputText;
      expect(f.required, isTrue);
      expect(f.multiline, isTrue);
    });

    test('manifest is registered as available with a builder', () {
      final manifest = defaultBuiltinManifests(tr)
          .firstWhere((m) => m.id == 'micro-habits');
      expect(manifest.status, GeneratorStatus.available);
      expect(manifest.builder, isNotNull);
      expect(manifest.inputs, isNotEmpty);
    });

    test('HabitsPlan.fromJson tolerates missing fields', () {
      final plan = HabitsPlan.fromJson(<String, Object?>{
        'model': 'm',
        'intent': 'Хочу засыпать раньше',
        'days': [
          {'day_index': 1, 'title': 'Действие', 'why': 'Причина'},
        ],
      });
      expect(plan.summary, isEmpty);
      expect(plan.days, hasLength(1));
      expect(plan.days.first.dayIndex, 1);
      expect(plan.days.first.title, 'Действие');
    });
  });
}
