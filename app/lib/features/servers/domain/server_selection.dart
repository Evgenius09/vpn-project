import '../../../gen/api/export.dart';

/// The servers of [group] by sortWeight. Equal weights keep the profile
/// order, the same order the core picks its default from (C3).
List<ServerNode> serversOf(List<ServerNode> servers, TunnelMode group) {
  final indexed = [
    for (final (index, server) in servers.indexed)
      if (server.group == group) (index, server),
  ];
  // List.sort is not stable, so the index breaks ties.
  indexed.sort((a, b) {
    final byWeight = a.$2.sortWeight.compareTo(b.$2.sortWeight);
    return byWeight != 0 ? byWeight : a.$1.compareTo(b.$1);
  });
  return [for (final (_, server) in indexed) server];
}

/// The server of [group] to use: [stored] while the profile holds it in that
/// group, otherwise the first server of the group (tech.md 28.2). Null for an
/// empty group.
String? choiceIn(List<ServerNode> servers, TunnelMode group, String? stored) {
  if (stored != null &&
      servers.any((server) => server.id == stored && server.group == group)) {
    return stored;
  }
  return serversOf(servers, group).firstOrNull?.id;
}

/// [stored] resolved for both groups, as `TunnelRequest.selected` carries it.
SelectedServers selectedIn(List<ServerNode> servers, SelectedServers stored) =>
    SelectedServers(
      regular: choiceIn(servers, TunnelMode.regular, stored.regular),
      whitelist: choiceIn(servers, TunnelMode.whitelist, stored.whitelist),
    );

String? storedFor(SelectedServers stored, TunnelMode group) => switch (group) {
  TunnelMode.regular => stored.regular,
  TunnelMode.whitelist => stored.whitelist,
};

/// [stored] with [serverId] chosen in [group] and the other group untouched.
SelectedServers withChoice(
  SelectedServers stored,
  TunnelMode group,
  String serverId,
) => switch (group) {
  TunnelMode.regular => SelectedServers(
    regular: serverId,
    whitelist: stored.whitelist,
  ),
  TunnelMode.whitelist => SelectedServers(
    regular: stored.regular,
    whitelist: serverId,
  ),
};
