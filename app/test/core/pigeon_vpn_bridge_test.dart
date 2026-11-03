import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vpnclient/core/vpn/pigeon_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/gen/pigeon/vpn_api.g.dart' as pigeon;

class _MockHost extends Mock implements pigeon.VpnHostApi {}

String _fixture(String name) =>
    File('../contracts/fixtures/core_event/$name.json').readAsStringSync();

void main() {
  setUpAll(() => registerFallbackValue(pigeon.TunnelModeMsg.regular));

  late _MockHost host;
  late StreamController<String> raw;
  late PigeonVpnBridge bridge;

  setUp(() {
    host = _MockHost();
    raw = StreamController<String>.broadcast();
    bridge = PigeonVpnBridge(host: host, rawEvents: raw.stream);
  });

  tearDown(() => raw.close());

  test('decodes events from the contract fixtures', () async {
    final events = <CoreEvent>[];
    final subscription = bridge.events.listen(events.add);

    raw.add(_fixture('state_connected'));
    raw.add(_fixture('traffic'));
    await pumpEventQueue();
    await subscription.cancel();

    expect(events.map((event) => event.type), [
      CoreEventType.state,
      CoreEventType.traffic,
    ]);
    expect(events.first.state!.status, TunnelStatus.connected);
  });

  test('passes the request JSON through unchanged', () async {
    when(() => host.start(any())).thenAnswer((_) async {});
    await bridge.start('{"schemaVersion":1}');
    verify(() => host.start('{"schemaVersion":1}')).called(1);
  });

  test('maps a platform error to its core error code', () async {
    when(() => host.start(any())).thenThrow(
      PlatformException(code: 'start_failed', message: 'start_failed: busy'),
    );
    await expectLater(
      bridge.start('{}'),
      throwsA(
        isA<VpnBridgeException>()
            .having((e) => e.code, 'code', CoreErrorCode.startFailed)
            .having((e) => e.message, 'message', 'start_failed: busy'),
      ),
    );
  });

  test('an unknown error code becomes internal', () async {
    when(host.stop).thenThrow(PlatformException(code: 'surprise'));
    await expectLater(
      bridge.stop(),
      throwsA(
        isA<VpnBridgeException>().having(
          (e) => e.code,
          'code',
          CoreErrorCode.internal,
        ),
      ),
    );
  });

  test('maps the prepare result', () async {
    when(host.prepare).thenAnswer((_) async => pigeon.PrepareResult.denied);
    expect(await bridge.prepare(), VpnPrepareResult.denied);
    when(host.prepare).thenAnswer((_) async => pigeon.PrepareResult.granted);
    expect(await bridge.prepare(), VpnPrepareResult.granted);
  });

  test('maps modes', () async {
    when(() => host.setUserMode(any())).thenAnswer((_) async {});
    await bridge.setUserMode(TunnelMode.whitelist);
    verify(() => host.setUserMode(pigeon.TunnelModeMsg.whitelist)).called(1);
  });

  test('decodes the state and url test answers', () async {
    when(host.getState).thenAnswer((_) async => _fixture('state_disconnected'));
    when(() => host.urlTest(any()))
        .thenAnswer((_) async => _fixture('url_test'));

    final state = await bridge.getState();
    final test = await bridge.urlTest(['a']);

    expect(state.state!.status, TunnelStatus.disconnected);
    expect(test.urlTest!.results, hasLength(2));
  });

  test('decodes selectable apps', () async {
    when(host.listApps).thenAnswer(
      (_) async => ['{"package":"org.telegram.messenger","label":"Telegram"}'],
    );
    final apps = await bridge.listSelectableApps();
    expect(apps.single.id, 'org.telegram.messenger');
    expect(apps.single.label, 'Telegram');
  });

  test('forgetLastRequest reaches the host', () async {
    when(host.forgetLastRequest).thenAnswer((_) async {});
    await bridge.forgetLastRequest();
    verify(host.forgetLastRequest).called(1);
  });
}
