import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/app/app.dart';
import 'package:vpnclient/app/home_screen.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/device/device_identity.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/fake_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/connection/application/connection_controller.dart';
import 'package:vpnclient/features/ping/application/ping_controller.dart';
import 'package:vpnclient/features/ping/data/tcp_ping.dart';
import 'package:vpnclient/features/ping/data/user_settings_store.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/features/servers/application/selection_controller.dart';
import 'package:vpnclient/features/servers/data/selection_store.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import '../ping/ping_harness.dart';

String seedProfileJson() =>
    File('../contracts/fixtures/profile/seed.json').readAsStringSync();

/// The seed profile without the servers of [group].
String profileWithout(TunnelMode group) {
  final json = jsonDecode(seedProfileJson()) as Map<String, Object?>;
  json['servers'] = [
    for (final server in json['servers']! as List<Object?>)
      if ((server! as Map<String, Object?>)['group'] != group.json) server,
  ];
  return jsonEncode(json);
}

/// Records what reaches the bridge and scripts a failing prepare, which the
/// shared fake cannot do: the Windows bridge throws service_unavailable there.
class RecordingVpnBridge extends FakeVpnBridge {
  final requests = <String>[];
  VpnBridgeException? prepareError;
  VpnBridgeException? setUserModeError;
  VpnBridgeException? selectServerError;

  /// Arguments of every selectServer call.
  final selections = <(TunnelMode, String)>[];

  /// The answer to getState, as from a tunnel that ran before the app.
  CoreEvent? stateAtLaunch;

  @override
  Future<CoreEvent> getState() async {
    final state = await super.getState();
    return stateAtLaunch ?? state;
  }

  @override
  Future<void> setUserMode(TunnelMode mode) async {
    final error = setUserModeError;
    if (error != null) {
      throw error;
    }
    await super.setUserMode(mode);
  }

  @override
  Future<void> selectServer(TunnelMode group, String serverId) async {
    await super.selectServer(group, serverId);
    selections.add((group, serverId));
    final error = selectServerError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<VpnPrepareResult> prepare() async {
    final result = await super.prepare();
    final error = prepareError;
    if (error != null) {
      throw error;
    }
    return result;
  }

  @override
  Future<void> start(String tunnelRequestJson) {
    requests.add(tunnelRequestJson);
    return super.start(tunnelRequestJson);
  }
}

const androidIdentity = DeviceIdentity(
  platform: Platform.android,
  model: 'Samsung SM-A225F',
  installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
);

/// The signed-in app over fakes, on the home screen.
class ConnectionHarness {
  ConnectionHarness({String? profile, TcpPing? tcp})
    : api = FakeApiClient(load: () async => profile ?? seedProfileJson()),
      tcp = tcp ?? InstantTcpPing();

  final FakeApiClient api;

  /// Answers at once by default, so the ping on open settles.
  final TcpPing tcp;
  final settings = MemoryUserSettingsStore();
  final bridge = RecordingVpnBridge();
  final selection = MemorySelectionStore();
  DateTime now = DateTime.utc(2026, 11, 3, 12);

  /// Bridge calls after the start-up getState.
  List<String> get taps => bridge.calls.skip(1).toList();

  /// [settle] false leaves a running ping spinning, for a gated TcpPing.
  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
          initialTokenProvider.overrideWithValue('t'),
          vpnBridgeProvider.overrideWithValue(bridge),
          profileCacheProvider.overrideWithValue(MemoryProfileCache()),
          selectionStoreProvider.overrideWithValue(selection),
          deviceIdentityProvider.overrideWith((ref) async => androidIdentity),
          connectionClockProvider.overrideWithValue(() => now),
          tcpPingProvider.overrideWithValue(tcp),
          userSettingsStoreProvider.overrideWithValue(settings),
        ],
        child: const VpnClientApp(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }
    expect(bridge.calls, ['getState'], reason: 'the panel reads the state');
  }

  Future<void> showScreen(WidgetTester tester, TunnelMode mode) async {
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
        .read(homePageProvider.notifier)
        .show(mode.index);
    // A spinner or the connection timer never settles, so wait out the page
    // animation instead.
    await tester.pump();
    await tester.pump(AppDurations.normal * 2);
  }

  /// Delivers a state event as the core would send it.
  Future<void> emitState(
    WidgetTester tester,
    TunnelStatus status, {
    TunnelMode userMode = TunnelMode.regular,
    TunnelMode? effectiveMode,
    DateTime? connectedSince,
  }) async {
    bridge.emit(
      CoreEvent(
        type: CoreEventType.state,
        at: now,
        state: StatePayload(
          status: status,
          userMode: userMode,
          effectiveMode: effectiveMode ?? userMode,
          connectedSince: connectedSince,
        ),
      ),
    );
    await _settle(tester);
  }

  /// One pump delivers the event, the next rebuilds the widgets watching it.
  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> emitError(WidgetTester tester, CoreErrorCode code) async {
    bridge.emit(
      CoreEvent(
        type: CoreEventType.error,
        at: now,
        error: ErrorPayload(code: code, message: 'from the core'),
      ),
    );
    await _settle(tester);
  }
}

PowerButton powerButton(WidgetTester tester) =>
    tester.widget<PowerButton>(find.byType(PowerButton));

Future<void> tapPower(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(PowerButton),
      matching: find.byType(InkWell),
    ),
  );
  await tester.pump();
  await tester.pump();
}
