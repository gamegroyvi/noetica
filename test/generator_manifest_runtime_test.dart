import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/generator_manifest.dart';
import 'package:noetica/services/generator_run_spec.dart';

void main() {
  group('GeneratorManifest.hasUniversalRuntime', () {
    test('false when prompts are blank', () {
      const m = GeneratorManifest(
        id: 't',
        title: 'T',
        description: 'd',
        icon: Icons.add,
        status: GeneratorStatus.available,
      );
      expect(m.hasUniversalRuntime, isFalse);
    });

    test('false when only system prompt is set', () {
      const m = GeneratorManifest(
        id: 't',
        title: 'T',
        description: 'd',
        icon: Icons.add,
        status: GeneratorStatus.available,
        promptSystem: 'be helpful',
      );
      expect(m.hasUniversalRuntime, isFalse);
    });

    test('true when both prompts are non-empty', () {
      const m = GeneratorManifest(
        id: 't',
        title: 'T',
        description: 'd',
        icon: Icons.add,
        status: GeneratorStatus.available,
        promptSystem: 'be helpful',
        promptUser: 'do {x}',
      );
      expect(m.hasUniversalRuntime, isTrue);
    });
  });

  group('GeneratorManifest defaults', () {
    test('importSpec defaults to task / today / no axis', () {
      const m = GeneratorManifest(
        id: 't',
        title: 'T',
        description: 'd',
        icon: Icons.add,
        status: GeneratorStatus.available,
      );
      expect(m.importSpec.importAs, GeneratorImportTarget.task);
      expect(m.importSpec.dueStrategy, GeneratorDueStrategy.today);
      expect(m.importSpec.axisIdInputId, isNull);
      expect(m.maxItems, 15);
      expect(m.temperature, 0.6);
    });
  });
}
