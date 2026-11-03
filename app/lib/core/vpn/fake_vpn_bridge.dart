import 'dart:async';
import 'dart:convert';

import '../../gen/api/export.dart';
import 'vpn_bridge.dart';

/// Plays the core without a device or a service (FAKE_VPN=true, tech.md 9). It
/// rejects a malformed TunnelRequest, so it also tests its callers.
class FakeVpnBridge implements VpnBridge {
  final _events = StreamController<CoreEvent>.broadcast();
  final _calls = <String>[];

  TunnelStatus _status = TunnelStatus.disconnected;
  TunnelMode _userMode = TunnelMode.regular;
  TunnelMode _effectiveMode = TunnelMode.regular;
  CoreErrorCode? _nextFailure;

  VpnPrepareResult prepareResult = VpnPrepareResult.granted;
  List<SelectableApp> selectableApps = const [];

  /// Method names in call order.
  List<String> get calls => List.unmodifiable(_calls);

  /// Makes the next start or update fail with [code].
  void failNext(CoreErrorCode code) => _nextFailure = code;

  /// Delivers an event as if the core had sent it.
  void emit(CoreEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();

  @override
  Stream<CoreEvent> get events => _events.stream;

  CoreEvent _state() => CoreEvent(
    type: CoreEventType.state,
    at: DateTime.now().toUtc(),
    state: StatePayload(
      status: _status,
      userMode: _userMode,
      effectiveMode: _effectiveMode,
    ),
  );

  void _setStatus(TunnelStatus status) {
    _status = status;
    _events.add(_state());
  }

  TunnelRequest _parse(String json) =>
      TunnelRequest.fromJson(jsonDecode(json) as Map<String, Object?>);

  void _throwIfFailing() {
    final failure = _nextFailure;
    if (failure != null) {
      _nextFailure = null;
      throw VpnBridgeException(failure);
    }
  }

  @override
  Future<VpnPrepareResult> prepare() async {
    _calls.add('prepare');
    return prepareResult;
  }

  @override
  Future<void> start(String tunnelRequestJson) async {
    _calls.add('start');
    final request = _parse(tunnelRequestJson);
    _userMode = request.userMode;
    _effectiveMode = request.userMode;
    _setStatus(TunnelStatus.connecting);
    final failure = _nextFailure;
    if (failure != null) {
      _setStatus(TunnelStatus.error);
    }
    _throwIfFailing();
    _setStatus(TunnelStatus.connected);
  }

  @override
  Future<void> update(String tunnelRequestJson) async {
    _calls.add('update');
    _parse(tunnelRequestJson);
    _throwIfFailing();
  }

  @override
  Future<void> stop() async {
    _calls.add('stop');
    _setStatus(TunnelStatus.disconnecting);
    _setStatus(TunnelStatus.disconnected);
  }

  @override
  Future<void> setUserMode(TunnelMode mode) async {
    _calls.add('setUserMode');
    _userMode = mode;
    _effectiveMode = mode;
    _events.add(_state());
  }

  @override
  Future<void> selectServer(TunnelMode group, String serverId) async {
    _calls.add('selectServer');
  }

  @override
  Future<CoreEvent> urlTest(List<String> serverIds) async {
    _calls.add('urlTest');
    return CoreEvent(
      type: CoreEventType.urlTest,
      at: DateTime.now().toUtc(),
      urlTest: UrlTestPayload(
        results: [
          for (final id in serverIds) UrlTestResult(serverId: id, delayMs: 42),
        ],
      ),
    );
  }

  @override
  Future<CoreEvent> getState() async {
    _calls.add('getState');
    return _state();
  }

  @override
  Future<List<SelectableApp>> listSelectableApps() async {
    _calls.add('listSelectableApps');
    return selectableApps;
  }

  @override
  Future<List<String>> syncRuleSets(List<RuleSetRef> ruleSets) async {
    _calls.add('syncRuleSets');
    return [for (final ruleSet in ruleSets) ruleSet.id];
  }

  @override
  Future<void> forgetLastRequest() async {
    _calls.add('forgetLastRequest');
  }
}
