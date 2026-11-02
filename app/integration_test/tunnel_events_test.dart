// Starts the real core through the platform bridge and checks that its events
// reach Dart (tech.md 15.1, S0-06). Run with FAKE_VPN=false on a device.
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';

String _server() => '''
{
  "id": "11111111-1111-4111-8111-111111111111",
  "group": "regular",
  "name": "Fixture",
  "protocol": "vless_reality",
  "address": "de1.example.invalid",
  "port": 443,
  "sortWeight": 10,
  "vless": {
    "uuid": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "flow": "xtls-rprx-vision",
    "serverName": "www.example.com",
    "publicKey": "YNSIc4L0W_A9M1wbXF_Gf5Otbun1wovS3NCVIwIPY2A",
    "shortId": "0123456789abcdef",
    "fingerprint": "chrome"
  }
}
''';

/// The excluded routes cover every IPv4 address, so the tunnel captures
/// nothing: a real TUN would otherwise cut the CI runner off from GitHub.
String _request() =>
    '''
{
  "schemaVersion": 1,
  "platform": "${io.Platform.isWindows ? 'windows' : 'android'}",
  "userMode": "regular",
  "selected": {},
  "servers": [${_server()}],
  "autoSwitch": { "enabled": false },
  "settings": {
    "routing": { "enabled": true, "preset": "all_proxy", "rules": [], "ruleSets": [] },
    "dns": { "remote": "https://1.1.1.1/dns-query", "direct": "77.88.8.8", "strategy": "prefer_ipv4" },
    "net": {
      "ipv6": false,
      "sniffing": true,
      "tlsFragment": { "enabled": false, "record": false },
      "mtu": 1500,
      "tunStack": "mixed",
      "excludeRoutes": ["0.0.0.0/1", "128.0.0.0/1"],
      "bypassLan": true
    },
    "perApp": { "mode": "off", "apps": [] }
  },
  "log": { "level": "warn" }
}
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core events reach Dart', (tester) async {
    final VpnBridge bridge = createPlatformBridge()!;
    final statuses = <TunnelStatus>[];
    final subscription = bridge.events.listen((event) {
      final state = event.state;
      if (state != null) {
        statuses.add(state.status);
      }
    });
    await tester.pump(const Duration(milliseconds: 200));

    if (io.Platform.isAndroid) {
      // S1-03 adds openTun and turns this into the full cycle below.
      Object? failure;
      await tester.runAsync(() async {
        try {
          await bridge.start(_request()).timeout(const Duration(seconds: 30));
        } on VpnBridgeException catch (error) {
          failure = error;
        }
        debugPrint('tunnel test: start returned $failure');
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      expect((failure! as VpnBridgeException).code, CoreErrorCode.startFailed);
      expect(statuses, [TunnelStatus.connecting, TunnelStatus.error]);
      debugPrint('tunnel test: cancelling the subscription');
      await subscription.cancel();
      debugPrint('tunnel test: first test done');
      return;
    }

    await tester.runAsync(() async {
      await bridge.start(_request()).timeout(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    expect(statuses, contains(TunnelStatus.connected));

    final state = await tester.runAsync(
      () => bridge.getState().timeout(const Duration(seconds: 30)),
    );
    expect(state!.state!.status, TunnelStatus.connected);

    await tester.runAsync(() async {
      await bridge.stop().timeout(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    expect(statuses, [
      TunnelStatus.connecting,
      TunnelStatus.connected,
      TunnelStatus.disconnecting,
      TunnelStatus.disconnected,
    ]);

    await subscription.cancel();
  });

  testWidgets('an invalid request fails with config_invalid', (tester) async {
    final VpnBridge bridge = createPlatformBridge()!;
    Object? failure;
    debugPrint('tunnel test: second test started');
    await tester.runAsync(() async {
      try {
        await bridge.start('{}').timeout(const Duration(seconds: 30));
      } on VpnBridgeException catch (error) {
        failure = error;
      }
      debugPrint('tunnel test: second start returned $failure');
    });
    expect((failure! as VpnBridgeException).code, CoreErrorCode.configInvalid);
  });
}
