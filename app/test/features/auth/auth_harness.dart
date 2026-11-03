import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/app/app.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/device/device_identity.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/core/vpn/fake_vpn_bridge.dart';
import 'package:vpnclient/features/auth/application/login_controller.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/gen/api/export.dart';

const testIdentity = DeviceIdentity(
  platform: Platform.windows,
  model: 'Windows 11 Pro',
  installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
);

/// The whole app over fakes, so a test walks the same routes as a user.
class AuthHarness {
  AuthHarness({String? token}) : tokens = MemoryTokenStore(token);

  final api = FakeApiClient(
    load: () async =>
        File('../contracts/fixtures/profile/seed.json').readAsStringSync(),
  );
  final MemoryTokenStore tokens;
  final bridge = FakeVpnBridge();
  final cache = MemoryProfileCache();
  final opened = <Uri>[];
  bool openSucceeds = true;

  Future<void> pump(WidgetTester tester) async {
    final token = await tokens.read();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(tokens),
          initialTokenProvider.overrideWithValue(token),
          vpnBridgeProvider.overrideWithValue(bridge),
          profileCacheProvider.overrideWithValue(cache),
          deviceIdentityProvider.overrideWith((ref) async => testIdentity),
          urlOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return openSucceeds;
          }),
        ],
        child: const VpnClientApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> enterUsername(WidgetTester tester, String username) async {
  await tester.enterText(find.byType(TextField), username);
  await tester.tap(find.text('Get code'));
  await tester.pumpAndSettle();
}

Future<void> enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pumpAndSettle();
}
