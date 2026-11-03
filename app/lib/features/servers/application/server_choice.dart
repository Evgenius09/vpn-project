import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/api/export.dart';
import '../../connection/application/connection_controller.dart';
import 'selection_controller.dart';

/// Whether a tap on a server tile counts. While the tunnel connects or
/// disconnects, or a bridge call is in flight, the core would ignore a
/// selectServer and the running server would differ from the highlighted
/// one, so taps wait, like the PowerButton (tech.md 2.1, 28.2).
final serverTapsEnabledProvider = Provider<bool>((ref) {
  final connection = ref.watch(connectionControllerProvider);
  return !connection.busy &&
      connection.tunnel.status != TunnelStatus.connecting &&
      connection.tunnel.status != TunnelStatus.disconnecting;
});

/// Applies a tap on a server tile: stores the choice of its group and moves a
/// running tunnel to it.
class ServerChoice {
  const ServerChoice(this._ref);

  final Ref _ref;

  Future<void> choose(TunnelMode group, String serverId) async {
    if (!_ref.read(serverTapsEnabledProvider)) {
      return;
    }
    await _ref
        .read(selectionControllerProvider.notifier)
        .remember(group, serverId);
    await _ref
        .read(connectionControllerProvider.notifier)
        .selectServer(group, serverId);
  }
}

final serverChoiceProvider = Provider<ServerChoice>(ServerChoice.new);
