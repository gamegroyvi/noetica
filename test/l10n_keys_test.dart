import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB key parity', () {
    test('app_ru.arb and app_en.arb have the same set of keys', () {
      final ruFile = File('lib/l10n/app_ru.arb');
      final enFile = File('lib/l10n/app_en.arb');
      expect(ruFile.existsSync(), isTrue, reason: 'app_ru.arb must exist');
      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');

      final ruData =
          json.decode(ruFile.readAsStringSync()) as Map<String, dynamic>;
      final enData =
          json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;

      // Filter out @-prefixed metadata keys
      final ruKeys =
          ruData.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys =
          enData.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInEn = ruKeys.difference(enKeys);
      final missingInRu = enKeys.difference(ruKeys);

      expect(
        missingInEn,
        isEmpty,
        reason:
            'Keys in app_ru.arb but missing in app_en.arb: $missingInEn',
      );
      expect(
        missingInRu,
        isEmpty,
        reason:
            'Keys in app_en.arb but missing in app_ru.arb: $missingInRu',
      );
    });

    test('both ARB files contain at least 300 keys', () {
      final ruFile = File('lib/l10n/app_ru.arb');
      final ruData =
          json.decode(ruFile.readAsStringSync()) as Map<String, dynamic>;
      final keys =
          ruData.keys.where((k) => !k.startsWith('@')).length;
      expect(keys, greaterThanOrEqualTo(300),
          reason: 'Expected 300+ translation keys, got $keys');
    });
  });
}
