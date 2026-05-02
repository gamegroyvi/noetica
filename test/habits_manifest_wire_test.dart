import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/builtin_generators.dart';
import 'package:noetica/services/generator_input.dart';
import 'package:noetica/services/generator_manifest.dart';
import 'package:noetica/services/tools_api.dart';

void main() {
  group('micro-habits manifest <-> backend wire contract', () {
    test('manifest declares the field ids the screen reads', () {
      final ids = habitsInputs().map((f) => f.id).toSet();
      // _generate() / _import() reach into _values via these keys.
      expect(
        ids,
        containsAll(<String>{'intent', 'duration_days', 'axis_id', 'notes'}),
      );
    });

    test('duration range stays inside backend tolerance (3..30)', () {
      final f = habitsInputs().firstWhere((f) => f.id == 'duration_days')
          as GeneratorInputInt;
      // Backend HabitsRequest.duration_days enforces ge=3 le=30. The
      // manifest can stay narrower (we ship 3..21 to keep chips
      // tappable) but must NEVER widen past those bounds.
      expect(f.min, greaterThanOrEqualTo(3));
      expect(f.max, lessThanOrEqualTo(30));
    });

    test('intent is required and multiline', () {
      final f = habitsInputs().firstWhere((f) => f.id == 'intent')
          as GeneratorInputText;
      expect(f.required, isTrue);
      expect(f.multiline, isTrue);
    });

    test('manifest is registered as available with a builder', () {
      final manifest = defaultBuiltinManifests()
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
