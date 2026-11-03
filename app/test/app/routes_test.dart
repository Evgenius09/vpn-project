import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/app/app.dart';
import 'package:vpnclient/app/kitchen_sink.dart';
import 'package:vpnclient/app/routes.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/fake_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/auth/presentation/settings_screen.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/ui/ui.dart';

void main() {
  group('redirectFor', () {
    test('sends a guest to login', () {
      expect(redirectFor(RoutePaths.home, signedIn: false), RoutePaths.login);
      expect(
        redirectFor(RoutePaths.settings, signedIn: false),
        RoutePaths.login,
      );
    });

    test('keeps a guest on login', () {
      expect(redirectFor(RoutePaths.login, signedIn: false), isNull);
    });

    test('moves a signed-in user off login', () {
      expect(redirectFor(RoutePaths.login, signedIn: true), RoutePaths.home);
    });

    test('lets a signed-in user through', () {
      expect(redirectFor(RoutePaths.home, signedIn: true), isNull);
      expect(redirectFor(RoutePaths.settings, signedIn: true), isNull);
    });

    test('the kitchen sink needs no token', () {
      expect(redirectFor(RoutePaths.kitchenSink, signedIn: false), isNull);
    });

    Glados<String>(any.letterOrDigits)
        .test('a guest never reaches a private path', (path) {
          final destination = '/$path';
          final redirect = redirectFor(destination, signedIn: false);
          final isPublic =
              destination == RoutePaths.login ||
              destination == RoutePaths.kitchenSink;
          expect(redirect == null, isPublic, reason: destination);
        });
  });

  test('release builds leave out the kitchen sink', () {
    final paths = routesFor(debug: false).map((route) => route.path);
    expect(paths, isNot(contains(RoutePaths.kitchenSink)));
    expect(paths, contains(RoutePaths.home));
  });

  test('debug builds keep every contract route', () {
    expect(routesFor(debug: true).map((route) => route.path), [
      '/login',
      '/',
      '/settings',
      '/settings/:section',
      '/dev/kitchen-sink',
    ]);
  });

  group('app', () {
    late FakeVpnBridge bridge;

    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      String? token,
    }) async {
      bridge = FakeVpnBridge();
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(MemoryTokenStore(token)),
            initialTokenProvider.overrideWithValue(token),
            vpnBridgeProvider.overrideWithValue(bridge as VpnBridge),
            apiClientProvider.overrideWithValue(
              FakeApiClient(
                load: () async =>
                    File('../contracts/fixtures/profile/seed.json')
                        .readAsStringSync(),
              ),
            ),
            profileCacheProvider.overrideWithValue(MemoryProfileCache()),
          ],
          child: const VpnClientApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(VpnClientApp)),
      );
    }

    testWidgets('a guest starts on login', (tester) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.login), findsOneWidget);
      expect(find.byType(ModePager), findsNothing);
    });

    testWidgets('a token opens the mode screens', (tester) async {
      await pumpApp(tester, token: 'token');
      expect(find.byType(ModePager), findsOneWidget);
    });

    testWidgets('signing in and out moves between the screens', (tester) async {
      final container = await pumpApp(tester);

      await container.read(sessionProvider.notifier).signIn('token');
      await tester.pumpAndSettle();
      expect(find.byType(ModePager), findsOneWidget);

      await container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.byType(ModePager), findsNothing);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('a swipe changes the screen and leaves the tunnel alone', (
      tester,
    ) async {
      await pumpApp(tester, token: 'token');
      // The connection panel reads the tunnel state once at launch.
      final before = bridge.calls;
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      final dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.index, 1);
      expect(bridge.calls, before);
    });

    testWidgets('a dot changes the screen and leaves the tunnel alone', (
      tester,
    ) async {
      await pumpApp(tester, token: 'token');
      final before = bridge.calls;
      await tester.tap(
        find
            .descendant(
              of: find.byType(PageDots),
              matching: find.byType(InkWell),
            )
            .at(1),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<PageDots>(find.byType(PageDots)).index, 1);
      expect(bridge.calls, before);
    });

    testWidgets('the settings button opens settings', (tester) async {
      await pumpApp(tester, token: 'token');
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ModePager), findsNothing);
    });

    testWidgets('the kitchen sink renders in both themes', (tester) async {
      tester.view.physicalSize = const Size(420, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = await pumpApp(tester);

      container.read(routerProvider).go(RoutePaths.kitchenSink);
      // Fixed pumps, because progress indicators never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(KitchenSinkScreen), findsOneWidget);
      expect(find.text('power_button'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Dark theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('power_button'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
