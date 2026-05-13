import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:noetica/utils/time_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  group('formatTimestamp', () {
    test('formats date with time', () {
      final t = DateTime(2024, 3, 15, 14, 30);
      final result = formatTimestamp(t);
      expect(result, contains('14:30'));
      expect(result, contains('15'));
    });
  });

  group('formatDateOnly', () {
    test('formats date without time', () {
      final t = DateTime(2024, 1, 1, 10, 0);
      final result = formatDateOnly(t);
      expect(result, contains('2024'));
      expect(result, contains('1'));
    });

    test('formats different months', () {
      final dates = [
        DateTime(2024, 6, 15),
        DateTime(2024, 12, 31),
      ];
      for (final d in dates) {
        final result = formatDateOnly(d);
        expect(result, isNotEmpty);
        expect(result, contains('2024'));
      }
    });
  });
}
