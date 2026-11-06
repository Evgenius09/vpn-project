import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/app/home_screen.dart';
import 'package:vpnclient/features/auth/presentation/login_screen.dart';
import 'package:vpnclient/app/app.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/api/fallback_api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/features/profile/domain/profile_state.dart';
import 'package:vpnclient/gen/api/export.dart';

String _fixtureJson() =>
    File('../contracts/fixtures/profile/seed.json').readAsStringSync();

ProfileV1 _seedProfile() =>
    ProfileV1.fromJson(jsonDecode(_fixtureJson()) as Map<String, Object?>);

FakeApiClient _api() => FakeApiClient(load: () async => _fixtureJson());

void main() {
  group('ProfileRepository', () {
    late FakeApiClient api;
    late MemoryProfileCache cache;
    late ProfileRepository repository;

    setUp(() {
      api = _api();
      cache = MemoryProfileCache();
      repository = ProfileRepository(api, cache, ApiEndpoints(const []));
    });

    test('loads the seed profile and caches it with its ETag', () async {
      final loaded = await repository.load();

      expect(loaded.profile.servers, hasLength(5));
      expect(loaded.fromCache, isFalse);
      expect(cache.value!.etag, '"fake"');
    });

    test('a 304 returns the cached profile', () async {
      await repository.load();
      final loaded = await repository.load();

      expect(api.fetches, 2);
      expect(loaded.profile.servers, hasLength(5));
      expect(loaded.fromCache, isFalse, reason: 'the server confirmed it');
    });

    test('a server failure falls back to the cache', () async {
      await repository.load();
      api.failure = const ApiUnavailable();

      final loaded = await repository.load();

      expect(loaded.fromCache, isTrue);
      expect(loaded.profile.servers, hasLength(5));
    });

    test('a server failure without a cache fails', () async {
      api.failure = const ApiUnavailable();
      await expectLater(repository.load(), throwsA(isA<ApiUnavailable>()));
    });

    test('unauthorized clears the cache, because it holds secrets', () async {
      await repository.load();
      api.failure = const ApiProblem(401, ProblemCode.deviceRevoked);

      await expectLater(repository.load(), throwsA(isA<ApiProblem>()));
      expect(cache.value, isNull);
    });

    group('API addresses (tech.md 35.1)', () {
      const built = 'https://built.example';

      test('the cached addresses lead the first request', () async {
        final endpoints = ApiEndpoints(const [built]);
        cache.value = CachedProfile(_seedProfile(), '"old"');
        List<String>? seen;
        final repository = ProfileRepository(
          FakeApiClient(
            load: () async {
              seen = endpoints.ordered;
              return _fixtureJson();
            },
          ),
          cache,
          endpoints,
        );

        await repository.load();

        expect(seen, ['http://localhost:8080', built]);
      });

      test('a fetched profile teaches its addresses', () async {
        final endpoints = ApiEndpoints(const [built]);

        await ProfileRepository(api, cache, endpoints).load();

        expect(endpoints.ordered, ['http://localhost:8080', built]);
      });
    });

    test('a validation problem keeps the cache', () async {
      await repository.load();
      api.failure = const ApiProblem(400, ProblemCode.validationFailed);

      await expectLater(repository.load(), throwsA(isA<ApiProblem>()));
      expect(cache.value, isNotNull);
    });
  });

  group('FileProfileCache', () {
    late Directory directory;
    late FileProfileCache cache;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('profile');
      cache = FileProfileCache(() async => directory);
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('survives a restart', () async {
      await cache.write(CachedProfile(_seedProfile(), '"tag"'));

      final read = await FileProfileCache(() async => directory).read();

      expect(read!.etag, '"tag"');
      expect(read.profile.servers, hasLength(5));
    });

    test('a damaged file reads as empty', () async {
      File('${directory.path}/profile.json').writeAsStringSync('{broken');
      expect(await cache.read(), isNull);
    });

    test('clear removes the file', () async {
      await cache.write(CachedProfile(_seedProfile(), null));
      await cache.clear();
      expect(await cache.read(), isNull);
      await cache.clear();
    });
  });

  group('ProfileController', () {
    ProviderContainer container(FakeApiClient api, MemoryProfileCache cache) {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          profileCacheProvider.overrideWithValue(cache),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
          initialTokenProvider.overrideWithValue('t'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(profileControllerProvider, (_, _) {});
      return container;
    }

    test('moves from loading to ready', () async {
      final c = container(_api(), MemoryProfileCache());
      expect(c.read(profileControllerProvider), isA<ProfileLoading>());
      await pumpEventQueue();
      expect(c.read(profileControllerProvider), isA<ProfileReady>());
    });

    test('reports the cache after a server failure', () async {
      final api = _api();
      final cache = MemoryProfileCache()
        ..value = CachedProfile(_seedProfile(), '"old"');
      api.failure = const ApiUnavailable();

      final c = container(api, cache);
      await pumpEventQueue();

      final state = c.read(profileControllerProvider);
      expect((state as ProfileReady).fromCache, isTrue);
    });

    test('fails without a cache', () async {
      final api = _api()..failure = const ApiUnavailable();
      final c = container(api, MemoryProfileCache());
      await pumpEventQueue();
      expect(c.read(profileControllerProvider), isA<ProfileFailed>());
    });

    test('retry succeeds once the server recovers', () async {
      final api = _api()..failure = const ApiUnavailable();
      final c = container(api, MemoryProfileCache());
      await pumpEventQueue();

      api.failure = null;
      await c.read(profileControllerProvider.notifier).load();

      expect(c.read(profileControllerProvider), isA<ProfileReady>());
    });

    test('a 401 signs the device out', () async {
      final api = _api()
        ..failure = const ApiProblem(401, ProblemCode.unauthorized);
      final c = container(api, MemoryProfileCache());
      await pumpEventQueue();
      expect(c.read(sessionProvider), isFalse);
    });

    test('provisioning polls after Retry-After', () async {
      final api = _api()
        ..scripted = ProfileFetch(
          profile: _seedProfile(),
          etag: '"p"',
          retryAfterSec: 0,
        );
      container(api, MemoryProfileCache());
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await pumpEventQueue();
      expect(api.fetches, greaterThan(1));
      api.scripted = ProfileFetch(profile: _seedProfile(), etag: '"p"');
    });
  });

  testWidgets('a 401 on the profile returns to the login screen', (
    tester,
  ) async {
    final api = _api()
      ..failure = const ApiProblem(401, ProblemCode.deviceRevoked);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          profileCacheProvider.overrideWithValue(MemoryProfileCache()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
          initialTokenProvider.overrideWithValue('t'),
        ],
        child: const VpnClientApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
