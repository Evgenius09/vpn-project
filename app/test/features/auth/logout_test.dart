import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/features/auth/presentation/login_screen.dart';
import 'package:vpnclient/features/auth/presentation/settings_screen.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/ui/ui.dart';

import 'auth_harness.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

Future<void> logOut(WidgetTester tester, {bool confirm = true}) async {
  await tester.tap(find.text('Log out'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirm ? 'Log out now' : 'Cancel'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings offer a logout button', (tester) async {
    await AuthHarness(token: 't').pump(tester);
    await openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('logout revokes the device and forgets every secret', (
    tester,
  ) async {
    final harness = AuthHarness(token: 't');
    await harness.pump(tester);
    expect(harness.cache.value, isNotNull, reason: 'the profile was cached');
    await openSettings(tester);

    await logOut(tester);

    expect(harness.api.logouts, 1);
    expect(harness.bridge.calls, contains('forgetLastRequest'));
    expect(await harness.tokens.read(), isNull);
    expect(harness.cache.value, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('logout stops a running tunnel before forgetting the request', (
    tester,
  ) async {
    final harness = AuthHarness(token: 't');
    await harness.pump(tester);
    await harness.bridge.start(_tunnelRequest);
    await openSettings(tester);

    await logOut(tester);

    final calls = harness.bridge.calls;
    expect(calls.indexOf('stop'), greaterThan(calls.indexOf('start')));
    expect(
      calls.indexOf('forgetLastRequest'),
      greaterThan(calls.indexOf('stop')),
    );
  });

  testWidgets('an unreachable server does not block logout', (tester) async {
    final harness = AuthHarness(token: 't');
    await harness.pump(tester);
    harness.api.authFailure = const ApiUnavailable();
    await openSettings(tester);

    await logOut(tester);

    expect(await harness.tokens.read(), isNull);
    expect(harness.bridge.calls, contains('forgetLastRequest'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('cancel keeps the session', (tester) async {
    final harness = AuthHarness(token: 't');
    await harness.pump(tester);
    await openSettings(tester);

    await logOut(tester, confirm: false);

    expect(harness.api.logouts, 0);
    expect(await harness.tokens.read(), 't');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the next login starts at the nick and loads a fresh profile', (
    tester,
  ) async {
    final harness = AuthHarness(token: 't');
    await harness.pump(tester);
    await openSettings(tester);
    await logOut(tester);
    final fetchesBefore = harness.api.fetches;

    expect(find.byType(AppTextField), findsOneWidget);
    await enterUsername(tester, 'seed_user');
    await enterCode(tester, '123456');

    expect(find.byType(ModePager), findsOneWidget);
    expect(harness.api.fetches, greaterThan(fetchesBefore));
    expect(harness.cache.value, isA<CachedProfile>());
  });
}

String get _tunnelRequest =>
    File('../contracts/fixtures/tunnel_request/android_regular.json')
        .readAsStringSync();
