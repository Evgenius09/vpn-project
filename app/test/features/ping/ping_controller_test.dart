import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/connection/application/connection_controller.dart';
import 'package:vpnclient/features/ping/application/ping_controller.dart';
import 'package:vpnclient/features/ping/data/tcp_ping.dart';
import 'package:vpnclient/features/ping/data/user_settings_store.dart';
import 'package:vpnclient/features/ping/domain/server_ping.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/features/profile/domain/profile_state.dart';
import 'package:vpnclient/gen/api/export.dart';

import 'ping_harness.dart';

const _frankfurt = '10000000-0000-4000-8000-000000000001';
const _amsterdam = '10000000-0000-4000-8000-000000000002';
const _helsinki = '10000000-0000-4000-8000-000000000003';
const _moscow = '10000000-0000-4000-8000-000000000004';
const _petersburg = '10000000-0000-4000-8000-000000000005';
const _all = [_frankfurt, _amsterdam, _helsinki, _moscow, _petersburg];
const _tcpServers = [_frankfurt, _amsterdam, _moscow, _petersburg];

Map<String, Object?> _seed() => jsonDecode(
  File('../contracts/fixtures/profile/seed.json').readAsStringSync(),
) as Map<String, Object?>;

/// The seed profile with [change] applied to its JSON.
String _profile([void Function(Map<String, Object?> json)? change]) {
  final json = _seed();
  change?.call(json);
  return jsonEncode(json);
}

Map<String, Object?> _policy(Map<String, Object?> json) =>
    json['policy']! as Map<String, Object?>;

Map<String, Object?> _defaults(Map<String, Object?> json) =>
    _policy(json)['defaults']! as Map<String, Object?>;

void _setPing(Map<String, Object?> json, String key, Object? value) {
  final ping = _defaults(json)['ping']! as Map<String, Object?>;
  if (value == null) {
    ping.remove(key);
  } else {
    ping[key] = value;
  }
}

class _App {
  _App({String? profile, TcpPing? tcp})
    : tcp = tcp ?? InstantTcpPing(),
      api = FakeApiClient(load: () async => profile ?? _profile());

  final FakeApiClient api;
  final TcpPing tcp;
  final bridge = UrlTestBridge();
  final settings = MemoryUserSettingsStore();
  late final ProviderContainer container;

  Future<void> start({bool watchPings = true}) async {
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
        initialTokenProvider.overrideWithValue('t'),
        vpnBridgeProvider.overrideWithValue(bridge),
        profileCacheProvider.overrideWithValue(MemoryProfileCache()),
        tcpPingProvider.overrideWithValue(tcp),
        userSettingsStoreProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(bridge.dispose);
    container.listen(connectionControllerProvider, (_, _) {});
    if (watchPings) {
      container.listen(pingControllerProvider, (_, _) {});
    }
    await _until(
      () => container.read(profileControllerProvider) is ProfileReady,
    );
    await pumpEventQueue();
  }

  PingState get state => container.read(pingControllerProvider);

  Map<String, ServerPing> get pings => state.pings;

  Future<void> run() => container.read(pingControllerProvider.notifier).run();

  Future<void> connect() async {
    bridge.emitStatus(TunnelStatus.connected);
    await pumpEventQueue();
    expect(
      container.read(connectionControllerProvider).tunnel.status,
      TunnelStatus.connected,
    );
  }
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await pumpEventQueue();
  }
  expect(done(), isTrue);
}

void main() {
  group('ping on open', () {
    test(
      'pings every server once with TCP when the profile is ready',
      () async {
        final tcp = InstantTcpPing();
        final app = _App(tcp: tcp);
        await app.start();

        expect(
          tcp.hosts,
          unorderedEquals([
            'de1.seed.invalid',
            'nl1.seed.invalid',
            'ru1.seed.invalid',
            'ru2.seed.invalid',
          ]),
        );
        for (final id in _tcpServers) {
          expect(app.pings[id], const ServerPing.delay(50), reason: id);
        }
        expect(app.state.running, isFalse);
      },
    );

    test(
      'a Hysteria2 server listens on UDP only, so TCP leaves it unknown',
      () async {
        final app = _App();
        await app.start();

        expect(app.pings[_helsinki], const ServerPing.unknown());
      },
    );

    test('ping.onOpen false waits for a refresh', () async {
      final tcp = InstantTcpPing();
      final app = _App(
        tcp: tcp,
        profile: _profile((json) => _setPing(json, 'onOpen', false)),
      );
      await app.start();

      expect(tcp.hosts, isEmpty);
      expect(app.pings, isEmpty);

      await app.run();
      expect(tcp.hosts, hasLength(4));
    });

    test(
      'a profile without servers yet pings once the servers arrive',
      () async {
        final tcp = InstantTcpPing();
        final app = _App(
          tcp: tcp,
          profile: _profile((json) => json['servers'] = <Object?>[]),
        );
        await app.start();
        expect(tcp.hosts, isEmpty);

        app.api.scripted = ProfileFetch(
          profile: ProfileV1.fromJson(_seed()),
          etag: '"with-servers"',
        );
        await app.container.read(profileControllerProvider.notifier).load();
        await pumpEventQueue();

        expect(tcp.hosts, hasLength(4));
        await app.container.read(profileControllerProvider.notifier).load();
        await pumpEventQueue();
        expect(
          tcp.hosts,
          hasLength(4),
          reason: 'on open runs once per app run',
        );
      },
    );

    test(
      'the timeout comes from the defaults, then from policy.ping',
      () async {
        final fromDefaults = InstantTcpPing();
        await _App(
          tcp: fromDefaults,
          profile: _profile((json) => _setPing(json, 'timeoutMs', 1200)),
        ).start();
        expect(fromDefaults.timeouts.toSet(), {
          const Duration(milliseconds: 1200),
        });

        final fromPolicy = InstantTcpPing();
        await _App(
          tcp: fromPolicy,
          profile: _profile((json) {
            _setPing(json, 'timeoutMs', null);
            (_policy(json)['ping']! as Map<String, Object?>)['timeoutMs'] = 700;
          }),
        ).start();
        expect(fromPolicy.timeouts.toSet(), {
          const Duration(milliseconds: 700),
        });
      },
    );
  });

  group('TCP ping', () {
    test(
      'never has more than 8 in flight and shows measuring meanwhile',
      () async {
        final servers = [
          for (var i = 0; i < 20; i++)
            {
              'id': 'srv-$i',
              'group': 'regular',
              'name': 'Server $i',
              'protocol': 'vless_reality',
              'address': 'h$i.example.com',
              'port': 443,
              'vless': {
                'uuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                'flow': 'xtls-rprx-vision',
                'serverName': 'www.example.com',
                'publicKey': 'jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0',
                'shortId': '0123',
                'fingerprint': 'chrome',
              },
              'sortWeight': i,
            },
        ];
        final tcp = GatedTcpPing({'h3.example.com': const ServerPing.delay(9)});
        final app = _App(
          tcp: tcp,
          profile: _profile((json) => json['servers'] = servers),
        );
        await app.start();

        expect(tcp.inFlight, 8);
        expect(app.state.running, isTrue);
        expect(app.pings['srv-19'], const ServerPing.measuring());

        tcp.release();
        await _until(() => !app.state.running);

        expect(tcp.peak, 8);
        expect(tcp.hosts, hasLength(20));
        expect(app.pings['srv-3'], const ServerPing.delay(9));
        expect(app.pings['srv-0'], const ServerPing.unreachable());
      },
    );

    test('a refresh while a ping runs is ignored', () async {
      final tcp = GatedTcpPing({});
      final app = _App(tcp: tcp);
      await app.start();
      expect(tcp.hosts, hasLength(4));

      final again = app.run();
      tcp.release();
      await again;
      await _until(() => !app.state.running);

      expect(tcp.hosts, hasLength(4));
    });
  });

  group('url_test', () {
    String urlTestProfile() =>
        _profile((json) => _setPing(json, 'type', 'url_test'));

    test('connected: one core call for every server, no TCP', () async {
      final tcp = InstantTcpPing();
      final app = _App(tcp: tcp, profile: urlTestProfile());
      app.bridge.urlTestAnswer = const UrlTestPayload(
        results: [
          UrlTestResult(serverId: _frankfurt, delayMs: 120),
          UrlTestResult(serverId: _helsinki, delayMs: 80),
          UrlTestResult(serverId: _moscow, error: 'timeout'),
        ],
      );
      await app.start();
      // Disconnected at open, so the open ping went over TCP.
      expect(app.bridge.urlTests, isEmpty);
      tcp.hosts.clear();

      await app.connect();
      await app.run();

      expect(app.bridge.urlTests, [_all]);
      expect(tcp.hosts, isEmpty);
      expect(app.pings[_frankfurt], const ServerPing.delay(120));
      expect(app.pings[_helsinki], const ServerPing.delay(80));
      expect(app.pings[_moscow], const ServerPing.unreachable());
      expect(app.pings[_amsterdam], const ServerPing.unknown());
    });

    for (final status in [
      TunnelStatus.disconnected,
      TunnelStatus.connecting,
      TunnelStatus.disconnecting,
      TunnelStatus.error,
    ]) {
      test('${status.json}: TCP instead of the core', () async {
        final tcp = InstantTcpPing();
        final app = _App(tcp: tcp, profile: urlTestProfile());
        await app.start();
        app.bridge.emitStatus(status);
        await pumpEventQueue();
        tcp.hosts.clear();

        await app.run();

        expect(app.bridge.urlTests, isEmpty);
        expect(tcp.hosts, hasLength(4));
      });
    }

    test('connected with ping.type tcp stays on TCP', () async {
      final tcp = InstantTcpPing();
      final app = _App(tcp: tcp);
      await app.start();
      await app.connect();
      tcp.hosts.clear();

      await app.run();

      expect(app.bridge.urlTests, isEmpty);
      expect(tcp.hosts, hasLength(4));
    });

    test('a failed core call falls back to TCP', () async {
      final tcp = InstantTcpPing();
      final app = _App(tcp: tcp, profile: urlTestProfile());
      app.bridge.urlTestError = const VpnBridgeException(
        CoreErrorCode.internal,
      );
      await app.start();
      await app.connect();
      tcp.hosts.clear();

      await app.run();

      expect(app.bridge.urlTests, hasLength(1));
      expect(tcp.hosts, hasLength(4));
      expect(app.pings[_frankfurt], const ServerPing.delay(50));
      expect(app.state.running, isFalse);
    });
  });

  group('sort toggle', () {
    test(
      'follows the policy until the user chooses, then keeps the choice',
      () async {
        final app = _App(
          profile: _profile(
            (json) =>
                (_defaults(json)['ui']! as Map<String, Object?>)['sortByPing'] =
                    false,
          ),
        );
        await app.start();
        await _until(() => app.container.read(sortChoiceProvider).hasValue);

        expect(app.container.read(sortByPingProvider), isFalse);
        expect(app.container.read(sortByPingLockedProvider), isFalse);

        await app.container.read(sortChoiceProvider.notifier).choose(true);

        expect(app.container.read(sortByPingProvider), isTrue);
        expect(app.settings.value.ui?.sortByPing, isTrue);
      },
    );

    test('reads the stored choice of the last run', () async {
      final app = _App();
      app.settings.value = withSortByPing(const SettingsPatch(), false);
      await app.start();
      await _until(() => app.container.read(sortChoiceProvider).hasValue);

      expect(app.container.read(sortByPingProvider), isFalse);
    });

    test('a locked key ignores the user and shows the default', () async {
      final app = _App(
        profile: _profile(
          (json) => _policy(json)['locked'] = ['ui.sortByPing'],
        ),
      );
      app.settings.value = withSortByPing(const SettingsPatch(), false);
      await app.start();
      await _until(() => app.container.read(sortChoiceProvider).hasValue);

      expect(app.container.read(sortByPingLockedProvider), isTrue);
      expect(app.container.read(sortByPingProvider), isTrue);
    });

    test('the ordered list follows the toggle and the pings', () async {
      // Ping order and name order differ here, so the toggle shows.
      final tcp = GatedTcpPing({
        'nl1.seed.invalid': const ServerPing.delay(90),
        'de1.seed.invalid': const ServerPing.delay(20),
      });
      final app = _App(tcp: tcp);
      await app.start();
      tcp.release();
      await _until(() => !app.state.running);
      await _until(() => app.container.read(sortChoiceProvider).hasValue);

      List<String> names() => [
        for (final server in app.container.read(
          orderedServersProvider(TunnelMode.regular),
        ))
          server.name,
      ];
      expect(names(), ['Frankfurt', 'Amsterdam', 'Helsinki']);

      await app.container.read(sortChoiceProvider.notifier).choose(false);
      expect(names(), ['Amsterdam', 'Frankfurt', 'Helsinki']);
    });
  });
}
