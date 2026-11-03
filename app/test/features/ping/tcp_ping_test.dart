import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/ping/data/tcp_ping.dart';
import 'package:vpnclient/features/ping/domain/bounded.dart';
import 'package:vpnclient/features/ping/domain/server_ping.dart';

void main() {
  group('forEachBounded', () {
    test('never runs more than the limit, and reaches it', () async {
      final gate = Completer<void>();
      var inFlight = 0;
      var peak = 0;
      final done = <int>[];

      final run = forEachBounded<int>(List.generate(20, (i) => i), 8, (
        item,
      ) async {
        inFlight++;
        peak = inFlight > peak ? inFlight : peak;
        // Every task waits on the same gate, so they pile up together.
        await gate.future;
        inFlight--;
        done.add(item);
      });

      await pumpEventQueue();
      expect(inFlight, 8);
      gate.complete();
      await run;

      expect(peak, 8);
      expect(done..sort(), List.generate(20, (i) => i));
    });

    test('a failing task does not stop the others', () async {
      final done = <int>[];
      await forEachBounded<int>([1, 2, 3], 2, (item) async {
        if (item == 1) {
          throw StateError('boom');
        }
        done.add(item);
      });
      expect(done, [2, 3]);
    });

    test('an empty list finishes at once', () async {
      await forEachBounded<int>(const [], 8, (_) async {});
    });
  });

  group('SocketTcpPing', () {
    test('a listening port gives a delay', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());

      final ping = await SocketTcpPing().ping(
        '127.0.0.1',
        server.port,
        const Duration(seconds: 3),
      );

      expect(ping, isA<DelayPing>());
      expect((ping as DelayPing).ms, greaterThanOrEqualTo(0));
    });

    test('a closed port is unreachable', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();

      final ping = await SocketTcpPing().ping(
        '127.0.0.1',
        port,
        const Duration(seconds: 3),
      );

      expect(ping, const ServerPing.unreachable());
    });

    test(
      'a connect that never answers is unreachable after the timeout',
      () async {
        final pending = Completer<Socket>();
        final watch = Stopwatch()..start();

        final ping = await SocketTcpPing(
          connect: (host, port, {timeout}) => pending.future,
        ).ping('203.0.113.1', 443, const Duration(milliseconds: 100));

        expect(ping, const ServerPing.unreachable());
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );

    test('the timeout reaches the connect call', () async {
      Duration? passed;
      await SocketTcpPing(
        connect: (host, port, {timeout}) async {
          passed = timeout;
          throw const SocketException('refused');
        },
      ).ping('example.com', 443, const Duration(milliseconds: 1500));

      expect(passed, const Duration(milliseconds: 1500));
    });
  });
}
