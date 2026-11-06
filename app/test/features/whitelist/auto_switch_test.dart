import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/whitelist/presentation/auto_switch_toggle.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import '../connection/connection_harness.dart';

// Acceptance of S2-05 (tech.md 16, 2.1, 34): the auto switch toggle on the
// whitelist screen and in settings, hidden when the provider turns the feature
// off; a mode event explains itself with a banner and moves the pager.

const _regular = TunnelMode.regular;
const _whitelist = TunnelMode.whitelist;
const _toggleTitle = 'Whitelists on mobile data';

/// The seed profile with the auto switch policy changed.
String _profile({bool flag = true, bool locked = false, bool? autoDefault}) {
  final json = jsonDecode(seedProfileJson()) as Map<String, Object?>;
  final policy = json['policy']! as Map<String, Object?>;
  policy['flags'] = {'autoWhitelist': flag};
  if (locked) {
    policy['locked'] = ['whitelist.autoOnCellular'];
  }
  if (autoDefault != null) {
    final defaults = policy['defaults']! as Map<String, Object?>;
    defaults['whitelist'] = {'autoOnCellular': autoDefault};
  }
  return jsonEncode(json);
}

int _shownPage(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

SettingsToggleTile? _toggle(WidgetTester tester) {
  final found = find
      .descendant(
        of: find.byType(AutoSwitchToggle),
        matching: find.byType(SettingsToggleTile),
      )
      .hitTestable();
  return found.evaluate().isEmpty
      ? null
      : tester.widget<SettingsToggleTile>(found);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pump();
  await tester.pump(AppDurations.slow * 2);
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_rounded));
  await tester.pump();
  await tester.pump(AppDurations.slow * 2);
}

Future<void> _flipToggle(WidgetTester tester) async {
  await tester.tap(find.text(_toggleTitle).hitTestable());
  await tester.pump();
  await tester.pump();
}

/// The banners the shown screen holds, as (kind, text).
List<(BannerKind, String)> _banners(WidgetTester tester) => [
  for (final banner in tester.widgetList<StatusBanner>(
    find.byType(StatusBanner).hitTestable(),
  ))
    (banner.kind, banner.text),
];

bool? _autoSwitchOf(String request) =>
    ((jsonDecode(request) as Map<String, Object?>)['autoSwitch']!
            as Map<String, Object?>)['enabled']
        as bool?;

Future<void> _animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDurations.normal * 2);
}

Future<ConnectionHarness> _connected(
  WidgetTester tester, {
  required TunnelMode screen,
  TunnelMode userMode = _regular,
  TunnelMode? effectiveMode,
}) async {
  final app = ConnectionHarness();
  await app.pump(tester);
  await app.showScreen(tester, screen);
  await app.emitState(
    tester,
    TunnelStatus.connected,
    userMode: userMode,
    effectiveMode: effectiveMode ?? userMode,
    connectedSince: app.now,
  );
  return app;
}

void main() {
  group('the toggle', () {
    // The design keeps the toggle in settings only (tech.md 43).
    testWidgets('sits in settings, not on the mode screens', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      expect(_toggle(tester), isNull, reason: 'regular screen');
      await app.showScreen(tester, _whitelist);
      expect(_toggle(tester), isNull, reason: 'whitelist screen');

      await _openSettings(tester);

      final toggle = _toggle(tester)!;
      expect(toggle.title, _toggleTitle);
      expect(toggle.value, isTrue, reason: 'the seed policy default');
      expect(toggle.locked, isFalse);
    });

    testWidgets('flips in settings and stores the choice', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSettings(tester);

      expect(find.text('BASICS'), findsOneWidget);
      expect(_toggle(tester)?.value, isTrue);

      await _flipToggle(tester);

      expect(_toggle(tester)?.value, isFalse);
      expect(app.settings.value.whitelist?.autoOnCellular, isFalse);
    });

    testWidgets('hides when the provider turns the feature off', (
      tester,
    ) async {
      final app = ConnectionHarness(profile: _profile(flag: false));
      await app.pump(tester);
      await _openSettings(tester);

      expect(find.text(_toggleTitle), findsNothing);
      expect(find.text('BASICS'), findsOneWidget, reason: 'other rows stay');
    });

    testWidgets('a locked key shows the policy value and ignores taps', (
      tester,
    ) async {
      final app = ConnectionHarness(
        profile: _profile(locked: true, autoDefault: false),
      );
      app.settings.value = const SettingsPatch(
        whitelist: WhitelistPatch(autoOnCellular: true),
      );
      await app.pump(tester);
      await _openSettings(tester);

      expect(_toggle(tester)?.locked, isTrue);
      expect(_toggle(tester)?.value, isFalse);

      await _flipToggle(tester);

      expect(_toggle(tester)?.value, isFalse);
      expect(app.taps, isEmpty);
    });

    testWidgets('off a tunnel it only stores, and the next start carries it', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSettings(tester);

      await _flipToggle(tester);

      expect(app.taps, isEmpty, reason: 'nothing runs to update');
      expect(app.settings.value.whitelist?.autoOnCellular, isFalse);

      await _closeSettings(tester);
      await tapPower(tester);

      expect(app.taps, ['prepare', 'start']);
      expect(_autoSwitchOf(app.bridge.requests.single), isFalse);
    });

    testWidgets('on a running tunnel it updates the request both ways', (
      tester,
    ) async {
      final app = await _connected(tester, screen: _whitelist);
      await _openSettings(tester);

      await _flipToggle(tester);
      await _flipToggle(tester);

      expect(app.taps, ['update', 'update'], reason: 'no restart, no start');
      expect(app.bridge.updates.map(_autoSwitchOf), [false, true]);
      final request =
          jsonDecode(app.bridge.updates.first) as Map<String, Object?>;
      expect(request['userMode'], _regular.json, reason: 'the running mode');
    });

    testWidgets('a rejected update shows the error banner', (tester) async {
      final app = await _connected(tester, screen: _whitelist);
      app.bridge.failNext(CoreErrorCode.configInvalid);
      await _openSettings(tester);

      await _flipToggle(tester);
      await _closeSettings(tester);

      expect(_banners(tester), [
        (
          BannerKind.error,
          'The connection settings are invalid. Update the app or contact '
              'support.',
        ),
      ]);
      expect(app.settings.value.whitelist?.autoOnCellular, isFalse);
    });
  });

  group('a mode event', () {
    testWidgets('network_cellular: info banner, pager to whitelist', (
      tester,
    ) async {
      final app = await _connected(tester, screen: _regular);

      await app.emitMode(
        tester,
        ModeSwitchReason.networkCellular,
        from: _regular,
        to: _whitelist,
      );
      await _animate(tester);

      expect(_shownPage(tester), _whitelist.index);
      expect(_banners(tester), [
        (BannerKind.info, 'Mobile network: switched to Whitelists'),
      ]);
      expect(app.taps, isEmpty, reason: 'the UI only follows the core');
    });

    testWidgets('network_wifi: info banner, pager back to regular', (
      tester,
    ) async {
      final app = await _connected(
        tester,
        screen: _whitelist,
        effectiveMode: _whitelist,
      );

      await app.emitMode(
        tester,
        ModeSwitchReason.networkWifi,
        from: _whitelist,
        to: _regular,
      );
      await _animate(tester);

      expect(_shownPage(tester), _regular.index);
      expect(_banners(tester), [
        (BannerKind.info, 'Network changed: switched to Regular VPN'),
      ]);
    });

    testWidgets('override_cleared: info banner, pager to whitelist', (
      tester,
    ) async {
      final app = await _connected(tester, screen: _regular);

      await app.emitMode(
        tester,
        ModeSwitchReason.overrideCleared,
        from: _regular,
        to: _whitelist,
      );
      await _animate(tester);

      expect(_shownPage(tester), _whitelist.index);
      expect(_banners(tester), [
        (
          BannerKind.info,
          'Auto switch follows the network again: switched to Whitelists',
        ),
      ]);
    });

    testWidgets('no_whitelist_servers: warning banner on the same group', (
      tester,
    ) async {
      final app = await _connected(tester, screen: _regular);

      await app.emitMode(
        tester,
        ModeSwitchReason.noWhitelistServers,
        from: _regular,
        to: _regular,
      );
      await _animate(tester);

      expect(_shownPage(tester), _regular.index);
      expect(_banners(tester), [
        (BannerKind.warning, 'No whitelist servers: Regular VPN stays on'),
      ]);
    });

    testWidgets('no_whitelist_servers with a group change moves the pager', (
      tester,
    ) async {
      final app = await _connected(
        tester,
        screen: _whitelist,
        effectiveMode: _whitelist,
      );

      await app.emitMode(
        tester,
        ModeSwitchReason.noWhitelistServers,
        from: _whitelist,
        to: _regular,
      );
      await _animate(tester);

      expect(_shownPage(tester), _regular.index);
      expect(_banners(tester).single.$1, BannerKind.warning);
    });

    testWidgets('user: no banner, the pager stays', (tester) async {
      final app = await _connected(tester, screen: _regular);
      await app.emitMode(
        tester,
        ModeSwitchReason.networkCellular,
        from: _regular,
        to: _whitelist,
      );
      await _animate(tester);
      await app.showScreen(tester, _regular);

      await app.emitMode(
        tester,
        ModeSwitchReason.user,
        from: _whitelist,
        to: _regular,
      );
      await _animate(tester);

      expect(_shownPage(tester), _regular.index);
      expect(_banners(tester), isEmpty, reason: 'user clears the banner');
    });

    testWidgets('the banner goes when the tunnel leaves connected', (
      tester,
    ) async {
      final app = await _connected(tester, screen: _whitelist);
      await app.emitMode(
        tester,
        ModeSwitchReason.networkCellular,
        from: _regular,
        to: _whitelist,
      );
      await _animate(tester);
      expect(_banners(tester), hasLength(1));

      await app.emitState(tester, TunnelStatus.disconnected);

      expect(_banners(tester), isEmpty);
    });

    testWidgets('the banner goes on a tap of the PowerButton', (tester) async {
      final app = await _connected(tester, screen: _regular);
      await app.emitMode(
        tester,
        ModeSwitchReason.noWhitelistServers,
        from: _regular,
        to: _regular,
      );
      expect(_banners(tester), hasLength(1));

      // A failed setUserMode sends neither a state nor a mode event, so only
      // the tap can clear the banner.
      app.bridge.setUserModeError = const VpnBridgeException(
        CoreErrorCode.internal,
      );
      await app.showScreen(tester, _whitelist);
      await tapPower(tester);

      expect(_banners(tester).map((banner) => banner.$1), [
        BannerKind.error,
      ], reason: 'the failed setUserMode replaces the mode banner');
    });
  });
}
