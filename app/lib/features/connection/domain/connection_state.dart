import '../../../gen/api/export.dart';

/// The tunnel as the last state event described it (tech.md 5.5).
class TunnelSnapshot {
  const TunnelSnapshot({
    required this.status,
    required this.userMode,
    required this.effectiveMode,
    this.connectedSince,
  });

  factory TunnelSnapshot.fromPayload(StatePayload payload) => TunnelSnapshot(
    status: payload.status,
    userMode: payload.userMode,
    effectiveMode: payload.effectiveMode,
    connectedSince: payload.connectedSince,
  );

  static const disconnected = TunnelSnapshot(
    status: TunnelStatus.disconnected,
    userMode: TunnelMode.regular,
    effectiveMode: TunnelMode.regular,
  );

  final TunnelStatus status;
  final TunnelMode userMode;
  final TunnelMode effectiveMode;
  final DateTime? connectedSince;
}

/// What the mode screens show about the tunnel.
class ConnectionState {
  const ConnectionState({
    this.tunnel = TunnelSnapshot.disconnected,
    this.traffic,
    this.issue,
    this.notice,
    this.busy = false,
  });

  final TunnelSnapshot tunnel;

  /// The last traffic sample, only while connected.
  final TrafficPayload? traffic;

  /// The failure the banner explains. A denied VPN permission arrives as
  /// permission_denied, so one code covers the host, the service, and the core.
  final CoreErrorCode? issue;

  /// The last mode change the auto switch made, for its banner (tech.md 34.2).
  final ModePayload? notice;

  /// A call to the bridge is in flight, so taps wait for it.
  final bool busy;

  ConnectionState copyWith({TunnelSnapshot? tunnel, bool? busy}) =>
      ConnectionState(
        tunnel: tunnel ?? this.tunnel,
        traffic: traffic,
        issue: issue,
        notice: notice,
        busy: busy ?? this.busy,
      );

  ConnectionState withTraffic(TrafficPayload? traffic) => ConnectionState(
    tunnel: tunnel,
    traffic: traffic,
    issue: issue,
    notice: notice,
    busy: busy,
  );

  ConnectionState withIssue(CoreErrorCode? issue) => ConnectionState(
    tunnel: tunnel,
    traffic: traffic,
    issue: issue,
    notice: notice,
    busy: busy,
  );

  ConnectionState withNotice(ModePayload? notice) => ConnectionState(
    tunnel: tunnel,
    traffic: traffic,
    issue: issue,
    notice: notice,
    busy: busy,
  );
}
