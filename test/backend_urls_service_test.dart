import 'package:flutter_test/flutter_test.dart';
import 'package:noetica/services/api_config.dart';
import 'package:noetica/services/backend_urls_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds default endpoint on first launch', () async {
    final svc = BackendUrlsService();
    final state = await svc.load();

    expect(state.endpoints, hasLength(1));
    expect(state.endpoints.first.url, kDefaultBackendUrl);
    expect(state.activeId, state.endpoints.first.id);
    expect(state.activeUrl, kDefaultBackendUrl);
  });

  test('add appends a new endpoint and may switch active', () async {
    final svc = BackendUrlsService();
    await svc.load();

    final ep = await svc.add(
      name: 'Localhost',
      url: 'http://localhost:8080',
      makeActive: true,
    );

    final state = await svc.load();
    expect(state.endpoints, hasLength(2));
    expect(state.activeId, ep.id);
    expect(state.activeUrl, 'http://localhost:8080');
  });

  test('add normalises trailing slashes', () async {
    final svc = BackendUrlsService();
    await svc.load();

    final ep = await svc.add(
      name: 'Trailing',
      url: 'https://example.com/api///',
    );

    expect(ep.url, 'https://example.com/api');
  });

  test('add throws on empty url', () async {
    final svc = BackendUrlsService();
    await svc.load();

    expect(
      () => svc.add(name: 'bad', url: '   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('setActive flips the active flag', () async {
    final svc = BackendUrlsService();
    await svc.load();
    final extra = await svc.add(name: 'Backup', url: 'https://b.example.com');

    await svc.setActive(extra.id);

    final state = await svc.load();
    expect(state.activeId, extra.id);
    expect(state.activeUrl, 'https://b.example.com');
  });

  test('remove rejects last endpoint, succeeds otherwise', () async {
    final svc = BackendUrlsService();
    final initial = await svc.load();

    expect(
      () => svc.remove(initial.endpoints.first.id),
      throwsA(isA<StateError>()),
    );

    final extra = await svc.add(name: 'Extra', url: 'https://x.example.com');
    await svc.remove(initial.endpoints.first.id);

    final state = await svc.load();
    expect(state.endpoints, hasLength(1));
    expect(state.endpoints.single.id, extra.id);
    expect(state.activeId, extra.id);
  });

  test('changes stream re-emits on add / setActive / remove', () async {
    final svc = BackendUrlsService();
    final received = <BackendUrlsState>[];
    final sub = svc.changes.listen(received.add);
    // Allow the seeded "load" snapshot to flush.
    await Future<void>.delayed(Duration.zero);

    final extra = await svc.add(name: 'B', url: 'https://b.example.com');
    await svc.setActive(extra.id);
    await Future<void>.delayed(Duration.zero);

    expect(received.length, greaterThanOrEqualTo(2));
    expect(received.last.activeId, extra.id);

    await sub.cancel();
    await svc.dispose();
  });

  test('persists across instances via SharedPreferences', () async {
    final a = BackendUrlsService();
    await a.load();
    final extra = await a.add(name: 'Extra', url: 'https://e.example.com');
    await a.setActive(extra.id);

    final b = BackendUrlsService();
    final state = await b.load();

    expect(state.endpoints, hasLength(2));
    expect(state.activeId, extra.id);
    expect(state.activeUrl, 'https://e.example.com');
  });
}
