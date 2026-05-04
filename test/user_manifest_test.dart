import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/generator_input.dart';
import 'package:noetica/services/generator_manifest.dart';
import 'package:noetica/services/generator_run_spec.dart';
import 'package:noetica/services/user_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserManifest _sample({
  String? title,
  String? promptSystem,
  String? promptUser,
  String? intentLabel,
  bool notesEnabled = false,
}) =>
    UserManifest(
      id: 'abc-123',
      title: title ?? 'My tool',
      description: 'short',
      iconKey: 'rocket',
      promptSystem: promptSystem ?? 'be helpful',
      promptUser: promptUser ?? 'do {intent}',
      intentLabel: intentLabel ?? 'What?',
      intentPlaceholder: 'placeholder',
      notesEnabled: notesEnabled,
      maxItems: 6,
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    );

void main() {
  group('UserManifest.validate', () {
    test('happy path returns null', () {
      expect(_sample().validate(), isNull);
    });

    test('rejects empty title', () {
      expect(_sample(title: '   ').validate(), contains('Назови'));
    });

    test('rejects empty system prompt', () {
      expect(_sample(promptSystem: '').validate(), contains('AI'));
    });

    test('rejects empty user prompt', () {
      expect(_sample(promptUser: '   ').validate(), contains('интент'));
    });

    test('rejects empty intent label', () {
      expect(_sample(intentLabel: '').validate(), contains('пользователя'));
    });
  });

  group('UserManifest.toGenerator', () {
    test('produces an available, runnable manifest', () {
      final g = _sample().toGenerator();
      expect(g.id, 'user/abc-123');
      expect(g.status, GeneratorStatus.available);
      expect(g.source, GeneratorSource.user);
      expect(g.hasUniversalRuntime, isTrue);
      expect(g.maxItems, 6);
      expect(g.importSpec.importAs, GeneratorImportTarget.task);
      expect(g.importSpec.dueStrategy, GeneratorDueStrategy.today);
      expect(g.importSpec.xpPerItem, 5);
    });

    test('emits one input field by default', () {
      final g = _sample().toGenerator();
      expect(g.inputs, hasLength(1));
      expect(g.inputs.first.id, 'intent');
      expect(g.inputs.first.required, isTrue);
      expect(g.inputs.first, isA<GeneratorInputText>());
      expect((g.inputs.first as GeneratorInputText).multiline, isTrue);
    });

    test('adds a notes input when notesEnabled', () {
      final g = _sample(notesEnabled: true).toGenerator();
      expect(g.inputs.map((f) => f.id), ['intent', 'notes']);
      expect(g.inputs[1].required, isFalse);
    });

    test('icon falls back if iconKey is unknown', () {
      final m = _sample().copyWith(iconKey: 'no-such-icon');
      expect(m.toGenerator().icon, isA<IconData>());
    });
  });

  group('UserManifest.toJson / fromJson', () {
    test('round-trips through JSON', () {
      final original = _sample(notesEnabled: true);
      final restored = UserManifest.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.iconKey, original.iconKey);
      expect(restored.notesEnabled, original.notesEnabled);
      expect(restored.promptSystem, original.promptSystem);
      expect(restored.maxItems, original.maxItems);
    });

    test('tolerates missing fields', () {
      final restored = UserManifest.fromJson(<String, Object?>{
        'id': 'x',
        'title': 'X',
      });
      expect(restored.id, 'x');
      expect(restored.title, 'X');
      expect(restored.maxItems, 10);
      expect(restored.iconKey, 'auto_awesome');
    });
  });

  group('blankUserManifest', () {
    test('has reasonable defaults', () {
      final blank = blankUserManifest();
      expect(blank.title, isEmpty);
      expect(blank.maxItems, 8);
      expect(blank.promptSystem, isNotEmpty);
      expect(blank.promptUser, contains('{intent}'));
    });
  });

  group('UserManifestStore (SharedPreferences-backed)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load on a fresh store returns empty', () async {
      final store = UserManifestStore();
      expect(await store.load(), isEmpty);
    });

    test('save then load', () async {
      final store = UserManifestStore();
      await store.save(_sample(title: 'A'));
      final list = await store.load();
      expect(list, hasLength(1));
      expect(list.first.title, 'A');
    });

    test('save updates existing entry by id', () async {
      final store = UserManifestStore();
      await store.save(_sample(title: 'A'));
      await store.save(_sample(title: 'A2'));
      final list = await store.load();
      expect(list, hasLength(1));
      expect(list.first.title, 'A2');
    });

    test('delete removes entry by id', () async {
      final store = UserManifestStore();
      await store.save(_sample(title: 'A'));
      await store.delete('abc-123');
      expect(await store.load(), isEmpty);
    });

    test('changes stream emits on save and delete', () async {
      final store = UserManifestStore();
      final emissions = <int>[];
      final sub = store.changes.listen((list) => emissions.add(list.length));
      // Wait for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.save(_sample(title: 'A'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.delete('abc-123');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      // First emission is the empty initial load, then save (1), delete (0).
      expect(emissions, [0, 1, 0]);
      store.dispose();
    });
  });

  group('CompositeGeneratorRegistry', () {
    test('combines builtins and user-authored sources, dedupes by id', () {
      const a = GeneratorManifest(
        id: 'a',
        title: 'A',
        description: '',
        icon: Icons.add,
        status: GeneratorStatus.available,
      );
      const b = GeneratorManifest(
        id: 'b',
        title: 'B',
        description: '',
        icon: Icons.add,
        status: GeneratorStatus.available,
      );
      const aDupe = GeneratorManifest(
        id: 'a',
        title: 'A-dupe',
        description: '',
        icon: Icons.add,
        status: GeneratorStatus.available,
      );
      final registry = CompositeGeneratorRegistry([
        BuiltinGeneratorRegistry([a]),
        UserGeneratorRegistry([b, aDupe]),
      ]);
      final ids = registry.list().map((m) => m.id).toList();
      // `a` only appears once; first source wins.
      expect(ids, ['a', 'b']);
    });
  });
}
