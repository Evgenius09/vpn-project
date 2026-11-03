import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../gen/api/export.dart';
import '../../connection/application/connection_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../../servers/domain/server_selection.dart';
import '../data/tcp_ping.dart';
import '../data/user_settings_store.dart';
import '../domain/bounded.dart';
import '../domain/ping_settings.dart';
import '../domain/server_ping.dart';
import '../domain/sort_servers.dart';

/// At most this many TCP pings run at once (tech.md 16 S1-12).
const tcpPingParallel = 8;

final tcpPingProvider = Provider<TcpPing>((ref) => SocketTcpPing());

/// The last ping of every server and whether a run is going on.
class PingState {
  const PingState({this.pings = const {}, this.running = false});

  final Map<String, ServerPing> pings;
  final bool running;

  PingState copyWith({Map<String, ServerPing>? pings, bool? running}) =>
      PingState(pings: pings ?? this.pings, running: running ?? this.running);
}

/// Pings the servers of the profile (tech.md 31.2): once on open by
/// `ping.onOpen`, and again on each refresh.
class PingController extends Notifier<PingState> {
  bool _opened = false;

  @override
  PingState build() {
    ref.listen<ProfileState>(profileControllerProvider, (_, next) {
      if (_opened || next is! ProfileReady || next.profile.servers.isEmpty) {
        return;
      }
      _opened = true;
      if (pingSettingsFrom(next.profile.policy).onOpen) {
        // A notifier must not change its state while it builds.
        unawaited(Future.microtask(run));
      }
    }, fireImmediately: true);
    return const PingState();
  }

  Future<void> run() async {
    final profile = ref.read(profileControllerProvider);
    if (state.running || profile is! ProfileReady) {
      return;
    }
    final servers = profile.profile.servers;
    if (servers.isEmpty) {
      return;
    }
    final settings = pingSettingsFrom(profile.profile.policy);
    state = PingState(
      pings: {
        ...state.pings,
        for (final server in servers) server.id: const ServerPing.measuring(),
      },
      running: true,
    );
    try {
      if (!await _urlTest(settings, servers)) {
        await _tcp(settings, servers);
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(running: false);
      }
    }
  }

  /// The core measures through the tunnel, so it answers only while
  /// connected (tech.md 5.6). False sends the run to TCP.
  Future<bool> _urlTest(PingSettings settings, List<ServerNode> servers) async {
    final status = ref.read(connectionControllerProvider).tunnel.status;
    if (settings.type != PingType.urlTest || status != TunnelStatus.connected) {
      return false;
    }
    final CoreEvent event;
    try {
      event = await ref.read(vpnBridgeProvider).urlTest([
        for (final server in servers) server.id,
      ]);
    } on Object {
      return false;
    }
    final results = {
      for (final result in event.urlTest?.results ?? const <UrlTestResult>[])
        result.serverId: result,
    };
    if (!ref.mounted) {
      return true;
    }
    state = state.copyWith(
      pings: {
        ...state.pings,
        for (final server in servers)
          server.id: switch (results[server.id]) {
            null => const ServerPing.unknown(),
            UrlTestResult(:final delayMs?) => ServerPing.delay(delayMs),
            UrlTestResult() => const ServerPing.unreachable(),
          },
      },
    );
    return true;
  }

  Future<void> _tcp(PingSettings settings, List<ServerNode> servers) async {
    final tcp = ref.read(tcpPingProvider);
    await forEachBounded(servers, tcpPingParallel, (server) async {
      // Hysteria2 listens on UDP only, so a TCP connect says nothing.
      final ping = server.protocol == ServerProtocol.hysteria2
          ? const ServerPing.unknown()
          : await tcp.ping(server.address, server.port, settings.timeout);
      if (ref.mounted) {
        state = state.copyWith(pings: {...state.pings, server.id: ping});
      }
    });
  }
}

final pingControllerProvider = NotifierProvider<PingController, PingState>(
  PingController.new,
);

/// The user's own `ui.sortByPing`, null until they touch the toggle.
class SortChoiceController extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() async =>
      (await ref.read(userSettingsStoreProvider).read()).ui?.sortByPing;

  Future<void> choose(bool value) async {
    state = AsyncData(value);
    final store = ref.read(userSettingsStoreProvider);
    await store.write(withSortByPing(await store.read(), value));
  }
}

final sortChoiceProvider = AsyncNotifierProvider<SortChoiceController, bool?>(
  SortChoiceController.new,
);

ClientPolicy? _policyOf(ProfileState state) =>
    state is ProfileReady ? state.profile.policy : null;

/// Whether the lists sort by ping (tech.md 31.2).
final sortByPingProvider = Provider<bool>((ref) {
  final policy = _policyOf(ref.watch(profileControllerProvider));
  final choice = ref.watch(sortChoiceProvider).value;
  if (policy == null) {
    return choice ?? builtInSortByPing;
  }
  return sortByPingFrom(policy, choice);
});

final sortByPingLockedProvider = Provider<bool>((ref) {
  final policy = _policyOf(ref.watch(profileControllerProvider));
  return policy != null && sortByPingLocked(policy);
});

/// The servers of [group] in the order the list shows them.
final orderedServersProvider = Provider.family<List<ServerNode>, TunnelMode>((
  ref,
  group,
) {
  final profile = ref.watch(profileControllerProvider);
  if (profile is! ProfileReady) {
    return const [];
  }
  return sortServers(
    serversOf(profile.profile.servers, group),
    ref.watch(pingControllerProvider.select((state) => state.pings)),
    byPing: ref.watch(sortByPingProvider),
  );
});
