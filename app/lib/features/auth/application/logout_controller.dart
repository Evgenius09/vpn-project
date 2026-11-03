import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../gen/api/export.dart';
import '../../profile/application/profile_controller.dart';
import 'login_controller.dart';

/// Signs the device out in the order of tech.md 26.3. Only the token removal
/// must succeed: everything before it is best effort, so a broken network or a
/// missing Windows service cannot trap the user in a session.
class LogoutController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> logout() async {
    if (state) {
      return;
    }
    state = true;
    await ref.read(authRepositoryProvider).logout();
    final bridge = ref.read(vpnBridgeProvider);
    try {
      final current = await bridge.getState();
      if (current.state?.status != TunnelStatus.disconnected) {
        await bridge.stop();
      }
    } on Object {
      // No service or no tunnel: nothing to stop.
    }
    try {
      await bridge.forgetLastRequest();
    } on Object {
      // The host already lost the request; signing out matters more.
    }
    // The cached profile holds server credentials.
    await ref.read(profileCacheProvider).clear();
    await ref.read(sessionProvider.notifier).signOut();
    ref
      ..invalidate(profileControllerProvider)
      ..invalidate(loginControllerProvider);
    state = false;
  }
}

final logoutControllerProvider = NotifierProvider<LogoutController, bool>(
  LogoutController.new,
);
