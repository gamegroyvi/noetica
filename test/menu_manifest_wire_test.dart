import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/builtin_generators.dart';
import 'package:noetica/services/generator_input.dart';
import 'package:noetica/services/tools_api.dart';

void main() {
  group('menu-week manifest <-> backend wire contract', () {
    test('every goal option round-trips through MenuGoal.fromWire', () {
      final goal = menuWeekInputs().firstWhere((f) => f.id == 'goal')
          as GeneratorInputEnum;
      for (final opt in goal.options) {
        final parsed = MenuGoal.fromWire(opt.value);
        expect(
          parsed.wire,
          opt.value,
          reason:
              'Manifest option "${opt.value}" must match a real MenuGoal '
              '(otherwise the backend will reject the request).',
        );
      }
    });

    test('servings range matches backend tolerance', () {
      final f = menuWeekInputs().firstWhere((f) => f.id == 'servings')
          as GeneratorInputInt;
      expect(f.min, 1);
      expect(f.max, 6);
    });

    test('manifest declares the same set of fields _generate() reads', () {
      final ids = menuWeekInputs().map((f) => f.id).toSet();
      // _generate() uses these keys via the convenience getters in
      // _MenuGeneratorScreenState. If we ever rename one without
      // updating the screen, this test breaks before runtime does.
      expect(
        ids,
        containsAll(<String>{
          'goal',
          'servings',
          'start_date',
          'axis_id',
          'restrictions',
          'notes',
        }),
      );
    });
  });
}
