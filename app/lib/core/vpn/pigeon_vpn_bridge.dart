import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../gen/api/export.dart';
import '../../gen/pigeon/vpn_api.g.dart' as pigeon;
import 'vpn_bridge.dart';

/// The Android bridge (tech.md 5.6).
class PigeonVpnBridge implements VpnBridge {
  PigeonVpnBridge({pigeon.VpnHostApi? host, Stream<String>? rawEvents})
    : _host = host ?? pigeon.VpnHostApi(),
      _rawEvents = rawEvents ?? pigeon.events();

  final pigeon.VpnHostApi _host;
  final Stream<String> _rawEvents;

  static CoreEvent _decode(String json) =>
      CoreEvent.fromJson(jsonDecode(json) as Map<String, Object?>);

  static pigeon.TunnelModeMsg _mode(TunnelMode mode) => switch (mode) {
    TunnelMode.regular => pigeon.TunnelModeMsg.regular,
    TunnelMode.whitelist => pigeon.TunnelModeMsg.whitelist,
  };

  static CoreErrorCode _code(String code) => CoreErrorCode.values.firstWhere(
    (value) => value.json == code,
    orElse: () => CoreErrorCode.internal,
  );

  Future<T> _guarded<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw VpnBridgeException(_code(error.code), error.message ?? '');
    }
  }

  @override
  Stream<CoreEvent> get events => _rawEvents.map(_decode);

  @override
  Future<VpnPrepareResult> prepare() => _guarded(() async {
    final result = await _host.prepare();
    return switch (result) {
      pigeon.PrepareResult.granted => VpnPrepareResult.granted,
      pigeon.PrepareResult.denied => VpnPrepareResult.denied,
    };
  });

  @override
  Future<void> start(String tunnelRequestJson) =>
      _guarded(() => _host.start(tunnelRequestJson));

  @override
  Future<void> update(String tunnelRequestJson) =>
      _guarded(() => _host.update(tunnelRequestJson));

  @override
  Future<void> stop() => _guarded(_host.stop);

  @override
  Future<void> setUserMode(TunnelMode mode) =>
      _guarded(() => _host.setUserMode(_mode(mode)));

  @override
  Future<void> selectServer(TunnelMode group, String serverId) =>
      _guarded(() => _host.selectServer(_mode(group), serverId));

  @override
  Future<CoreEvent> urlTest(List<String> serverIds) =>
      _guarded(() async => _decode(await _host.urlTest(serverIds)));

  @override
  Future<CoreEvent> getState() =>
      _guarded(() async => _decode(await _host.getState()));

  @override
  Future<List<SelectableApp>> listSelectableApps() => _guarded(() async {
    final apps = await _host.listApps();
    return [
      for (final app in apps)
        switch (jsonDecode(app)) {
          {'package': final String id, 'label': final String label} =>
            SelectableApp(id: id, label: label),
          _ => throw const FormatException('unexpected app entry'),
        },
    ];
  });

  /// S3-02 downloads the rule sets in Dart. On Android nothing is ready yet.
  @override
  Future<List<String>> syncRuleSets(List<RuleSetRef> ruleSets) async =>
      const [];
}
