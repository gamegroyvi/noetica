import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/generator_run_spec.dart';

void main() {
  group('GeneratorRunItem.fromJson', () {
    test('parses a typical item', () {
      final item = GeneratorRunItem.fromJson(<String, Object?>{
        'title': 'Сделать так',
        'body': 'Зачем — короткое объяснение.',
        'due_offset_days': 3,
      });
      expect(item.title, 'Сделать так');
      expect(item.body, 'Зачем — короткое объяснение.');
      expect(item.dueOffsetDays, 3);
    });

    test('tolerates missing optional fields', () {
      final item = GeneratorRunItem.fromJson(<String, Object?>{
        'title': 'Только заголовок',
      });
      expect(item.title, 'Только заголовок');
      expect(item.body, isEmpty);
      expect(item.dueOffsetDays, isNull);
    });

    test('coerces double offset to int', () {
      final item = GeneratorRunItem.fromJson(<String, Object?>{
        'title': 'X',
        'due_offset_days': 4.7,
      });
      expect(item.dueOffsetDays, 4);
    });
  });

  group('GeneratorRunResult.fromJson', () {
    test('parses model + summary + items', () {
      final result = GeneratorRunResult.fromJson(<String, Object?>{
        'model': 'llama3-70b',
        'summary': 'Три действия.',
        'items': <Map<String, Object?>>[
          {'title': 'A', 'body': 'a-body'},
          {'title': 'B', 'due_offset_days': 1},
          {'title': 'C', 'due_offset_days': 2},
        ],
      });
      expect(result.model, 'llama3-70b');
      expect(result.summary, 'Три действия.');
      expect(result.items, hasLength(3));
      expect(result.items[0].body, 'a-body');
      expect(result.items[1].dueOffsetDays, 1);
    });

    test('drops non-map items silently', () {
      final result = GeneratorRunResult.fromJson(<String, Object?>{
        'model': 'm',
        'items': <Object?>[
          {'title': 'kept'},
          'not-a-map',
          42,
          {'title': 'also-kept'},
        ],
      });
      expect(result.items.map((i) => i.title), ['kept', 'also-kept']);
    });

    test('defaults when fields missing', () {
      final result = GeneratorRunResult.fromJson(const <String, Object?>{});
      expect(result.model, isEmpty);
      expect(result.summary, isEmpty);
      expect(result.items, isEmpty);
    });
  });

  group('GeneratorImportSpec defaults', () {
    test('produce sane defaults for a fresh manifest', () {
      const spec = GeneratorImportSpec();
      expect(spec.importAs, GeneratorImportTarget.task);
      expect(spec.dueStrategy, GeneratorDueStrategy.today);
      expect(spec.dueHourLocal, 9);
      expect(spec.axisIdInputId, isNull);
      expect(spec.tagPrefix, isEmpty);
      expect(spec.xpPerItem, 5);
    });
  });
}
