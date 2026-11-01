import '../../gen/api/export.dart';

enum VpnPrepareResult { granted, denied }

/// An app or process the user can pick for split tunneling. id is a package
/// name on Android and a process name on Windows (tech.md 19.7).
class SelectableApp {
  const SelectableApp({required this.id, required this.label});

  final String id;
  final String label;
}

/// A failure from the core. code is a CoreErrorCode wire value.
class VpnBridgeException implements Exception {
  const VpnBridgeException(this.code, [this.message = '']);

  final CoreErrorCode code;
  final String message;

  @override
  String toString() => 'VpnBridgeException(${code.json}: $message)';
}

/// The only way features reach the tunnel (tech.md 5.6). Pigeon and the named
/// pipe stay behind it.
abstract interface class VpnBridge {
  Stream<CoreEvent> get events;

  Future<VpnPrepareResult> prepare();
  Future<void> start(String tunnelRequestJson);
  Future<void> update(String tunnelRequestJson);
  Future<void> stop();
  Future<void> setUserMode(TunnelMode mode);
  Future<void> selectServer(TunnelMode group, String serverId);
  Future<CoreEvent> urlTest(List<String> serverIds);
  Future<CoreEvent> getState();
  Future<List<SelectableApp>> listSelectableApps();
  Future<List<String>> syncRuleSets(List<RuleSetRef> ruleSets);
}
