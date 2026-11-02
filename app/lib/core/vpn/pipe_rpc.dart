import 'dart:async';
import 'dart:convert';

/// A byte stream to vpnsvc, one JSON message per line. Tests replace it with an
/// in-memory transport.
abstract interface class PipeTransport {
  Stream<String> get lines;
  void send(String line);
  Future<void> close();
}

/// A JSON-RPC error from the service (tech.md 5.6). dataCode is a CoreErrorCode
/// wire value when the core produced the error.
class PipeRpcException implements Exception {
  const PipeRpcException(this.code, this.message, this.dataCode);

  final int code;
  final String message;
  final String? dataCode;

  @override
  String toString() => 'PipeRpcException($code, $dataCode: $message)';
}

/// The connection to the service ended before a response arrived.
class PipeClosedException implements Exception {
  const PipeClosedException();
}

/// JSON-RPC 2.0 over a [PipeTransport].
class PipeRpcClient {
  PipeRpcClient(this._transport) {
    _subscription = _transport.lines.listen(
      _onLine,
      onDone: _onClosed,
      onError: (Object _) => _onClosed(),
    );
  }

  final PipeTransport _transport;
  late final StreamSubscription<String> _subscription;
  final _pending = <int, Completer<Object?>>{};
  final _notifications = StreamController<Map<String, Object?>>.broadcast();
  int _nextId = 1;

  /// Params of every `event` notification.
  Stream<Map<String, Object?>> get events => _notifications.stream;

  Future<Object?> call(String method, Map<String, Object?> params) {
    final id = _nextId++;
    final response = Completer<Object?>();
    _pending[id] = response;
    _transport.send(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    return response.future;
  }

  void _onLine(String line) {
    final message = jsonDecode(line) as Map<String, Object?>;
    final id = message['id'];
    if (id == null) {
      if (message['method'] == 'event') {
        _notifications.add(message['params']! as Map<String, Object?>);
      }
      return;
    }
    final response = _pending.remove(id);
    if (response == null) {
      return;
    }
    final error = message['error'] as Map<String, Object?>?;
    if (error == null) {
      response.complete(message['result']);
      return;
    }
    final data = error['data'] as Map<String, Object?>?;
    response.completeError(
      PipeRpcException(
        error['code']! as int,
        error['message']! as String,
        data?['code'] as String?,
      ),
    );
  }

  void _onClosed() {
    final pending = _pending.values.toList();
    _pending.clear();
    for (final response in pending) {
      response.completeError(const PipeClosedException());
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    _onClosed();
    await _transport.close();
    await _notifications.close();
  }
}
