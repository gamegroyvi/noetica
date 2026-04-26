import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/data/profile.dart';

void main() {
  group('UserProfile epoch fields', () {
    test('round-trip preserves currentEpoch and timestamps', () {
      final started = DateTime.utc(2024, 5, 1, 12, 0);
      final acked = DateTime.utc(2024, 5, 1, 12, 1);
      final p = UserProfile(
        name: 'Ира',
        aspiration: 'стать кем-то получше',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 10,
        updatedAt: DateTime.utc(2024, 5, 1),
        currentEpoch: 3,
        epochStartedAt: started,
        epochAckedAt: acked,
      );
      final restored = UserProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(restored.currentEpoch, 3);
      expect(restored.epochStartedAt, started);
      expect(restored.epochAckedAt, acked);
    });

    test('old saves default to epoch 1 with null timestamps', () {
      final legacy = {
        'name': 'Ира',
        'aspiration': '',
        'interests': [],
        'interestLevels': {},
        'painPoint': '',
        'weeklyHours': 5,
        'updatedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
      };
      final p = UserProfile.fromJson(legacy);
      expect(p.currentEpoch, 1);
      expect(p.epochStartedAt, isNull);
      expect(p.epochAckedAt, isNull);
    });

    test('copyWith can clear epoch timestamps via flags', () {
      final p = UserProfile(
        name: '',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 0,
        updatedAt: DateTime(2024),
        currentEpoch: 2,
        epochStartedAt: DateTime(2024),
        epochAckedAt: DateTime(2024),
      );
      final cleared = p.copyWith(
        clearEpochAckedAt: true,
        clearEpochStartedAt: true,
      );
      expect(cleared.currentEpoch, 2);
      expect(cleared.epochAckedAt, isNull);
      expect(cleared.epochStartedAt, isNull);
    });

    test('round-trip preserves epochTier and epochRefreshedAt', () {
      final refreshed = DateTime.utc(2024, 6, 10, 9, 30);
      final p = UserProfile(
        name: 'Ира',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 0,
        updatedAt: DateTime.utc(2024, 6, 10),
        currentEpoch: 2,
        epochTier: 3,
        epochRefreshedAt: refreshed,
      );
      final restored = UserProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(restored.epochTier, 3);
      expect(restored.epochRefreshedAt, refreshed);
    });

    test('old saves default epochTier=1 and null epochRefreshedAt', () {
      final legacy = {
        'name': 'Ира',
        'aspiration': '',
        'interests': [],
        'interestLevels': {},
        'painPoint': '',
        'weeklyHours': 5,
        'updatedAt': DateTime.utc(2024, 1, 1).toIso8601String(),
      };
      final p = UserProfile.fromJson(legacy);
      expect(p.epochTier, 1);
      expect(p.epochRefreshedAt, isNull);
    });

    test('copyWith can clear epochRefreshedAt via flag', () {
      final p = UserProfile(
        name: '',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 0,
        updatedAt: DateTime(2024),
        epochRefreshedAt: DateTime(2024),
      );
      final cleared = p.copyWith(clearEpochRefreshedAt: true);
      expect(cleared.epochRefreshedAt, isNull);
    });
  });
}
