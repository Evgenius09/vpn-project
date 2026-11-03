import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/connection/domain/tunnel_request.dart';
import 'package:vpnclient/gen/api/export.dart';

const _fixtures = '../contracts/fixtures';

Map<String, Object?> _read(String path) =>
    jsonDecode(File('$_fixtures/$path').readAsStringSync())
        as Map<String, Object?>;

ProfileV1 _seed() => ProfileV1.fromJson(_read('profile/seed.json'));

ProfileV1 _withPolicy(
  ProfileV1 profile, {
  SettingsPatch? defaults,
  bool? autoWhitelist,
}) {
  final json = profile.toJson();
  final policy = profile.policy.toJson();
  if (defaults != null) {
    policy['defaults'] = defaults.toJson();
  }
  if (autoWhitelist != null) {
    policy['flags'] = {'autoWhitelist': autoWhitelist};
  }
  json['policy'] = policy;
  return ProfileV1.fromJson(
    jsonDecode(jsonEncode(json)) as Map<String, Object?>,
  );
}

/// The request exactly as the bridge receives it.
Map<String, Object?> _wire(TunnelRequest request) =>
    jsonDecode(jsonEncode(request.toJson())) as Map<String, Object?>;

/// Dotted key paths of a JSON value. List items collapse into one `[]` step.
Set<String> _paths(Object? value, [String prefix = '']) {
  final paths = <String>{};
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      paths
        ..add(path)
        ..addAll(_paths(entry.value, path));
    }
  } else if (value is List<Object?>) {
    for (final item in value) {
      paths.addAll(_paths(item, '$prefix[]'));
    }
  }
  return paths;
}

/// Paths outside the server list and the selection, which depend on the data.
Set<String> _shape(Map<String, Object?> request) => _paths(request)
    .where(
      (path) => !path.startsWith('servers[]') && !path.startsWith('selected.'),
    )
    .toSet();

extension on Any {
  Generator<T?> optional<T>(Generator<T> item) =>
      oneOf<T?>([always<T?>(null), item.map<T?>((value) => value)]);

  Generator<SettingsPatch> get tunnelPatch => combine6(
    optional<bool>(this.bool),
    optional<int>(intInRange(1280, 9001)),
    optional<RoutingPreset>(choose(RoutingPreset.values)),
    optional<DnsStrategy>(choose(DnsStrategy.values)),
    optional<TunStack>(choose(TunStack.values)),
    optional<bool>(this.bool),
    (
      bool? ipv6,
      int? mtu,
      RoutingPreset? preset,
      DnsStrategy? strategy,
      TunStack? stack,
      bool? autoOnCellular,
    ) => SettingsPatch(
      routing: preset == null ? null : RoutingPatch(preset: preset),
      dns: strategy == null ? null : DnsPatch(strategy: strategy),
      net: NetPatch(ipv6: ipv6, mtu: mtu, tunStack: stack),
      whitelist: WhitelistPatch(autoOnCellular: autoOnCellular),
    ),
  );
}

void main() {
  test('sends every server of the profile, both groups, as received', () {
    final profile = _seed();
    final request = buildTunnelRequest(
      platform: Platform.android,
      userMode: TunnelMode.regular,
      profile: profile,
    );
    final wire = _wire(request);

    expect(wire['schemaVersion'], 1);
    expect(wire['platform'], 'android');
    expect(wire['userMode'], 'regular');
    expect(
      wire['servers'],
      jsonDecode(jsonEncode(profile.toJson()))['servers'],
    );
    expect(wire['log'], {'level': 'warn'});
  });

  test('leaves the selection to the core until S1-09 (tech.md 27.2)', () {
    final request = buildTunnelRequest(
      platform: Platform.windows,
      userMode: TunnelMode.whitelist,
      profile: _seed(),
    );

    expect(_wire(request)['selected'], <String, Object?>{});
    expect(_wire(request)['userMode'], 'whitelist');
    expect(_wire(request)['platform'], 'windows');
  });

  test('takes policy defaults and fills the rest with built-in values', () {
    final settings = _wire(
      buildTunnelRequest(
        platform: Platform.android,
        userMode: TunnelMode.regular,
        profile: _seed(),
      ),
    )['settings'];

    expect(settings, {
      'routing': {
        'enabled': true,
        'preset': 'ru_direct',
        'rules': <Object?>[],
        'ruleSets': <Object?>[],
      },
      'dns': {
        'remote': 'https://1.1.1.1/dns-query',
        'direct': 'https://77.88.8.8/dns-query',
        'strategy': 'prefer_ipv4',
      },
      'net': {
        'ipv6': false,
        'sniffing': true,
        'tlsFragment': {'enabled': false, 'record': false},
        'mtu': 1500,
        'tunStack': 'mixed',
        'excludeRoutes': <Object?>[],
        'bypassLan': true,
      },
      'perApp': {'mode': 'off', 'apps': <Object?>[]},
    });
  });

  test('a policy without defaults gives the built-in settings', () {
    final seeded = buildTunnelRequest(
      platform: Platform.android,
      userMode: TunnelMode.regular,
      profile: _seed(),
    );
    final bare = buildTunnelRequest(
      platform: Platform.android,
      userMode: TunnelMode.regular,
      profile: _withPolicy(_seed(), defaults: const SettingsPatch()),
    );

    // The built-in values equal the shipped policy (tech.md 27.2).
    expect(_wire(bare)['settings'], _wire(seeded)['settings']);
  });

  test('a policy value wins over the built-in one', () {
    final request = buildTunnelRequest(
      platform: Platform.android,
      userMode: TunnelMode.regular,
      profile: _withPolicy(
        _seed(),
        defaults: const SettingsPatch(
          routing: RoutingPatch(enabled: false, preset: RoutingPreset.allProxy),
          dns: DnsPatch(remote: 'https://9.9.9.9/dns-query'),
          net: NetPatch(
            mtu: 1400,
            tlsFragment: TlsFragment(enabled: true, record: true),
            excludeRoutes: ['10.0.0.0/8'],
          ),
          perApp: PerAppPatch(mode: PerAppMode.exclude, apps: ['org.example']),
        ),
      ),
    );
    final settings = request.settings;

    expect(settings.routing.enabled, isFalse);
    expect(settings.routing.preset, RoutingPreset.allProxy);
    expect(settings.dns.remote, 'https://9.9.9.9/dns-query');
    expect(settings.dns.direct, 'https://77.88.8.8/dns-query');
    expect(settings.net.mtu, 1400);
    expect(settings.net.tlsFragment.enabled, isTrue);
    expect(settings.net.tlsFragment.record, isTrue);
    expect(settings.net.excludeRoutes, ['10.0.0.0/8']);
    expect(settings.perApp.mode, PerAppMode.exclude);
    expect(settings.perApp.apps, ['org.example']);
  });

  group('autoSwitch (tech.md 27.2)', () {
    bool enabled(ProfileV1 profile) => buildTunnelRequest(
      platform: Platform.android,
      userMode: TunnelMode.regular,
      profile: profile,
    ).autoSwitch.enabled;

    test('on when the flag and autoOnCellular are on', () {
      expect(enabled(_seed()), isTrue);
    });

    test('off when the provider turns the feature off', () {
      expect(enabled(_withPolicy(_seed(), autoWhitelist: false)), isFalse);
    });

    test('off when autoOnCellular is off', () {
      final profile = _withPolicy(
        _seed(),
        defaults: const SettingsPatch(
          whitelist: WhitelistPatch(autoOnCellular: false),
        ),
      );
      expect(enabled(profile), isFalse);
    });
  });

  test('the request has the shape of the fixture', () {
    final fixture = _read('tunnel_request/android_regular.json');
    final request = _wire(
      buildTunnelRequest(
        platform: Platform.android,
        userMode: TunnelMode.regular,
        profile: _seed(),
      ),
    );

    expect(_shape(request), _shape(fixture));
  });

  test('every server object keeps the ServerNode schema', () {
    final request = _wire(
      buildTunnelRequest(
        platform: Platform.windows,
        userMode: TunnelMode.regular,
        profile: _seed(),
      ),
    );
    for (final server in request['servers']! as List<Object?>) {
      final json = server! as Map<String, Object?>;
      expect(ServerNode.fromJson(json).toJson(), json);
    }
  });

  Glados3<SettingsPatch, Platform, TunnelMode>(
    any.tunnelPatch,
    any.choose(Platform.values),
    any.choose(TunnelMode.values),
  ).test('any policy gives a request the generated model reads back', (
    patch,
    platform,
    mode,
  ) {
    final fixture = _read('tunnel_request/android_regular.json');
    final request = buildTunnelRequest(
      platform: platform,
      userMode: mode,
      profile: _withPolicy(_seed(), defaults: patch),
    );
    final wire = _wire(request);

    expect(TunnelRequest.fromJson(wire).toJson(), request.toJson());
    expect(_shape(wire), _shape(fixture));
    expect(request.settings.net.ipv6, patch.net?.ipv6 ?? false);
    expect(request.settings.net.mtu, patch.net?.mtu ?? 1500);
    expect(
      request.settings.routing.preset,
      patch.routing?.preset ?? RoutingPreset.ruDirect,
    );
    expect(request.autoSwitch.enabled, patch.whitelist?.autoOnCellular ?? true);
  });

  test('hasServersIn tells whether a mode has servers to start', () {
    final profile = _seed();
    expect(hasServersIn(profile, TunnelMode.regular), isTrue);
    expect(hasServersIn(profile, TunnelMode.whitelist), isTrue);

    final regularOnly = ProfileV1.fromJson(
      jsonDecode(
        jsonEncode(
          profile.toJson()
            ..['servers'] = [
              for (final server in profile.servers)
                if (server.group == TunnelMode.regular) server.toJson(),
            ],
        ),
      ) as Map<String, Object?>,
    );
    expect(hasServersIn(regularOnly, TunnelMode.whitelist), isFalse);
    expect(hasServersIn(regularOnly, TunnelMode.regular), isTrue);
  });
}
