import '../../../gen/api/export.dart';
import 'server_ping.dart';

/// [servers] in list order (tech.md 31.2). With [byPing], measured servers
/// come first by delay, then servers without a result, then unreachable ones.
/// Servers that rank the same keep the sortWeight order, and equal weights
/// keep the input order, so the list does not jump between equal pings.
List<ServerNode> sortServers(
  List<ServerNode> servers,
  Map<String, ServerPing> pings, {
  required bool byPing,
}) {
  final indexed = servers.indexed.toList();
  // List.sort is not stable, so the index breaks the last tie.
  indexed.sort((a, b) {
    if (byPing) {
      final byRank = _rank(pings[a.$2.id]).compareTo(_rank(pings[b.$2.id]));
      if (byRank != 0) {
        return byRank;
      }
    }
    final byWeight = a.$2.sortWeight.compareTo(b.$2.sortWeight);
    return byWeight != 0 ? byWeight : a.$1.compareTo(b.$1);
  });
  return [for (final (_, server) in indexed) server];
}

/// Below 2^31 every delay sorts before the servers without one.
const _notMeasured = 1 << 31;
const _unreachable = _notMeasured + 1;

int _rank(ServerPing? ping) => switch (ping) {
  DelayPing(:final ms) => ms,
  UnreachablePing() => _unreachable,
  UnknownPing() || MeasuringPing() || null => _notMeasured,
};
