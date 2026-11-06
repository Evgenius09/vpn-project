import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/ping/data/user_settings_store.dart';
import 'package:vpnclient/features/ping/domain/server_ping.dart';
import 'package:vpnclient/features/ping/presentation/ping_controls.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/gen/l10n/app_localizations.dart';
import 'package:vpnclient/ui/ui.dart';

import '../connection/connection_harness.dart';
import 'ping_harness.dart';

/// Pulls the sheet up so every tile is on screen.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.drag(find.text('Servers'), const Offset(0, -400));
  await tester.pump();
  await tester.pump(AppDurations.slow);
}

List<String> _titles(WidgetTester tester) => [
  for (final tile in tester.widgetList<ServerTile>(find.byType(ServerTile)))
    tile.title,
];

PingValue _pingOf(WidgetTester tester, String title) => tester
    .widget<ServerTile>(find.widgetWithText(ServerTile, title).first)
    .ping;

/// The sort chip of the sheet header (tech.md 31.2, 43): on means ping order.
({bool value, bool locked}) _toggle(WidgetTester tester) {
  final chip = tester.widget<SheetChip>(
    find.descendant(
      of: find.byType(SortByPingToggle),
      matching: find.byType(SheetChip),
    ),
  );
  return (value: chip.active, locked: chip.onPressed == null);
}

/// The seed profile with [change] applied to its policy.
String _withPolicy(void Function(Map<String, Object?> policy) change) {
  final json = jsonDecode(seedProfileJson()) as Map<String, Object?>;
  change(json['policy']! as Map<String, Object?>);
  return jsonEncode(json);
}

void main() {
  testWidgets('the list shows each ping, Hysteria2 stays unknown', (
    tester,
  ) async {
    final app = ConnectionHarness();
    await app.pump(tester);
    await _openSheet(tester);

    expect(_pingOf(tester, 'Frankfurt'), isA<PingMs>());
    expect((_pingOf(tester, 'Frankfurt') as PingMs).value, 50);
    expect(_pingOf(tester, 'Helsinki'), isA<PingUnknown>());
    expect(find.text('50 ms'), findsWidgets);
  });

  testWidgets('measuring shows a spinner, then the result in ping order', (
    tester,
  ) async {
    final tcp = GatedTcpPing({
      'nl1.seed.invalid': const ServerPing.delay(20),
      'de1.seed.invalid': const ServerPing.delay(90),
    });
    final app = ConnectionHarness(tcp: tcp);
    await app.pump(tester, settle: false);
    await _openSheet(tester);

    expect(_pingOf(tester, 'Frankfurt'), isA<PingMeasuring>());
    expect(_titles(tester), ['Frankfurt', 'Amsterdam', 'Helsinki']);

    tcp.release();
    await tester.pump();
    await tester.pump();

    expect(_titles(tester), ['Amsterdam', 'Frankfurt', 'Helsinki']);
    expect(_pingOf(tester, 'Amsterdam'), isA<PingMs>());
  });

  testWidgets('the toggle switches the list back to the sortWeight order', (
    tester,
  ) async {
    final tcp = GatedTcpPing({
      'nl1.seed.invalid': const ServerPing.delay(20),
      'de1.seed.invalid': const ServerPing.delay(90),
    });
    final app = ConnectionHarness(tcp: tcp);
    await app.pump(tester, settle: false);
    tcp.release();
    await tester.pumpAndSettle();
    await _openSheet(tester);
    expect(_toggle(tester).value, isTrue);
    expect(_titles(tester), ['Amsterdam', 'Frankfurt', 'Helsinki']);

    await tester.tap(find.byType(SortByPingToggle));
    await tester.pumpAndSettle();

    expect(_toggle(tester).value, isFalse);
    expect(_titles(tester), ['Frankfurt', 'Amsterdam', 'Helsinki']);
    expect(app.settings.value.ui?.sortByPing, isFalse);
  });

  testWidgets('the toggle starts from the stored choice', (tester) async {
    final app = ConnectionHarness();
    app.settings.value = withSortByPing(const SettingsPatch(), false);
    await app.pump(tester);
    await _openSheet(tester);

    expect(_toggle(tester).value, isFalse);
  });

  testWidgets('a locked toggle shows the lock and ignores taps', (
    tester,
  ) async {
    final app = ConnectionHarness(
      profile: _withPolicy((policy) => policy['locked'] = ['ui.sortByPing']),
    );
    await app.pump(tester);
    await _openSheet(tester);

    expect(_toggle(tester).locked, isTrue);
    await tester.tap(find.byType(SortByPingToggle));
    await tester.pumpAndSettle();
    expect(_toggle(tester).value, isTrue);
    expect(app.settings.value.ui, isNull);
  });

  testWidgets('the refresh button pings again', (tester) async {
    final tcp = InstantTcpPing();
    final app = ConnectionHarness(tcp: tcp);
    await app.pump(tester);
    await _openSheet(tester);
    expect(tcp.hosts, hasLength(4));

    await tester.tap(find.byTooltip('Check ping'));
    await tester.pumpAndSettle();

    expect(tcp.hosts, hasLength(8));
    expect(app.taps, isEmpty, reason: 'TCP ping does not reach the bridge');
  });

  testWidgets('url_test while connected goes through the core', (tester) async {
    final tcp = InstantTcpPing();
    final app = ConnectionHarness(
      tcp: tcp,
      profile: _withPolicy(
        (policy) =>
            ((policy['defaults']! as Map<String, Object?>)['ping']!
                    as Map<String, Object?>)['type'] =
                'url_test',
      ),
    );
    await app.pump(tester);
    await app.emitState(tester, TunnelStatus.connected);
    await _openSheet(tester);
    tcp.hosts.clear();

    await tester.tap(find.byTooltip('Check ping'));
    await tester.pump();
    await tester.pump();

    expect(app.taps, ['urlTest']);
    expect(tcp.hosts, isEmpty);
    // The fake core answers 42 ms for every server, Hysteria2 included.
    expect((_pingOf(tester, 'Helsinki') as PingMs).value, 42);
  });

  test('the header strings exist in Russian and English', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    final en = lookupAppLocalizations(const Locale('en'));

    expect(ru.pingSortByPing, 'Сортировать по пингу');
    expect(ru.pingRefresh, 'Проверить пинг');
    expect(en.pingSortByPing, 'Sort by ping');
    expect(en.pingRefresh, 'Check ping');
  });
}
