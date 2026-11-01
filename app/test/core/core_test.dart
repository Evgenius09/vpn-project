import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/config/app_config.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/fake_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final profile = File('../contracts/fixtures/profile/trial.json')
        .readAsStringSync();
    return ResponseBody.fromString(
      profile,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.status, this.body, this.etag);

  final int status;
  final String body;
  final String? etag;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      'etag': ?etag == null ? null : [etag!],
    },
  );

  @override
  void close({bool force = false}) {}
}

String _tunnelRequest() =>
    File('../contracts/fixtures/tunnel_request/android_regular.json')
        .readAsStringSync();

void main() {
  group('AppConfig', () {
    test('splits the URL list', () {
      expect(AppConfig.parseUrls('https://a, https://b ,'), [
        'https://a',
        'https://b',
      ]);
      expect(AppConfig.parseUrls(''), isEmpty);
    });
  });

  group('env files', () {
    test('every flavor sets every key', () {
      for (final flavor in ['dev', 'staging', 'prod']) {
        final env = jsonDecode(
          File('env/$flavor.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(env['FLAVOR'], flavor);
        expect(
          env.keys,
          containsAll(['API_BASE_URLS', 'FAKE_VPN', 'FAKE_API']),
        );
      }
    });

    test('only dev may fake the tunnel or carry a token', () {
      for (final flavor in ['staging', 'prod']) {
        final env = jsonDecode(
          File('env/$flavor.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(env['FAKE_VPN'], isFalse);
        expect(env['FAKE_API'], isFalse);
        expect(env.containsKey('DEV_TOKEN'), isFalse);
      }
    });
  });

  group('MemoryTokenStore', () {
    test('stores and deletes', () async {
      final store = MemoryTokenStore();
      expect(await store.read(), isNull);
      await store.write('t');
      expect(await store.read(), 't');
      await store.delete();
      expect(await store.read(), isNull);
    });
  });

  group('API client', () {
    test('sends the token and parses the profile', () async {
      final adapter = _RecordingAdapter();
      final client = createGeneratedClient(
        baseUrl: 'https://api.example.invalid',
        tokens: MemoryTokenStore('secret'),
        adapter: adapter,
      );

      final response = await client.profile.getProfile();

      expect(adapter.request!.headers['Authorization'], 'Bearer secret');
      expect(adapter.request!.path, '/v1/profile');
      expect(response.data.account.status, AccountStatus.trial);
      expect(response.data.servers, hasLength(3));
    });

    test('sends no header without a token', () async {
      final adapter = _RecordingAdapter();
      final client = createGeneratedClient(
        baseUrl: 'https://api.example.invalid',
        tokens: MemoryTokenStore(),
        adapter: adapter,
      );
      await client.profile.getProfile();
      expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('HttpApiClient', () {
    HttpApiClient clientWith(int status, String body, [String? etag]) {
      final adapter = _ScriptedAdapter(status, body, etag);
      return HttpApiClient(
        createGeneratedClient(
          baseUrl: 'https://api.example.invalid',
          tokens: MemoryTokenStore('t'),
          adapter: adapter,
        ),
      );
    }

    final trial = File('../contracts/fixtures/profile/trial.json')
        .readAsStringSync();

    test('reads the ETag', () async {
      final fetch = await clientWith(200, trial, '"abc"').fetchProfile();
      expect(fetch.etag, '"abc"');
      expect(fetch.profile, isNotNull);
    });

    test('a 304 has no profile', () async {
      final fetch = await clientWith(304, '').fetchProfile(etag: '"abc"');
      expect(fetch.profile, isNull);
    });

    test('a problem keeps its code', () async {
      final client = clientWith(
        401,
        '{"title":"t","status":401,"code":"device_revoked"}',
      );
      await expectLater(
        client.fetchProfile(),
        throwsA(
          isA<ApiProblem>().having(
            (problem) => problem.isUnauthorized,
            'isUnauthorized',
            isTrue,
          ),
        ),
      );
    });

    test('a 5xx counts as unavailable', () async {
      await expectLater(
        clientWith(503, '').fetchProfile(),
        throwsA(isA<ApiUnavailable>()),
      );
    });
  });

  group('FakeVpnBridge', () {
    late FakeVpnBridge bridge;

    setUp(() => bridge = FakeVpnBridge());
    tearDown(() => bridge.dispose());

    Future<List<TunnelStatus>> statuses(Future<void> Function() action) async {
      final seen = <TunnelStatus>[];
      final subscription = bridge.events.listen((event) {
        final state = event.state;
        if (state != null) {
          seen.add(state.status);
        }
      });
      await action();
      await pumpEventQueue();
      await subscription.cancel();
      return seen;
    }

    test('start reports connecting then connected', () async {
      final seen = await statuses(() => bridge.start(_tunnelRequest()));
      expect(seen, [TunnelStatus.connecting, TunnelStatus.connected]);
    });

    test('stop reports disconnecting then disconnected', () async {
      await bridge.start(_tunnelRequest());
      final seen = await statuses(bridge.stop);
      expect(seen, [TunnelStatus.disconnecting, TunnelStatus.disconnected]);
    });

    test('rejects a malformed request', () async {
      await expectLater(bridge.start('{}'), throwsA(anything));
      await expectLater(bridge.start('not json'), throwsA(anything));
    });

    test('failNext reports the core error once', () async {
      bridge.failNext(CoreErrorCode.startFailed);
      await expectLater(
        bridge.start(_tunnelRequest()),
        throwsA(
          isA<VpnBridgeException>().having(
            (error) => error.code,
            'code',
            CoreErrorCode.startFailed,
          ),
        ),
      );
      await expectLater(bridge.start(_tunnelRequest()), completes);
    });

    test('records calls in order', () async {
      await bridge.prepare();
      await bridge.start(_tunnelRequest());
      await bridge.selectServer(TunnelMode.regular, 'id');
      await bridge.stop();
      expect(bridge.calls, ['prepare', 'start', 'selectServer', 'stop']);
    });

    test('urlTest answers for each server', () async {
      final event = await bridge.urlTest(['a', 'b']);
      expect(event.type, CoreEventType.urlTest);
      expect(event.urlTest!.results.map((r) => r.serverId), ['a', 'b']);
    });

    test('setUserMode changes the reported mode', () async {
      await bridge.setUserMode(TunnelMode.whitelist);
      final event = await bridge.getState();
      expect(event.state!.userMode, TunnelMode.whitelist);
      expect(event.state!.effectiveMode, TunnelMode.whitelist);
    });

    test('syncRuleSets reports each set as ready', () async {
      final ready = await bridge.syncRuleSets([
        const RuleSetRef(id: 'ru-direct', url: 'u', sha256: 's'),
      ]);
      expect(ready, ['ru-direct']);
    });
  });
}
