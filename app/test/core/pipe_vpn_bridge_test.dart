import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/vpn/pipe_rpc.dart';
import 'package:vpnclient/core/vpn/pipe_vpn_bridge.dart';
import 'package:vpnclient/core/vpn/vpn_bridge.dart';
import 'package:vpnclient/gen/api/export.dart';

class _Frame {
  _Frame(this.outgoing, this.message);

  factory _Frame.parse(String line) {
    final json = jsonDecode(line) as Map<String, Object?>;
    return _Frame(json['dir'] == 'send', json['msg']! as Map<String, Object?>);
  }

  final bool outgoing;
  final Map<String, Object?> message;
}

/// Replays a recorded session: the same files core/internal/ipc plays against
/// the Go server (tech.md 10). A request that differs from the record fails.
class _ReplayTransport implements PipeTransport {
  _ReplayTransport(this._frames);

  factory _ReplayTransport.session(String name) => _ReplayTransport([
    for (final line in File(
      '../contracts/fixtures/ipc/$name.jsonl',
    ).readAsLinesSync())
      _Frame.parse(line),
  ]);

  final List<_Frame> _frames;
  final _lines = StreamController<String>.broadcast();
  int _index = 0;
  bool closed = false;

  @override
  Stream<String> get lines => _lines.stream;

  void _deliver() {
    while (_index < _frames.length && !_frames[_index].outgoing) {
      final frame = _frames[_index++];
      scheduleMicrotask(() => _lines.add(jsonEncode(frame.message)));
    }
  }

  @override
  void send(String line) {
    final expected = _frames[_index++];
    expect(expected.outgoing, isTrue, reason: line);
    expect(jsonDecode(line), expected.message);
    _deliver();
  }

  @override
  Future<void> close() async {
    closed = true;
    await _lines.close();
  }

  void hangUp() => _lines.close();
}

/// Answers every request with a fixed result per method.
class _ScriptedTransport implements PipeTransport {
  _ScriptedTransport(this.results);

  final Map<String, Object?> results;
  final _lines = StreamController<String>.broadcast();
  final sent = <Map<String, Object?>>[];

  @override
  Stream<String> get lines => _lines.stream;

  @override
  void send(String line) {
    final request = jsonDecode(line) as Map<String, Object?>;
    sent.add(request);
    final method = request['method']! as String;
    scheduleMicrotask(() {
      _lines.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': results[method] ?? <String, Object?>{},
        }),
      );
    });
  }

  @override
  Future<void> close() => _lines.close();
}

PipeVpnBridge _bridge(PipeTransport transport, {int? protocolVersion}) =>
    PipeVpnBridge(
      connect: () async => transport,
      appVersion: '0.1.0',
      protocolVersion:
          protocolVersion ?? PipeVpnBridge.supportedProtocolVersion,
      timeout: const Duration(milliseconds: 200),
    );

void main() {
  group('recorded sessions', () {
    test('hello, subscribe, and state', () async {
      final transport = _ReplayTransport.session('hello_subscribe_state');
      final bridge = _bridge(transport);
      final events = <CoreEvent>[];
      final subscription = bridge.events.listen(events.add);

      // The first transport delivery needs a listener in place, so the session
      // starts from the bridge call itself.
      final state = await bridge.getState();
      await pumpEventQueue();
      await subscription.cancel();

      expect(state.state!.status, TunnelStatus.disconnected);
      expect(events.single.state!.status, TunnelStatus.connected);
    });

    test('a version mismatch fails with ipc_version_mismatch', () async {
      final bridge = _bridge(
        _ReplayTransport.session('version_mismatch'),
        protocolVersion: 99,
      );
      await expectLater(
        bridge.prepare(),
        throwsA(
          isA<VpnBridgeException>().having(
            (error) => error.code,
            'code',
            CoreErrorCode.ipcVersionMismatch,
          ),
        ),
      );
    });

    test('an unknown method reports -32601', () async {
      final client = PipeRpcClient(_ReplayTransport.session('unknown_method'));
      await client.call('hello', {'protocolVersion': 1, 'appVersion': '0.1.0'});
      await expectLater(
        client.call('reboot', {}),
        throwsA(
          isA<PipeRpcException>()
              .having((error) => error.code, 'code', -32601)
              .having((error) => error.dataCode, 'dataCode', isNull),
        ),
      );
    });
  });

  group('failures', () {
    test('a missing service is service_unavailable', () async {
      final bridge = PipeVpnBridge(
        connect: () async => throw Exception('no pipe'),
        appVersion: '0.1.0',
      );
      await expectLater(
        bridge.prepare(),
        throwsA(
          isA<VpnBridgeException>().having(
            (error) => error.code,
            'code',
            CoreErrorCode.serviceUnavailable,
          ),
        ),
      );
    });

    test('the bridge reconnects once the service appears', () async {
      var attempts = 0;
      final bridge = PipeVpnBridge(
        connect: () async {
          attempts++;
          if (attempts == 1) {
            throw Exception('no pipe');
          }
          return _ScriptedTransport({});
        },
        appVersion: '0.1.0',
      );

      await expectLater(bridge.prepare(), throwsA(anything));
      expect(await bridge.prepare(), VpnPrepareResult.granted);
      expect(attempts, 2);
    });

    test('a dropped connection is service_unavailable', () async {
      final transport = _ReplayTransport([
        _Frame(true, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'hello',
          'params': {'protocolVersion': 1, 'appVersion': '0.1.0'},
        }),
      ]);
      final bridge = _bridge(transport);
      final call = bridge.prepare();
      await pumpEventQueue();
      transport.hangUp();
      await expectLater(
        call,
        throwsA(
          isA<VpnBridgeException>().having(
            (error) => error.code,
            'code',
            CoreErrorCode.serviceUnavailable,
          ),
        ),
      );
    });

    test('a silent service times out as service_unavailable', () async {
      final transport = _ReplayTransport([
        _Frame(true, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'hello',
          'params': {'protocolVersion': 1, 'appVersion': '0.1.0'},
        }),
      ]);
      await expectLater(
        _bridge(transport).prepare(),
        throwsA(
          isA<VpnBridgeException>().having(
            (error) => error.code,
            'code',
            CoreErrorCode.serviceUnavailable,
          ),
        ),
      );
    });
  });

  group('requests', () {
    Future<Map<String, Object?>> lastParams(
      _ScriptedTransport transport,
      Future<void> Function(PipeVpnBridge bridge) action,
    ) async {
      await action(_bridge(transport));
      return transport.sent.last['params']! as Map<String, Object?>;
    }

    test('start sends the request as an object', () async {
      final params = await lastParams(
        _ScriptedTransport({}),
        (bridge) => bridge.start('{"schemaVersion":1}'),
      );
      expect(params, {
        'tunnelRequest': {'schemaVersion': 1},
      });
    });

    test('modes use their wire names', () async {
      final params = await lastParams(
        _ScriptedTransport({}),
        (bridge) => bridge.selectServer(TunnelMode.whitelist, 'id'),
      );
      expect(params, {'group': 'whitelist', 'serverId': 'id'});
    });

    test('processes become selectable apps', () async {
      final bridge = _bridge(
        _ScriptedTransport({
          'listProcesses': [
            {'name': 'telegram.exe', 'path': r'C:\telegram.exe'},
          ],
        }),
      );
      final apps = await bridge.listSelectableApps();
      expect(apps.single.id, 'telegram.exe');
    });

    test('syncRuleSets returns the ready identifiers', () async {
      final bridge = _bridge(
        _ScriptedTransport({
          'syncRuleSets': {
            'ready': ['ru-direct'],
          },
        }),
      );
      final ready = await bridge.syncRuleSets([
        const RuleSetRef(id: 'ru-direct', url: 'u', sha256: 's'),
      ]);
      expect(ready, ['ru-direct']);
    });

    test('hello and subscribe run once per connection', () async {
      final transport = _ScriptedTransport({});
      final bridge = _bridge(transport);
      await bridge.prepare();
      await bridge.stop();
      expect(transport.sent.map((request) => request['method']), [
        'hello',
        'subscribe',
        'prepare',
        'stop',
      ]);
    });
  });
}
