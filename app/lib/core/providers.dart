import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen/api/export.dart';
import 'api/api_client.dart';
import 'config/app_config.dart';
import 'storage/token_store.dart';
import 'vpn/fake_vpn_bridge.dart';
import 'vpn/vpn_bridge.dart';

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

/// S0-06 and S0-07 add the Android and Windows bridges here.
final vpnBridgeProvider = Provider<VpnBridge>((ref) {
  final bridge = FakeVpnBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});
