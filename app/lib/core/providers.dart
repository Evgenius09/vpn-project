import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen/api/export.dart';
import 'api/api_client.dart';
import 'config/app_config.dart';
import 'storage/token_store.dart';
import 'vpn/fake_vpn_bridge.dart';
import 'vpn/pigeon_vpn_bridge.dart';
import 'vpn/pipe_transport_windows.dart';
import 'vpn/pipe_vpn_bridge.dart';
import 'vpn/vpn_bridge.dart';

const appVersion = '0.1.0';
const windowsPipeName = r'\\.\pipe\vpnclient-core';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The token read at startup. main overrides it after reading the store, so
/// the router knows the session before the first frame.
final initialTokenProvider = Provider<String?>((ref) => null);

/// Whether a device token exists.
class SessionNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialTokenProvider) != null;

  Future<void> signIn(String token) async {
    await ref.read(tokenStoreProvider).write(token);
    state = true;
  }

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).delete();
    state = false;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, bool>(
  SessionNotifier.new,
);

final apiClientProvider = Provider<VpnApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return createApiClient(
    baseUrl: config.apiBaseUrls.first,
    tokens: ref.watch(tokenStoreProvider),
  );
});

/// The bridge of this platform, or null where none exists.
VpnBridge? createPlatformBridge() {
  if (io.Platform.isAndroid) {
    return PigeonVpnBridge();
  }
  if (io.Platform.isWindows) {
    return PipeVpnBridge(
      connect: () => Win32PipeTransport.connect(windowsPipeName),
      appVersion: appVersion,
    );
  }
  return null;
}

final vpnBridgeProvider = Provider<VpnBridge>((ref) {
  final platform = ref.watch(appConfigProvider).fakeVpn
      ? null
      : createPlatformBridge();
  if (platform != null) {
    return platform;
  }
  final bridge = FakeVpnBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});
