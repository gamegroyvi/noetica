import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/builtin_generators.dart';
import 'package:noetica/services/generator_manifest.dart';

void main() {
  group('GeneratorManifest', () {
    test('isInteractable is true for available and beta', () {
      const a = GeneratorManifest(
        id: 'a',
        title: 't',
        description: 'd',
        icon: Icons.star,
        status: GeneratorStatus.available,
      );
      const b = GeneratorManifest(
        id: 'b',
        title: 't',
        description: 'd',
        icon: Icons.star,
        status: GeneratorStatus.beta,
      );
      const c = GeneratorManifest(
        id: 'c',
        title: 't',
        description: 'd',
        icon: Icons.star,
        status: GeneratorStatus.soon,
      );
      expect(a.isInteractable, isTrue);
      expect(b.isInteractable, isTrue);
      expect(c.isInteractable, isFalse);
    });

    test('default source is builtin', () {
      const m = GeneratorManifest(
        id: 'a',
        title: 't',
        description: 'd',
        icon: Icons.star,
        status: GeneratorStatus.soon,
      );
      expect(m.source, GeneratorSource.builtin);
    });
  });

  group('BuiltinGeneratorRegistry', () {
    test('list returns an unmodifiable view', () {
      final reg = BuiltinGeneratorRegistry(const [
        GeneratorManifest(
          id: 'a',
          title: 't',
          description: 'd',
          icon: Icons.star,
          status: GeneratorStatus.available,
        ),
      ]);
      final out = reg.list();
      expect(() => out.add(out.first), throwsUnsupportedError);
    });

    test('available / beta / soon partition the list', () {
      final reg = BuiltinGeneratorRegistry(const [
        GeneratorManifest(
          id: 'a',
          title: 't',
          description: 'd',
          icon: Icons.star,
          status: GeneratorStatus.available,
        ),
        GeneratorManifest(
          id: 'b',
          title: 't',
          description: 'd',
          icon: Icons.star,
          status: GeneratorStatus.beta,
        ),
        GeneratorManifest(
          id: 'c',
          title: 't',
          description: 'd',
          icon: Icons.star,
          status: GeneratorStatus.soon,
        ),
      ]);
      expect(reg.available.map((e) => e.id), ['a']);
      expect(reg.beta.map((e) => e.id), ['b']);
      expect(reg.soon.map((e) => e.id), ['c']);
    });

    test('findById returns the matching manifest or null', () {
      final reg = BuiltinGeneratorRegistry(const [
        GeneratorManifest(
          id: 'menu-week',
          title: 't',
          description: 'd',
          icon: Icons.star,
          status: GeneratorStatus.available,
        ),
      ]);
      expect(reg.findById('menu-week')?.id, 'menu-week');
      expect(reg.findById('missing'), isNull);
    });
  });

  group('defaultBuiltinManifests', () {
    test('exposes menu-week as available with a builder', () {
      final manifests = defaultBuiltinManifests();
      final menu = manifests.firstWhere((m) => m.id == 'menu-week');
      expect(menu.status, GeneratorStatus.available);
      expect(menu.builder, isNotNull);
      expect(menu.bullets, isNotEmpty);
    });

    test('all ids are unique', () {
      final ids = defaultBuiltinManifests().map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('contains at least one "soon" placeholder', () {
      final manifests = defaultBuiltinManifests();
      expect(
        manifests.any((m) => m.status == GeneratorStatus.soon),
        isTrue,
      );
    });
  });
}
