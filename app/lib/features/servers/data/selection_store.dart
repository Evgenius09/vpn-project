import 'dart:convert';
import 'dart:io';

import '../../../gen/api/export.dart';

/// Keeps the chosen server of each group across restarts (tech.md 28.2).
abstract interface class SelectionStore {
  Future<SelectedServers> read();
  Future<void> write(SelectedServers selected);
}

/// Stores the choice next to the profile cache in the private app directory.
class FileSelectionStore implements SelectionStore {
  FileSelectionStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/selected_servers.json');

  /// A missing or damaged file means no choice yet: the first server of each
  /// group is a safe start.
  @override
  Future<SelectedServers> read() async {
    try {
      final file = await _file;
      if (!file.existsSync()) {
        return const SelectedServers();
      }
      return SelectedServers.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      return const SelectedServers();
    }
  }

  /// A failed write keeps the choice for this run only, which is no reason to
  /// fail the tap.
  @override
  Future<void> write(SelectedServers selected) async {
    try {
      await (await _file).writeAsString(jsonEncode(selected.toJson()));
    } on Object {
      return;
    }
  }
}

class MemorySelectionStore implements SelectionStore {
  SelectedServers value = const SelectedServers();

  @override
  Future<SelectedServers> read() async => value;

  @override
  Future<void> write(SelectedServers selected) async => value = selected;
}
