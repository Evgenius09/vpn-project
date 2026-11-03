import 'dart:async';
import 'dart:io';

import '../domain/server_ping.dart';

/// Measures how long a TCP connection to a server takes (tech.md 31.2).
abstract interface class TcpPing {
  Future<ServerPing> ping(String host, int port, Duration timeout);
}

typedef SocketConnect = Future<Socket> Function(
  Object host,
  int port, {
  Duration? timeout,
});

class SocketTcpPing implements TcpPing {
  SocketTcpPing({SocketConnect? connect})
    : _connect = connect ?? Socket.connect;

  final SocketConnect _connect;

  /// Any failure, a refused port as much as a timeout, means unreachable.
  @override
  Future<ServerPing> ping(String host, int port, Duration timeout) async {
    final watch = Stopwatch()..start();
    final connecting = _connect(host, port, timeout: timeout);
    try {
      // The outer timeout also covers a name lookup that hangs.
      final socket = await connecting.timeout(timeout);
      final ms = watch.elapsedMilliseconds;
      socket.destroy();
      return ServerPing.delay(ms);
    } on TimeoutException {
      // A late connection must not stay open.
      unawaited(
        connecting.then((socket) => socket.destroy(), onError: (Object _) {}),
      );
      return const ServerPing.unreachable();
    } on Object {
      return const ServerPing.unreachable();
    }
  }
}
