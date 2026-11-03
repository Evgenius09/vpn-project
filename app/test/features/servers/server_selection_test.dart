import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/servers/domain/server_selection.dart';
import 'package:vpnclient/gen/api/export.dart';

ProfileV1 _profile(String name) => ProfileV1.fromJson(
  jsonDecode(
    File('../contracts/fixtures/profile/$name.json').readAsStringSync(),
  ) as Map<String, Object?>,
);

ServerNode _server(int index, TunnelMode group, int weight) => ServerNode(
  id: 'srv-$index',
  group: group,
  name: 'Server $index',
  protocol: ServerProtocol.hysteria2,
  address: 'h$index.example.com',
  port: 443,
  hysteria2: const Hysteria2Params(password: 'p', serverName: 'h.example.com'),
  sortWeight: weight,
);

extension on Any {
  /// Up to eight servers with few distinct weights, so ties are common.
  Generator<List<ServerNode>> get servers =>
      list(
        combine2(
          choose(TunnelMode.values),
          intInRange(0, 3),
          (TunnelMode group, int weight) => (group, weight),
        ),
      ).map(
        (specs) => [
          for (final (index, (group, weight)) in specs.take(8).indexed)
            _server(index, group, weight),
        ],
      );

  /// A stored id: absent, one of the first servers, or one never served.
  Generator<String?> get storedId => oneOf<String?>([
    always<String?>(null),
    intInRange(0, 8).map<String?>((index) => 'srv-$index'),
    always<String?>('gone'),
  ]);
}

void main() {
  group('serversOf', () {
    test('keeps one group in catalog order', () {
      final profile = _profile('seed');

      expect(
        serversOf(profile.servers, TunnelMode.regular).map((s) => s.name),
        ['Frankfurt', 'Amsterdam', 'Helsinki'],
      );
      expect(
        serversOf(profile.servers, TunnelMode.whitelist).map((s) => s.name),
        ['Moscow', 'Saint Petersburg'],
      );
    });

    test('equal weights keep the profile order, as the core does', () {
      final servers = [
        for (var i = 0; i < 100; i++) _server(i, TunnelMode.regular, i % 2),
      ];

      final ordered = serversOf(servers, TunnelMode.regular);

      expect(ordered.map((s) => s.id), [
        for (var i = 0; i < 100; i += 2) 'srv-$i',
        for (var i = 1; i < 100; i += 2) 'srv-$i',
      ]);
    });
  });

  group('choiceIn against the profile fixtures', () {
    for (final name in ['seed', 'trial', 'expired', 'provisioning']) {
      test('$name: nothing stored gives the first server by sortWeight', () {
        final servers = _profile(name).servers;
        for (final group in TunnelMode.values) {
          final first = serversOf(servers, group).firstOrNull?.id;
          expect(choiceIn(servers, group, null), first, reason: group.json);
        }
      });
    }

    test('a stored server of the group wins', () {
      final servers = _profile('seed').servers;
      expect(
        choiceIn(servers, TunnelMode.regular, servers[2].id),
        servers[2].id,
      );
    });

    test('a stored server that left the profile falls back to the first', () {
      final servers = _profile('seed').servers;
      expect(
        choiceIn(servers, TunnelMode.regular, 'deleted-server'),
        servers.first.id,
      );
    });

    test('a stored server of the other group falls back to the first', () {
      final servers = _profile('seed').servers;
      final moscow = servers.firstWhere((s) => s.name == 'Moscow').id;
      expect(choiceIn(servers, TunnelMode.regular, moscow), servers.first.id);
    });
  });

  test('selectedIn resolves both groups and drops an empty one', () {
    final servers = [
      for (final server in _profile('seed').servers)
        if (server.group == TunnelMode.regular) server,
    ];

    final selected = selectedIn(
      servers,
      const SelectedServers(regular: 'gone', whitelist: 'gone'),
    );

    expect(selected.toJson(), {'regular': servers.first.id});
  });

  test('withChoice changes one group only', () {
    const stored = SelectedServers(regular: 'a', whitelist: 'b');

    expect(withChoice(stored, TunnelMode.whitelist, 'c').toJson(), {
      'regular': 'a',
      'whitelist': 'c',
    });
    expect(withChoice(stored, TunnelMode.regular, 'd').toJson(), {
      'regular': 'd',
      'whitelist': 'b',
    });
  });

  Glados3<List<ServerNode>, TunnelMode, String?>(
    any.servers,
    any.choose(TunnelMode.values),
    any.storedId,
  ).test('the choice is a server of its group, or none for an empty group', (
    servers,
    group,
    stored,
  ) {
    final members = servers.where((s) => s.group == group).toList();
    final choice = choiceIn(servers, group, stored);

    if (members.isEmpty) {
      expect(choice, isNull);
      return;
    }
    expect(members.map((s) => s.id), contains(choice));
    if (members.any((s) => s.id == stored)) {
      expect(choice, stored, reason: 'a stored member wins');
    } else {
      // C3: the first server of the group by sortWeight, ties in profile
      // order.
      final lowest = members.map((s) => s.sortWeight).reduce(min);
      expect(choice, members.firstWhere((s) => s.sortWeight == lowest).id);
    }
  });

  Glados2<List<ServerNode>, String?>(any.servers, any.storedId).test(
    'serversOf splits the list without losing or moving a server',
    (servers, _) {
      final regular = serversOf(servers, TunnelMode.regular);
      final whitelist = serversOf(servers, TunnelMode.whitelist);

      expect(regular.length + whitelist.length, servers.length);
      expect(regular.every((s) => s.group == TunnelMode.regular), isTrue);
      expect(whitelist.every((s) => s.group == TunnelMode.whitelist), isTrue);
      for (final ordered in [regular, whitelist]) {
        for (var i = 1; i < ordered.length; i++) {
          final a = ordered[i - 1];
          final b = ordered[i];
          expect(a.sortWeight <= b.sortWeight, isTrue);
          if (a.sortWeight == b.sortWeight) {
            expect(servers.indexOf(a) < servers.indexOf(b), isTrue);
          }
        }
      }
    },
  );
}

int min(int a, int b) => a < b ? a : b;
