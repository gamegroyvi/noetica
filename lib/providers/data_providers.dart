import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/repository.dart';

final dbProvider = FutureProvider<NoeticaDb>((ref) async {
  final db = await NoeticaDb.open();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = FutureProvider<NoeticaRepository>((ref) async {
  final db = await ref.watch(dbProvider.future);
  return NoeticaRepository(db);
});

final axesProvider = StreamProvider<List<LifeAxis>>((ref) async* {
  final repo = await ref.watch(repositoryProvider.future);
  yield* repo.watchAxes();
});

final entriesProvider = StreamProvider<List<Entry>>((ref) async* {
  final repo = await ref.watch(repositoryProvider.future);
  yield* repo.watchEntries();
});
