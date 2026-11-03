import '../../../gen/api/export.dart';
import '../../../ui/ui.dart';
import '../domain/connection_state.dart';

/// What a tap on the PowerButton of one mode screen does (tech.md 2.1).
sealed class PowerAction {
  const PowerAction();
}

final class StartTunnel extends PowerAction {
  const StartTunnel(this.mode);

  final TunnelMode mode;

  @override
  bool operator ==(Object other) => other is StartTunnel && other.mode == mode;

  @override
  int get hashCode => Object.hash(StartTunnel, mode);
}

final class StopTunnel extends PowerAction {
  const StopTunnel();

  @override
  bool operator ==(Object other) => other is StopTunnel;

  @override
  int get hashCode => (StopTunnel).hashCode;
}

/// Moves the running tunnel to another mode without reconnecting.
final class SwitchUserMode extends PowerAction {
  const SwitchUserMode(this.mode);

  final TunnelMode mode;

  @override
  bool operator ==(Object other) =>
      other is SwitchUserMode && other.mode == mode;

  @override
  int get hashCode => Object.hash(SwitchUserMode, mode);
}

class PowerView {
  const PowerView(this.state, this.action, {this.activeElsewhere});

  final PowerState state;

  /// Null when a tap must do nothing.
  final PowerAction? action;

  /// The mode that runs while this screen shows idle.
  final TunnelMode? activeElsewhere;
}

/// The PowerButton of the [screen] mode screen. [busy] means a bridge call is
/// in flight. [canStart] is false until a profile with servers is loaded,
/// because a start needs one, while a stop never does.
PowerView powerViewFor(
  TunnelMode screen,
  TunnelSnapshot tunnel, {
  bool busy = false,
  bool canStart = true,
}) {
  PowerAction? unlessBusy(PowerAction action) => busy ? null : action;
  final start = canStart ? unlessBusy(StartTunnel(screen)) : null;
  return switch (tunnel.status) {
    TunnelStatus.disconnected => PowerView(PowerState.idle, start),
    TunnelStatus.error => PowerView(
      tunnel.userMode == screen ? PowerState.error : PowerState.idle,
      start,
    ),
    TunnelStatus.connecting => const PowerView(PowerState.connecting, null),
    TunnelStatus.disconnecting => const PowerView(
      PowerState.disconnecting,
      null,
    ),
    TunnelStatus.connected when tunnel.effectiveMode == screen => PowerView(
      PowerState.connected,
      unlessBusy(const StopTunnel()),
    ),
    TunnelStatus.connected => PowerView(
      PowerState.idle,
      unlessBusy(SwitchUserMode(screen)),
      activeElsewhere: tunnel.effectiveMode,
    ),
  };
}
