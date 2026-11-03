import 'dart:async';

import 'package:vpnclient/core/vpn/fake_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/features/ping/data/tcp_ping.dart';
import 'package:vpnclient/features/ping/domain/server_ping.dart';
import 'package:vpnclient/gen/api/export.dart';

/// Answers every TCP ping with the same delay at once, so lists keep the
/// sortWeight order and spinners settle in widget tests.
class InstantTcpPing implements TcpPing {
  InstantTcpPing([this.answer = const ServerPing.delay(50)]);

  final ServerPing answer;
  final hosts = <String>[];
  final timeouts = <Duration>[];

  @override
  Future<ServerPing> ping(String host, int port, Duration timeout) async {
    hosts.add(host);
    timeouts.add(timeout);
    return answer;
  }
}

/// Holds every ping until [release], and counts how many wait at once.
class GatedTcpPing implements TcpPing {
  GatedTcpPing(this.answers);

  /// The delay of each host; a host without one is unreachable.
  final Map<String, ServerPing> answers;
  final _gate = Completer<void>();
  final hosts = <String>[];
  int inFlight = 0;
  int peak = 0;

  void release() => _gate.complete();

  @override
  Future<ServerPing> ping(String host, int port, Duration timeout) async {
    hosts.add(host);
    inFlight++;
    peak = inFlight > peak ? inFlight : peak;
    await _gate.future;
    inFlight--;
    return answers[host] ?? const ServerPing.unreachable();
  }
}

/// Records urlTest calls and answers them from [urlTestAnswer].
class UrlTestBridge extends FakeVpnBridge {
  final urlTests = <List<String>>[];
  UrlTestPayload? urlTestAnswer;
  VpnBridgeException? urlTestError;

  @override
  Future<CoreEvent> urlTest(List<String> serverIds) async {
    urlTests.add(serverIds);
    final error = urlTestError;
    if (error != null) {
      throw error;
    }
    final answer = urlTestAnswer;
    if (answer == null) {
      return super.urlTest(serverIds);
    }
    return CoreEvent(
      type: CoreEventType.urlTest,
      at: DateTime.utc(2026, 11, 3),
      urlTest: answer,
    );
  }

  void emitStatus(TunnelStatus status) => emit(
    CoreEvent(
      type: CoreEventType.state,
      at: DateTime.utc(2026, 11, 3),
      state: StatePayload(
        status: status,
        userMode: TunnelMode.regular,
        effectiveMode: TunnelMode.regular,
      ),
    ),
  );
}
