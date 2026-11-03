import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/features/servers/application/selection_controller.dart';
import 'package:vpnclient/features/servers/data/selection_store.dart';
import 'package:vpnclient/features/servers/presentation/server_picker.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/gen/l10n/app_localizations.dart';
import 'package:vpnclient/ui/ui.dart';

import '../connection/connection_harness.dart';

const _regular = TunnelMode.regular;
const _whitelist = TunnelMode.whitelist;

const _frankfurt = '10000000-0000-4000-8000-000000000001';
const _amsterdam = '10000000-0000-4000-8000-000000000002';
const _moscow = '10000000-0000-4000-8000-000000000004';
const _petersburg = '10000000-0000-4000-8000-000000000005';

/// Pulls the sheet up so every tile is on screen.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.drag(find.text('Servers'), const Offset(0, -400));
  await tester.pump();
  await tester.pump(AppDurations.slow);
}

/// Lets the sheet fall back so the PowerButton is on screen again.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.drag(find.text('Servers'), const Offset(0, 400));
  await tester.pump();
  await tester.pump(AppDurations.slow);
}

List<String> _titles(WidgetTester tester) => [
  for (final tile in tester.widgetList<ServerTile>(find.byType(ServerTile)))
    tile.title,
];

List<String> _selected(WidgetTester tester) => [
  for (final tile in tester.widgetList<ServerTile>(find.byType(ServerTile)))
    if (tile.selected) tile.title,
];

Future<void> _tapServer(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(ServerTile, name).first);
  await tester.pump();
  await tester.pump();
}

Map<String, Object?> _lastRequest(ConnectionHarness app) =>
    jsonDecode(app.bridge.requests.last) as Map<String, Object?>;

void main() {
  group('on the mode screens', () {
    testWidgets('each screen lists its own group, first by sortWeight chosen', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSheet(tester);

      expect(_titles(tester), ['Frankfurt', 'Amsterdam', 'Helsinki']);
      expect(_selected(tester), ['Frankfurt']);

      await app.showScreen(tester, _whitelist);
      await _openSheet(tester);

      expect(_titles(tester), ['Moscow', 'Saint Petersburg']);
      expect(_selected(tester), ['Moscow']);
    });

    testWidgets('a choice while disconnected is stored and calls nothing', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSheet(tester);

      await _tapServer(tester, 'Amsterdam');

      expect(_selected(tester), ['Amsterdam']);
      expect(app.selection.value.toJson(), {'regular': _amsterdam});
      expect(app.taps, isEmpty);
    });

    testWidgets('each group keeps its own choice', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSheet(tester);
      await _tapServer(tester, 'Amsterdam');

      await app.showScreen(tester, _whitelist);
      await _openSheet(tester);
      await _tapServer(tester, 'Saint Petersburg');
      expect(_selected(tester), ['Saint Petersburg']);

      await app.showScreen(tester, _regular);
      await _openSheet(tester);
      expect(_selected(tester), ['Amsterdam']);
      expect(app.selection.value.toJson(), {
        'regular': _amsterdam,
        'whitelist': _petersburg,
      });
    });

    testWidgets('a stored choice from the last run is shown and sent', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.selection.value = const SelectedServers(whitelist: _petersburg);
      await app.pump(tester);
      await app.showScreen(tester, _whitelist);
      await _openSheet(tester);

      expect(_selected(tester), ['Saint Petersburg']);

      await _closeSheet(tester);
      await tapPower(tester);

      expect(_lastRequest(app)['selected'], {
        'regular': _frankfurt,
        'whitelist': _petersburg,
      });
    });

    testWidgets('the start request carries the choice of both groups', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSheet(tester);
      await _tapServer(tester, 'Amsterdam');

      await _closeSheet(tester);
      await tapPower(tester);

      expect(app.taps, ['prepare', 'start']);
      expect(_lastRequest(app)['selected'], {
        'regular': _amsterdam,
        'whitelist': _moscow,
      });
    });

    testWidgets('a stored server that left the profile falls back cleanly', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.selection.value = const SelectedServers(
        regular: 'gone',
        whitelist: _frankfurt,
      );
      await app.pump(tester);
      await _openSheet(tester);

      expect(_selected(tester), ['Frankfurt']);

      await _closeSheet(tester);
      await tapPower(tester);

      expect(_lastRequest(app)['selected'], {
        'regular': _frankfurt,
        'whitelist': _moscow,
      });
    });

    testWidgets('a group without servers shows the empty state', (
      tester,
    ) async {
      final app = ConnectionHarness(profile: profileWithout(_whitelist));
      await app.pump(tester);
      await app.showScreen(tester, _whitelist);
      await _openSheet(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No servers yet'), findsOneWidget);
      expect(find.byType(ServerTile), findsNothing);
    });
  });

  group('while connected', () {
    testWidgets('a choice in the active group calls selectServer, not start', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );
      await _openSheet(tester);

      await _tapServer(tester, 'Amsterdam');

      expect(app.taps, ['selectServer']);
      expect(app.bridge.selections, [(_regular, _amsterdam)]);
      expect(_selected(tester), ['Amsterdam']);
      expect(powerButton(tester).state, PowerState.connected);
    });

    testWidgets('a choice in the other group moves its selector too', (
      tester,
    ) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );
      await app.showScreen(tester, _whitelist);
      await _openSheet(tester);

      await _tapServer(tester, 'Saint Petersburg');

      expect(app.taps, ['selectServer']);
      expect(app.bridge.selections, [(_whitelist, _petersburg)]);
      expect(app.selection.value.whitelist, _petersburg);
    });

    testWidgets('a failed selectServer shows the banner of its code', (
      tester,
    ) async {
      final app = ConnectionHarness();
      app.bridge.selectServerError = const VpnBridgeException(
        CoreErrorCode.configInvalid,
      );
      await app.pump(tester);
      await app.emitState(
        tester,
        TunnelStatus.connected,
        connectedSince: app.now,
      );
      await _openSheet(tester);

      await _tapServer(tester, 'Amsterdam');

      expect(
        find.text(
          'The connection settings are invalid. Update the app or '
          'contact support.',
        ),
        findsOneWidget,
      );
    });
  });

  for (final status in [TunnelStatus.connecting, TunnelStatus.disconnecting]) {
    testWidgets('${status.json}: taps on servers are ignored', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(tester, status);
      await _openSheet(tester);

      await _tapServer(tester, 'Amsterdam');

      expect(_selected(tester), ['Frankfurt']);
      expect(app.selection.value.toJson(), <String, Object?>{});
      expect(app.taps, isEmpty);
    });
  }

  group('ServerPicker alone', () {
    String fixture() =>
        File('../contracts/fixtures/profile/seed.json').readAsStringSync();
    ProfileV1 seed() =>
        ProfileV1.fromJson(jsonDecode(fixture()) as Map<String, Object?>);

    Future<void> pump(
      WidgetTester tester,
      FakeApiClient api, {
      MemoryProfileCache? cache,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            profileCacheProvider.overrideWithValue(
              cache ?? MemoryProfileCache(),
            ),
            selectionStoreProvider.overrideWithValue(MemorySelectionStore()),
            tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
            initialTokenProvider.overrideWithValue('t'),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ServerPicker(group: _regular)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the error with a retry', (tester) async {
      final api = FakeApiClient(load: () async => fixture())
        ..failure = const ApiUnavailable();
      await pump(tester, api);
      await _openSheet(tester);

      expect(find.byType(ErrorView), findsOneWidget);

      api.failure = null;
      await tester.ensureVisible(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(ServerTile), findsNWidgets(3));
    });

    testWidgets('warns when the list comes from the cache', (tester) async {
      final api = FakeApiClient(load: () async => fixture())
        ..failure = const ApiUnavailable();
      final cache = MemoryProfileCache()
        ..value = CachedProfile(seed(), '"old"');
      await pump(tester, api, cache: cache);
      await _openSheet(tester);

      expect(find.byType(StatusBanner), findsOneWidget);
      expect(find.byType(ServerTile), findsNWidgets(3));
    });
  });
}
