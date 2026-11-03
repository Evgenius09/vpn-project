import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/api/fallback_api_client.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/gen/api/export.dart';

// tech.md 35.1: the app tries the API addresses in order, a server's answer
// ends the search, and a request that may have reached a server is never
// sent again unless repeating it is harmless.

const _primary = 'https://api.example';
const _fallback = 'https://api2.example';

/// How one address behaves.
enum _Host { ok, down, broken, refuses, rejects }

/// Answers like the server at each address, or fails like the network.
class _Network implements HttpClientAdapter {
  _Network(this.hosts);

  final Map<String, _Host> hosts;
  final hits = <String>[];
  final timeouts = <Duration?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final base = options.uri.origin;
    hits.add(base);
    timeouts
      ..add(options.connectTimeout)
      ..add(options.receiveTimeout);
    ResponseBody json(int status, String body) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    return switch (hosts[base]!) {
      _Host.ok => json(
        200,
        File('../contracts/fixtures/profile/seed.json').readAsStringSync(),
      ),
      _Host.down => throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      ),
      _Host.refuses => throw DioException.connectionTimeout(
        requestOptions: options,
        timeout: apiAttemptTimeout,
      ),
      _Host.broken => json(502, '{}'),
      _Host.rejects => json(401, '{"code":"unauthorized"}'),
    };
  }

  @override
  void close({bool force = false}) {}
}

FallbackApiClient _client(_Network network, ApiEndpoints endpoints) =>
    FallbackApiClient(
      endpoints,
      (baseUrl) => HttpApiClient(
        createGeneratedClient(
          baseUrl: baseUrl,
          tokens: MemoryTokenStore('t'),
          adapter: network,
        ),
      ),
    );

FallbackApiClient _over(Map<String, _Host> hosts, _Network network) =>
    _client(network, ApiEndpoints(hosts.keys.toList()));

const _start = TelegramLoginStart(
  username: 'seed_user',
  installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
  model: 'Pixel 8',
);

void main() {
  group('ApiEndpoints', () {
    test('profile addresses first, then the build, without repeats', () {
      final endpoints = ApiEndpoints([_primary, 'https://built.example'])
        ..learn([_fallback, _primary]);

      expect(endpoints.ordered, [_fallback, _primary, 'https://built.example']);
    });

    test('a newer profile replaces the learned addresses', () {
      final endpoints = ApiEndpoints([_primary])
        ..learn([_fallback])
        ..learn(['https://api3.example']);

      expect(endpoints.ordered, ['https://api3.example', _primary]);
    });
  });

  group('the profile', () {
    for (final failure in [_Host.down, _Host.refuses, _Host.broken]) {
      test('moves on when the primary is ${failure.name}', () async {
        final hosts = {_primary: failure, _fallback: _Host.ok};
        final network = _Network(hosts);

        final fetch = await _over(hosts, network).fetchProfile();

        expect(fetch.profile, isNotNull);
        expect(network.hits, [_primary, _fallback]);
      });
    }

    test('stops at a server that answers with a problem', () async {
      final hosts = {_primary: _Host.rejects, _fallback: _Host.ok};
      final network = _Network(hosts);

      await expectLater(
        _over(hosts, network).fetchProfile(),
        throwsA(isA<ApiProblem>()),
      );
      expect(network.hits, [_primary]);
    });

    test('all addresses down is unavailable', () async {
      final hosts = {_primary: _Host.down, _fallback: _Host.broken};
      final network = _Network(hosts);

      await expectLater(
        _over(hosts, network).fetchProfile(),
        throwsA(isA<ApiUnavailable>()),
      );
      expect(network.hits, [_primary, _fallback]);
    });

    test('no address at all is unavailable', () async {
      await expectLater(
        _client(_Network({}), ApiEndpoints(const [])).fetchProfile(),
        throwsA(isA<ApiUnavailable>()),
      );
    });

    test('each address waits 9 s to connect and 9 s for the answer', () async {
      final hosts = {_primary: _Host.ok};
      final network = _Network(hosts);

      await _over(hosts, network).fetchProfile();

      expect(network.timeouts, [
        const Duration(seconds: 9),
        const Duration(seconds: 9),
      ]);
    });
  });

  group('login and logout', () {
    final calls = <String, Future<Object?> Function(ApiClient)>{
      'start': (client) => client.startTelegramLogin(_start),
      'verify': (client) => client.verifyTelegramLogin(
        const TelegramLoginVerify(
          loginId: '0d5f8a2e-3c1b-4e7a-9f6d-2b8c4a1e5d3f',
          code: '123456',
          installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
          platform: Platform.android,
          model: 'Pixel 8',
          appVersion: '0.1.0',
        ),
      ),
      'logout': (client) => client.logout(),
    };
    for (final MapEntry(key: name, value: call) in calls.entries) {
      test('$name moves on when the request never left', () async {
        for (final failure in [_Host.down, _Host.refuses]) {
          final hosts = {_primary: failure, _fallback: _Host.rejects};
          final network = _Network(hosts);

          await expectLater(
            call(_over(hosts, network)),
            throwsA(isA<ApiProblem>()),
            reason: 'the fallback answered',
          );
          expect(network.hits, [_primary, _fallback], reason: failure.name);
        }
      });

      test('$name is not sent twice after a server error', () async {
        final hosts = {_primary: _Host.broken, _fallback: _Host.ok};
        final network = _Network(hosts);

        await expectLater(
          call(_over(hosts, network)),
          throwsA(isA<ApiUnavailable>()),
        );
        expect(network.hits, [_primary]);
      });
    }
  });

  test('a lost connection marks the request as possibly sent', () async {
    final error = DioException.receiveTimeout(
      requestOptions: RequestOptions(),
      timeout: apiAttemptTimeout,
    );
    final network = _ThrowingNetwork(error);
    final client = HttpApiClient(
      createGeneratedClient(
        baseUrl: _primary,
        tokens: MemoryTokenStore('t'),
        adapter: network,
      ),
    );

    await expectLater(
      client.startTelegramLogin(_start),
      throwsA(
        isA<ApiUnavailable>().having((e) => e.requestSent, 'sent', isTrue),
      ),
    );
  });
}

class _ThrowingNetwork implements HttpClientAdapter {
  _ThrowingNetwork(this.error);

  final DioException error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;

  @override
  void close({bool force = false}) {}
}
