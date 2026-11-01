// Starts the real core through the platform bridge and checks that its events
// reach Dart (tech.md 15.1, S0-06). Run with FAKE_VPN=false on a device.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpnclient/core/vpn/pigeon_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';

const _request = '''
{
  "schemaVersion": 1,
  "platform": "android",
  "userMode": "regular",
  "selected": {},
  "servers": [],
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
      "excludeRoutes": [],
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
    final VpnBridge bridge = PigeonVpnBridge();
    final statuses = <TunnelStatus>[];
    final subscription = bridge.events.listen((event) {
      final state = event.state;
      if (state != null) {
        statuses.add(state.status);
      }
    });
    await tester.pump(const Duration(milliseconds: 200));

    await tester.runAsync(() async {
      await bridge.start(_request).timeout(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    expect(statuses, contains(TunnelStatus.connected));

    final state = await tester.runAsync(bridge.getState);
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
    final VpnBridge bridge = PigeonVpnBridge();
    Object? failure;
    await tester.runAsync(() async {
      try {
        await bridge.start('{}').timeout(const Duration(seconds: 30));
      } on VpnBridgeException catch (error) {
        failure = error;
      }
    });
    expect((failure! as VpnBridgeException).code, CoreErrorCode.configInvalid);
  });
}
