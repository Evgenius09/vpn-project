import 'dart:async';
import 'dart:convert';

import '../../gen/api/export.dart';
import 'pipe_rpc.dart';
import 'vpn_bridge.dart';

/// The Windows bridge: JSON-RPC to the vpnsvc service (tech.md 5.6). It connects
/// on first use, so an app without the service still starts and can explain the
/// problem.
class PipeVpnBridge implements VpnBridge {
  PipeVpnBridge({
    required this.connect,
    required this.appVersion,
    this.protocolVersion = supportedProtocolVersion,
    this.timeout = const Duration(seconds: 30),
  });

  static const supportedProtocolVersion = 1;

  final Future<PipeTransport> Function() connect;
  final String appVersion;
  final int protocolVersion;
  final Duration timeout;

  final _events = StreamController<CoreEvent>.broadcast();
  Future<PipeRpcClient>? _client;

  static CoreErrorCode _code(String? code) => CoreErrorCode.values.firstWhere(
    (value) => value.json == code,
    orElse: () => CoreErrorCode.internal,
  );

  static String _mode(TunnelMode mode) => mode.json!;

  Future<PipeRpcClient> _open() async {
    final PipeTransport transport;
    try {
      transport = await connect();
    } on Object catch (error) {
      throw VpnBridgeException(
        CoreErrorCode.serviceUnavailable,
        error.toString(),
      );
    }
    final client = PipeRpcClient(transport);
    await client
        .call('hello', {
          'protocolVersion': protocolVersion,
          'appVersion': appVersion,
        })
        .timeout(timeout);
    await client.call('subscribe', {}).timeout(timeout);
    client.events.map(CoreEvent.fromJson).listen(_events.add);
    return client;
  }

  /// Reconnects on the next call after a failed connection, because the user
  /// may start the service in the meantime.
  Future<PipeRpcClient> get _connected {
    final client = _client ??= _open();
    client.catchError((Object _) {
      _client = null;
      return Future<PipeRpcClient>.error(
        const VpnBridgeException(CoreErrorCode.serviceUnavailable),
      );
    }).ignore();
    return client;
  }

  Future<Object?> _call(String method, Map<String, Object?> params) async {
    try {
      final client = await _connected;
      return await client.call(method, params).timeout(timeout);
    } on PipeRpcException catch (error) {
      if (error.dataCode == CoreErrorCode.ipcVersionMismatch.json) {
        _client = null;
      }
      throw VpnBridgeException(_code(error.dataCode), error.message);
    } on PipeClosedException {
      _client = null;
      throw const VpnBridgeException(CoreErrorCode.serviceUnavailable);
    } on TimeoutException {
      _client = null;
      throw const VpnBridgeException(CoreErrorCode.serviceUnavailable);
    }
  }

  CoreEvent _event(Object? result) =>
      CoreEvent.fromJson(result! as Map<String, Object?>);

  @override
  Stream<CoreEvent> get events => _events.stream;

  @override
  Future<VpnPrepareResult> prepare() async {
    await _call('prepare', {});
    return VpnPrepareResult.granted;
  }

  @override
  Future<void> start(String tunnelRequestJson) =>
      _call('start', {'tunnelRequest': jsonDecode(tunnelRequestJson)});

  @override
  Future<void> update(String tunnelRequestJson) =>
      _call('update', {'tunnelRequest': jsonDecode(tunnelRequestJson)});

  @override
  Future<void> stop() => _call('stop', {});

  @override
  Future<void> setUserMode(TunnelMode mode) =>
      _call('setUserMode', {'mode': _mode(mode)});

  @override
  Future<void> selectServer(TunnelMode group, String serverId) =>
      _call('selectServer', {'group': _mode(group), 'serverId': serverId});

  @override
  Future<CoreEvent> urlTest(List<String> serverIds) async =>
      _event(await _call('urlTest', {'serverIds': serverIds}));

  @override
  Future<CoreEvent> getState() async => _event(await _call('getState', {}));

  @override
  Future<List<SelectableApp>> listSelectableApps() async {
    final processes = await _call('listProcesses', {});
    return [
      for (final process in processes! as List<Object?>)
        switch (process) {
          {'name': final String name} => SelectableApp(id: name, label: name),
          _ => throw const FormatException('unexpected process entry'),
        },
    ];
  }

  @override
  Future<List<String>> syncRuleSets(List<RuleSetRef> ruleSets) async {
    final result = await _call('syncRuleSets', {
      'ruleSets': [for (final ruleSet in ruleSets) ruleSet.toJson()],
    });
    final ready = (result! as Map<String, Object?>)['ready']! as List<Object?>;
    return ready.cast<String>();
  }

  /// The service keeps its own last request for autostart, and IPC v1 has no
  /// method to delete it (tech.md 26.3).
  @override
  Future<void> forgetLastRequest() async {}
}
