import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import 'connection_harness.dart';

const _regular = TunnelMode.regular;
const _whitelist = TunnelMode.whitelist;

void main() {
  group('the PowerButton table of tech.md 2.1', () {
    for (final screen in TunnelMode.values) {
      testWidgets('disconnected on ${screen.json}: idle, a tap starts it', (
        tester,
      ) async {
        final app = ConnectionHarness();
        await app.pump(tester);
        await app.showScreen(tester, screen);

        expect(powerButton(tester).state, PowerState.idle);
        expect(powerButton(tester).caption, 'Disconnected');

        await tapPower(tester);

        expect(app.taps, ['prepare', 'start']);
        final request =
            jsonDecode(app.bridge.requests.single) as Map<String, Object?>;
        expect(request['userMode'], screen.json);
        expect(request['platform'], 'android');
        expect(powerButton(tester).state, PowerState.connected);
      });
    }

    testWidgets('connected on its own screen: a tap stops', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.showScreen(tester, _whitelist);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        effectiveMode: _whitelist,
        connectedSince: app.now,
      );

      expect(powerButton(tester).state, PowerState.connected);

      await tapPower(tester);

      expect(app.taps, ['stop']);
      expect(powerButton(tester).state, PowerState.idle);
    });

    testWidgets('connected in the other mode: idle with a hint, and a tap '
        'calls setUserMode, not start', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.showScreen(tester, _whitelist);
      await tapPower(tester);
      await app.showScreen(tester, _regular);

      expect(powerButton(tester).state, PowerState.idle);
      expect(powerButton(tester).caption, 'Now active: Whitelists');

      await tapPower(tester);

      expect(app.taps, ['prepare', 'start', 'setUserMode']);
      expect(app.bridge.requests, hasLength(1));
      expect(powerButton(tester).state, PowerState.connected);
    });

    for (final status in [
      TunnelStatus.connecting,
      TunnelStatus.disconnecting,
    ]) {
      testWidgets('${status.json}: the same state on both screens, taps '
          'ignored', (tester) async {
        final app = ConnectionHarness();
        await app.pump(tester);
        await app.emitState(tester, status, userMode: _whitelist);
        final expected = status == TunnelStatus.connecting
            ? PowerState.connecting
            : PowerState.disconnecting;

        for (final screen in TunnelMode.values) {
          await app.showScreen(tester, screen);
          expect(powerButton(tester).state, expected, reason: screen.json);
          await tapPower(tester);
        }

        expect(app.taps, isEmpty);
      });
    }
  });

  testWidgets('the timer counts from connectedSince', (tester) async {
    final app = ConnectionHarness();
    await app.pump(tester);
    await app.emitState(
      tester,
      TunnelStatus.connected,
      connectedSince: app.now.subtract(
        const Duration(minutes: 12, seconds: 31),
      ),
    );

    expect(powerButton(tester).caption, 'Connected 00:12:31');

    app.now = app.now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(powerButton(tester).caption, 'Connected 00:12:32');
  });

  testWidgets('traffic shows only while connected', (tester) async {
    final app = ConnectionHarness();
    await app.pump(tester);
    await app.emitState(
      tester,
      TunnelStatus.connected,
      connectedSince: app.now,
    );
    app.bridge.emit(
      CoreEvent(
        type: CoreEventType.traffic,
        at: app.now,
        traffic: const TrafficPayload(
          upBps: 2048,
          downBps: 512,
          upTotal: 1,
          downTotal: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2.0 KB/s'), findsOneWidget);
    expect(find.text('512 B/s'), findsOneWidget);

    await app.showScreen(tester, _whitelist);
    expect(find.byType(TrafficCounter), findsNothing, reason: 'not active');
    await app.showScreen(tester, _regular);

    await app.emitState(tester, TunnelStatus.disconnected);

    expect(find.byType(TrafficCounter), findsNothing);
  });

  group('errors', () {
    testWidgets('a denied VPN permission shows a banner and does not start', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.bridge.prepareResult = VpnPrepareResult.denied;
      await app.pump(tester);

      await tapPower(tester);

      expect(app.taps, ['prepare']);
      expect(
        find.widgetWithText(
          StatusBanner,
          'Allow the VPN connection to turn the VPN on.',
        ),
        findsOneWidget,
      );
      expect(powerButton(tester).state, PowerState.idle);
    });

    testWidgets('a missing Windows service asks to reinstall the app', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.bridge.prepareError = const VpnBridgeException(
        CoreErrorCode.serviceUnavailable,
      );
      await app.pump(tester);

      await tapPower(tester);

      expect(app.taps, ['prepare']);
      expect(
        find.widgetWithText(
          StatusBanner,
          'The VPN service is not responding. Reinstall the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('start_failed turns the button to error with a banner', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.bridge.failNext(CoreErrorCode.startFailed);
      await app.pump(tester);

      await tapPower(tester);

      expect(app.taps, ['prepare', 'start']);
      expect(powerButton(tester).state, PowerState.error);
      expect(powerButton(tester).caption, 'Connection error');
      expect(
        find.widgetWithText(
          StatusBanner,
          'Could not start the VPN. Try again or pick another server.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap after an error starts again and clears the banner', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.bridge.failNext(CoreErrorCode.startFailed);
      await app.pump(tester);
      await tapPower(tester);

      await tapPower(tester);

      expect(app.taps, ['prepare', 'start', 'prepare', 'start']);
      expect(powerButton(tester).state, PowerState.connected);
      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('an error event from the core shows its banner', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );

      await app.emitError(tester, CoreErrorCode.revoked);
      await app.emitState(tester, TunnelStatus.disconnected);

      expect(
        find.widgetWithText(
          StatusBanner,
          'Another VPN app took over the connection.',
        ),
        findsOneWidget,
      );
      expect(powerButton(tester).state, PowerState.idle);
    });

    testWidgets('a connection after an error clears the banner', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitError(tester, CoreErrorCode.revoked);
      expect(find.byType(StatusBanner), findsOneWidget);

      // Always-on brings the tunnel back without a tap.
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );

      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('a new tap clears the old banner', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );
      await app.emitError(tester, CoreErrorCode.internal);
      expect(find.byType(StatusBanner), findsOneWidget);

      await tapPower(tester);

      expect(app.taps, ['stop']);
      expect(find.byType(StatusBanner), findsNothing);
    });

    testWidgets('a mode without servers says so and does not call the core', (
      tester,
    ) async {
      final app = ConnectionHarness(profile: profileWithout(_whitelist));
      await app.pump(tester);
      await app.showScreen(tester, _whitelist);

      await tapPower(tester);

      expect(app.taps, isEmpty);
      expect(
        find.widgetWithText(StatusBanner, 'No servers for this mode yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed setUserMode shows the core error', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        userMode: _whitelist,
        connectedSince: app.now,
      );
      app.bridge.setUserModeError = const VpnBridgeException(
        CoreErrorCode.noServersInGroup,
      );

      await tapPower(tester);

      expect(
        find.widgetWithText(StatusBanner, 'No servers for this mode yet.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('swiping between screens never reaches the bridge', (
    tester,
  ) async {
    final app = ConnectionHarness();
    await app.pump(tester);

    await tester.fling(find.byType(ModePager), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ModePager), const Offset(500, 0), 2000);
    await tester.pumpAndSettle();

    expect(app.taps, isEmpty);
  });

  testWidgets('a tunnel running at launch shows as connected', (tester) async {
    final app = ConnectionHarness();
    app.bridge.stateAtLaunch = CoreEvent(
      type: CoreEventType.state,
      at: app.now,
      state: StatePayload(
        status: TunnelStatus.connected,
        userMode: _regular,
        effectiveMode: _regular,
        connectedSince: app.now.subtract(const Duration(seconds: 7)),
      ),
    );
    await app.pump(tester);

    expect(powerButton(tester).state, PowerState.connected);
    expect(powerButton(tester).caption, 'Connected 00:00:07');
  });
}
