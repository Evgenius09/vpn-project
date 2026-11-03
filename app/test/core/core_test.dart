import 'dart:convert';
import 'dart:io' show File;

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

/// Answers one scripted response and keeps the request it saw.
class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter(this.status, this.body);

  final int status;
  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

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

    test('only dev may fake the tunnel', () {
      for (final flavor in ['staging', 'prod']) {
        final env = jsonDecode(
          File('env/$flavor.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(env['FAKE_VPN'], isFalse);
        expect(env['FAKE_API'], isFalse);
      }
    });

    test('no flavor carries a token, because login issues it', () {
      for (final flavor in ['dev', 'staging', 'prod']) {
        final env = File('env/$flavor.json').readAsStringSync();
        expect(env, isNot(contains('DEV_TOKEN')), reason: flavor);
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

  group('HttpApiClient auth', () {
    late _AuthAdapter adapter;

    HttpApiClient clientWith(int status, String body) {
      adapter = _AuthAdapter(status, body);
      return HttpApiClient(
        createGeneratedClient(
          baseUrl: 'https://api.example.invalid',
          tokens: MemoryTokenStore('t'),
          adapter: adapter,
        ),
      );
    }

    const start = TelegramLoginStart(
      username: 'seed_user',
      installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
      model: 'Pixel 7',
    );
    const verify = TelegramLoginVerify(
      loginId: '1f0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
      code: '123456',
      installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
      platform: Platform.android,
      model: 'Pixel 7',
      appVersion: '0.1.0',
    );

    TypeMatcher<ApiProblem> problem(ProblemCode code, int status) =>
        isA<ApiProblem>()
            .having((p) => p.code, 'code', code)
            .having((p) => p.status, 'status', status);

    test('start sends the username, install, and model', () async {
      final client = clientWith(
        200,
        '{"loginId":"1f0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f",'
        '"expiresAt":"2026-11-03T10:05:00Z","resendAfterSec":60,'
        '"botUrl":"https://t.me/vpnclient_bot"}',
      );

      final challenge = await client.startTelegramLogin(start);

      expect(adapter.request!.path, '/v1/auth/telegram/start');
      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.data, {
        'username': 'seed_user',
        'installId': '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
        'model': 'Pixel 7',
      });
      expect(challenge.resendAfterSec, 60);
      expect(challenge.botUrl, 'https://t.me/vpnclient_bot');
    });

    test('an unknown user carries the bot link', () async {
      final client = clientWith(
        404,
        '{"title":"t","status":404,"code":"telegram_user_not_found",'
        '"botUrl":"https://t.me/vpnclient_bot"}',
      );
      await expectLater(
        client.startTelegramLogin(start),
        throwsA(
          problem(
            ProblemCode.telegramUserNotFound,
            404,
          ).having((p) => p.botUrl, 'botUrl', 'https://t.me/vpnclient_bot'),
        ),
      );
    });

    test('a rate limit carries the wait', () async {
      final client = clientWith(
        429,
        '{"title":"t","status":429,"code":"rate_limited","retryAfterSec":42}',
      );
      await expectLater(
        client.startTelegramLogin(start),
        throwsA(
          problem(
            ProblemCode.rateLimited,
            429,
          ).having((p) => p.retryAfterSec, 'retryAfterSec', 42),
        ),
      );
    });

    test('verify returns the token', () async {
      final client = clientWith(
        200,
        '{"deviceId":"2f0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f",'
        '"accountId":"3f0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f","token":"tok"}',
      );

      final result = await client.verifyTelegramLogin(verify);

      expect(adapter.request!.path, '/v1/auth/telegram/verify');
      expect(
        (adapter.request!.data as Map<String, Object?>)['platform'],
        'android',
      );
      expect(result.token, 'tok');
    });

    test('a wrong code carries the attempts left', () async {
      final client = clientWith(
        400,
        '{"title":"t","status":400,"code":"code_invalid","attemptsLeft":3}',
      );
      await expectLater(
        client.verifyTelegramLogin(verify),
        throwsA(
          problem(
            ProblemCode.codeInvalid,
            400,
          ).having((p) => p.attemptsLeft, 'attemptsLeft', 3),
        ),
      );
    });

    test('an expired code is a problem, not an outage', () async {
      final client = clientWith(
        410,
        '{"title":"t","status":410,"code":"code_expired"}',
      );
      await expectLater(
        client.verifyTelegramLogin(verify),
        throwsA(problem(ProblemCode.codeExpired, 410)),
      );
    });

    test('logout accepts 204', () async {
      final client = clientWith(204, '');
      await client.logout();
      expect(adapter.request!.path, '/v1/auth/logout');
      expect(adapter.request!.headers['Authorization'], 'Bearer t');
    });

    test('a server failure during login is unavailable', () async {
      await expectLater(
        clientWith(502, '').startTelegramLogin(start),
        throwsA(isA<ApiUnavailable>()),
      );
    });
  });

  group('FakeApiClient auth', () {
    const start = TelegramLoginStart(
      username: 'anyone',
      installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
      model: 'm',
    );

    test('answers start and verify for any input', () async {
      final api = FakeApiClient(load: () async => '{}');
      final challenge = await api.startTelegramLogin(start);
      final result = await api.verifyTelegramLogin(
        TelegramLoginVerify(
          loginId: challenge.loginId,
          code: '000000',
          installId: start.installId,
          platform: Platform.windows,
          model: 'm',
          appVersion: '0.1.0',
        ),
      );
      await api.logout();

      expect(challenge.resendAfterSec, greaterThan(0));
      expect(result.token, isNotEmpty);
      expect(api.starts.single.username, 'anyone');
      expect(api.verifies.single.code, '000000');
      expect(api.logouts, 1);
    });

    test('fails with the scripted problem', () async {
      final api = FakeApiClient(load: () async => '{}')
        ..authFailure = const ApiProblem(404, ProblemCode.telegramUserNotFound);
      await expectLater(
        api.startTelegramLogin(start),
        throwsA(isA<ApiProblem>()),
      );
      expect(api.starts, hasLength(1));
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

    test('records forgetLastRequest', () async {
      await bridge.forgetLastRequest();
      expect(bridge.calls, ['forgetLastRequest']);
    });

    test('syncRuleSets reports each set as ready', () async {
      final ready = await bridge.syncRuleSets([
        const RuleSetRef(id: 'ru-direct', url: 'u', sha256: 's'),
      ]);
      expect(ready, ['ru-direct']);
    });
  });
}
