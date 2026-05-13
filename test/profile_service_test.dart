import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:noetica/data/db.dart';
import 'package:noetica/data/profile.dart';

Future<NoeticaDb> _openTestDb() async {
  final raw = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: NoeticaDb.currentSchemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        // Minimal schema — only the profile table is needed.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS profile (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    ),
  );
  return NoeticaDb.test(raw);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ProfileService', () {
    test('save then load returns the same profile', () async {
      final db = await _openTestDb();
      final svc = ProfileService(db);

      final profile = UserProfile(
        name: 'Test User',
        aspiration: 'become great',
        interests: const ['coding', 'reading'],
        interestLevels: const {'coding': 'expert'},
        painPoint: '',
        weeklyHours: 10,
        updatedAt: DateTime.utc(2025, 1, 1),
        currentEpoch: 2,
        epochTier: 3,
      );

      await svc.save(profile);
      final loaded = await svc.load();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Test User');
      expect(loaded.aspiration, 'become great');
      expect(loaded.interests, ['coding', 'reading']);
      expect(loaded.interestLevels['coding'], 'expert');
      expect(loaded.weeklyHours, 10);
      expect(loaded.currentEpoch, 2);
      expect(loaded.epochTier, 3);

      await db.close();
    });

    test('load returns null when no profile saved', () async {
      final db = await _openTestDb();
      final svc = ProfileService(db);

      final loaded = await svc.load();
      expect(loaded, isNull);

      await db.close();
    });

    test('clear removes profile', () async {
      final db = await _openTestDb();
      final svc = ProfileService(db);

      await svc.save(UserProfile(
        name: 'To Delete',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 0,
        updatedAt: DateTime.utc(2025, 1, 1),
      ));
      expect(await svc.load(), isNotNull);

      await svc.clear();
      expect(await svc.load(), isNull);

      await db.close();
    });

    test('save overwrites previous profile', () async {
      final db = await _openTestDb();
      final svc = ProfileService(db);

      await svc.save(UserProfile(
        name: 'First',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 5,
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      await svc.save(UserProfile(
        name: 'Second',
        aspiration: '',
        interests: const [],
        interestLevels: const {},
        painPoint: '',
        weeklyHours: 20,
        updatedAt: DateTime.utc(2025, 2, 1),
      ));

      final loaded = await svc.load();
      expect(loaded!.name, 'Second');
      expect(loaded.weeklyHours, 20);

      await db.close();
    });
  });
}
