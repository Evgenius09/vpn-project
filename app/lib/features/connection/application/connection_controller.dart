import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity.dart';
import '../../../core/providers.dart';
import '../../../core/vpn/vpn_bridge.dart';
import '../../../gen/api/export.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../../servers/application/selection_controller.dart';
import '../domain/connection_state.dart';
import '../domain/tunnel_request.dart';
import 'power_view.dart';

/// The current UTC time, replaceable in tests.
final connectionClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// Ticks once a second while a screen shows the connection timer.
final connectionTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(connectionClockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock());
});

/// Follows the core through VpnBridge and turns PowerButton taps into bridge
/// calls by the table of tech.md 2.1.
class ConnectionController extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    final bridge = ref.watch(vpnBridgeProvider);
    final subscription = bridge.events.listen(_onEvent);
    ref.onDispose(subscription.cancel);
    unawaited(Future.microtask(() => _readState(bridge)));
    return const ConnectionState();
  }

  /// A tunnel may already run: always-on, autostart, or the Windows service
  /// outliving the UI.
  Future<void> _readState(VpnBridge bridge) async {
    try {
      _onEvent(await bridge.getState());
    } on Object {
      // No service yet. A tap explains it through prepare.
    }
  }

  void _onEvent(CoreEvent event) {
    if (!ref.mounted) {
      return;
    }
    switch (event.type) {
      case CoreEventType.state:
        final payload = event.state;
        if (payload == null) {
          return;
        }
        final tunnel = TunnelSnapshot.fromPayload(payload);
        var next = state.copyWith(tunnel: tunnel);
        if (tunnel.status != TunnelStatus.connected) {
          next = next.withTraffic(null);
        } else {
          next = next.withIssue(null);
        }
        state = next;
      case CoreEventType.traffic:
        if (state.tunnel.status == TunnelStatus.connected) {
          state = state.withTraffic(event.traffic);
        }
      case CoreEventType.error:
        final error = event.error;
        if (error != null) {
          state = state.withIssue(error.code);
        }
      case CoreEventType.mode || CoreEventType.urlTest:
        // S2-05 shows mode changes; effectiveMode arrives with state.
        break;
    }
  }

  /// Whether a start has a profile to build the request from.
  bool get canStart => ref.read(profileControllerProvider) is ProfileReady;

  PowerView viewFor(TunnelMode screen) =>
      powerViewFor(screen, state.tunnel, busy: state.busy, canStart: canStart);

  Future<void> tap(TunnelMode screen) async {
    final action = viewFor(screen).action;
    final bridge = ref.read(vpnBridgeProvider);
    switch (action) {
      case null:
        return;
      case StartTunnel(:final mode):
        await _start(bridge, mode);
      case StopTunnel():
        await _call(bridge.stop);
      case SwitchUserMode(:final mode):
        await _call(() => bridge.setUserMode(mode));
    }
  }

  Future<void> _start(VpnBridge bridge, TunnelMode mode) async {
    final profile = ref.read(profileControllerProvider);
    if (profile is! ProfileReady || !hasServersIn(profile.profile, mode)) {
      state = state.withIssue(CoreErrorCode.noServersInGroup);
      return;
    }
    await _call(() async {
      if (await bridge.prepare() == VpnPrepareResult.denied) {
        throw const VpnBridgeException(CoreErrorCode.permissionDenied);
      }
      final identity = await ref.read(deviceIdentityProvider.future);
      final choice = await ref.read(selectionControllerProvider.future);
      final request = buildTunnelRequest(
        platform: identity.platform,
        userMode: mode,
        profile: profile.profile,
        choice: choice,
      );
      await bridge.start(jsonEncode(request.toJson()));
    });
  }

  /// Moves the running tunnel of [group] to [serverId] without a reconnect.
  /// Either group, so a later setUserMode lands on the chosen server. Outside
  /// connected the core ignores it, and the next start carries the choice
  /// (tech.md 22.1, 28.2).
  Future<void> selectServer(TunnelMode group, String serverId) async {
    if (state.tunnel.status != TunnelStatus.connected) {
      return;
    }
    await _call(
      () => ref.read(vpnBridgeProvider).selectServer(group, serverId),
    );
  }

  /// Runs one bridge call with taps held and turns its failure into a banner.
  Future<void> _call(Future<void> Function() call) async {
    state = state.withIssue(null).copyWith(busy: true);
    try {
      await call();
    } on VpnBridgeException catch (error) {
      if (ref.mounted) {
        state = state.withIssue(error.code);
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }
}

final connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionState>(
      ConnectionController.new,
    );
