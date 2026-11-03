import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/ping/domain/server_ping.dart';
import 'package:vpnclient/features/ping/domain/sort_servers.dart';
import 'package:vpnclient/gen/api/export.dart';

ServerNode _server(int index, int weight) => ServerNode(
  id: 'srv-$index',
  group: TunnelMode.regular,
  name: 'Server $index',
  protocol: ServerProtocol.hysteria2,
  address: 'h$index.example.com',
  port: 443,
  hysteria2: const Hysteria2Params(password: 'p', serverName: 'h.example.com'),
  sortWeight: weight,
);

extension on Any {
  /// A ping of any kind, with few distinct delays so ties are common.
  Generator<ServerPing> get ping => oneOf<ServerPing>([
    always<ServerPing>(const ServerPing.unknown()),
    always<ServerPing>(const ServerPing.measuring()),
    always<ServerPing>(const ServerPing.unreachable()),
    intInRange(0, 4).map<ServerPing>((ms) => ServerPing.delay(ms * 50)),
  ]);

  /// Up to twelve servers with few distinct weights and a ping for each, or
  /// none at all when the map has no entry.
  Generator<(List<ServerNode>, Map<String, ServerPing>)> get pinged =>
      list(
        combine3(
          intInRange(0, 3),
          ping,
          intInRange(0, 5),
          (int weight, ServerPing ping, int present) => (weight, ping, present),
        ),
      ).map((specs) {
        final servers = <ServerNode>[];
        final pings = <String, ServerPing>{};
        for (final (index, (weight, ping, present)) in specs.take(12).indexed) {
          servers.add(_server(index, weight));
          // One in five servers has no entry yet.
          if (present > 0) {
            pings['srv-$index'] = ping;
          }
        }
        return (servers, pings);
      });
}

/// The order the list has with sorting off: weight, then the input order.
List<String> _byWeight(List<ServerNode> servers) {
  final indexed = servers.indexed.toList()
    ..sort((a, b) {
      final byWeight = a.$2.sortWeight.compareTo(b.$2.sortWeight);
      return byWeight != 0 ? byWeight : a.$1.compareTo(b.$1);
    });
  return [for (final (_, server) in indexed) server.id];
}

ServerPing _pingOf(Map<String, ServerPing> pings, ServerNode server) =>
    pings[server.id] ?? const ServerPing.unknown();

bool _notMeasured(ServerPing ping) =>
    ping is UnknownPing || ping is MeasuringPing;

void main() {
  test('sorted by delay, then not measured, then unreachable', () {
    final servers = [for (var i = 0; i < 5; i++) _server(i, 0)];
    final pings = <String, ServerPing>{
      'srv-0': const ServerPing.unreachable(),
      'srv-1': const ServerPing.delay(90),
      'srv-2': const ServerPing.measuring(),
      'srv-4': const ServerPing.delay(30),
    };

    final sorted = sortServers(servers, pings, byPing: true);

    expect(sorted.map((s) => s.id), [
      'srv-4',
      'srv-1',
      'srv-2',
      'srv-3',
      'srv-0',
    ]);
  });

  test('switched off it keeps the sortWeight order whatever the ping', () {
    final servers = [_server(0, 3), _server(1, 1), _server(2, 2)];
    final pings = <String, ServerPing>{
      'srv-0': const ServerPing.delay(1),
      'srv-1': const ServerPing.unreachable(),
    };

    final sorted = sortServers(servers, pings, byPing: false);

    expect(sorted.map((s) => s.id), ['srv-1', 'srv-2', 'srv-0']);
  });

  // Short lists sort stably by chance, so this one is long.
  test('equal pings and weights keep the input order in a long list', () {
    final servers = [for (var i = 0; i < 100; i++) _server(i, i % 2)];
    final pings = {
      for (final server in servers) server.id: const ServerPing.delay(40),
    };

    for (final byPing in [true, false]) {
      expect(sortServers(servers, pings, byPing: byPing).map((s) => s.id), [
        for (var i = 0; i < 100; i += 2) 'srv-$i',
        for (var i = 1; i < 100; i += 2) 'srv-$i',
      ]);
    }
  });

  Glados2<(List<ServerNode>, Map<String, ServerPing>), bool>(
    any.pinged,
    any.bool,
  ).test('the result is a permutation of the input', (input, byPing) {
    final (servers, pings) = input;

    final sorted = sortServers(servers, pings, byPing: byPing);

    expect(sorted.length, servers.length);
    expect(
      sorted.map((s) => s.id).toList()..sort(),
      servers.map((s) => s.id).toList()..sort(),
    );
  });

  Glados(any.pinged).test('unreachable servers come last', (input) {
    final (servers, pings) = input;

    final sorted = sortServers(servers, pings, byPing: true);

    final firstUnreachable = sorted.indexWhere(
      (s) => _pingOf(pings, s) is UnreachablePing,
    );
    if (firstUnreachable >= 0) {
      expect(
        sorted
            .skip(firstUnreachable)
            .every((s) => _pingOf(pings, s) is UnreachablePing),
        isTrue,
      );
    }
  });

  Glados(any.pinged)
      .test('measured servers come first, fastest first', (input) {
        final (servers, pings) = input;

        final sorted = sortServers(servers, pings, byPing: true);

        final delays = [
          for (final server in sorted.takeWhile(
            (s) => _pingOf(pings, s) is DelayPing,
          ))
            (_pingOf(pings, server) as DelayPing).ms,
        ];
        final measured = servers.where((s) => _pingOf(pings, s) is DelayPing);
        expect(delays.length, measured.length);
        expect(delays, [...delays]..sort());
      });

  Glados(any.pinged).test('equal pings keep the sortWeight order', (input) {
    final (servers, pings) = input;
    final weightOrder = _byWeight(servers);

    final sorted = sortServers(servers, pings, byPing: true);

    // Any two servers with the same ping keep their order with sorting off.
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = _pingOf(pings, sorted[i]);
        final b = _pingOf(pings, sorted[j]);
        if (a == b || (_notMeasured(a) && _notMeasured(b))) {
          expect(
            weightOrder.indexOf(sorted[i].id) <
                weightOrder.indexOf(sorted[j].id),
            isTrue,
            reason: '${sorted[i].id} before ${sorted[j].id}',
          );
        }
      }
    }
  });

  Glados(any.pinged)
      .test('switched off it keeps the sortWeight order', (input) {
        final (servers, pings) = input;

        final sorted = sortServers(servers, pings, byPing: false);

        expect(sorted.map((s) => s.id), _byWeight(servers));
      });
}
