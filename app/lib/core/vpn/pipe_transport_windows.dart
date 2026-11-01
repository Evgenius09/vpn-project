import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'pipe_rpc.dart';

const _pollInterval = Duration(milliseconds: 20);
const _readChunk = 64 * 1024;

/// A named pipe client. A synchronous pipe handle serializes reads and writes,
/// so a blocking read would stall every write. A single background isolate polls
/// with PeekNamedPipe instead and never blocks on an empty pipe.
class Win32PipeTransport implements PipeTransport {
  Win32PipeTransport._(this._isolate, this._commands, this._lines);

  final Isolate _isolate;
  final SendPort _commands;
  final StreamController<String> _lines;

  static Future<Win32PipeTransport> connect(String pipeName) async {
    final messages = ReceivePort();
    final lines = StreamController<String>.broadcast();
    final ready = Completer<SendPort>();

    messages.listen((message) {
      switch (message) {
        case SendPort commands:
          ready.complete(commands);
        case String line:
          lines.add(line);
        case _PipeFailed(:final error):
          if (!ready.isCompleted) {
            ready.completeError(error);
          }
          messages.close();
          unawaited(lines.close());
      }
    });

    final isolate = await Isolate.spawn(
      _pipeLoop,
      _PipeStart(pipeName, messages.sendPort),
    );
    return Win32PipeTransport._(isolate, await ready.future, lines);
  }

  @override
  Stream<String> get lines => _lines.stream;

  @override
  void send(String line) => _commands.send(line);

  @override
  Future<void> close() async {
    _commands.send(const _PipeClose());
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

class _PipeStart {
  const _PipeStart(this.pipeName, this.replies);

  final String pipeName;
  final SendPort replies;
}

class _PipeClose {
  const _PipeClose();
}

class _PipeFailed {
  const _PipeFailed(this.error);

  final String error;
}

void _pipeLoop(_PipeStart start) {
  final replies = start.replies;
  final name = start.pipeName.toPcwstr();
  final opened = CreateFile(
    name,
    GENERIC_READ | GENERIC_WRITE,
    FILE_SHARE_NONE,
    null,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    null,
  );
  free(name);
  final handle = opened.value;
  if (handle == INVALID_HANDLE_VALUE) {
    replies.send(_PipeFailed('open pipe: error ${opened.error}'));
    return;
  }

  final commands = ReceivePort();
  replies.send(commands.sendPort);

  final buffer = calloc<Uint8>(_readChunk);
  final count = calloc<Uint32>();
  final available = calloc<Uint32>();
  final decoder = const Utf8Decoder(allowMalformed: true);
  var pending = <int>[];

  void finish(String reason) {
    CloseHandle(handle);
    calloc
      ..free(buffer)
      ..free(count)
      ..free(available);
    commands.close();
    replies.send(_PipeFailed(reason));
  }

  late final Timer poll;
  poll = Timer.periodic(_pollInterval, (_) {
    if (!PeekNamedPipe(handle, null, 0, null, available, null).value) {
      poll.cancel();
      finish('pipe closed');
      return;
    }
    while (available.value > 0) {
      final size = available.value < _readChunk ? available.value : _readChunk;
      if (!ReadFile(handle, buffer, size, count, null).value) {
        poll.cancel();
        finish('read failed');
        return;
      }
      pending.addAll(buffer.asTypedList(count.value));
      var end = pending.indexOf(0x0A);
      while (end >= 0) {
        replies.send(decoder.convert(pending.sublist(0, end)));
        pending = pending.sublist(end + 1);
        end = pending.indexOf(0x0A);
      }
      PeekNamedPipe(handle, null, 0, null, available, null);
    }
  });

  commands.listen((message) {
    switch (message) {
      case String line:
        final bytes = utf8.encode('$line\n');
        final data = calloc<Uint8>(bytes.length);
        data.asTypedList(bytes.length).setAll(0, bytes);
        final written = WriteFile(handle, data, bytes.length, count, null);
        calloc.free(data);
        if (!written.value) {
          poll.cancel();
          finish('write failed');
        }
      case _PipeClose():
        poll.cancel();
        finish('closed');
    }
  });
}
