import 'dart:convert';
import 'dart:io';

import '../../../gen/api/export.dart';

/// The user's own settings as a SettingsPatch (tech.md 31.2). S1-12 keeps only
/// `ui.sortByPing` in it; S3-01 takes the file over for every key.
abstract interface class UserSettingsStore {
  Future<SettingsPatch> read();
  Future<void> write(SettingsPatch settings);
}

class FileUserSettingsStore implements UserSettingsStore {
  FileUserSettingsStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/user_settings.json');

  /// A missing or damaged file means no choice yet, so the policy applies.
  @override
  Future<SettingsPatch> read() async {
    try {
      final file = await _file;
      if (!file.existsSync()) {
        return const SettingsPatch();
      }
      return SettingsPatch.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      return const SettingsPatch();
    }
  }

  /// A failed write keeps the value for this run only, which is no reason to
  /// fail the toggle.
  @override
  Future<void> write(SettingsPatch settings) async {
    try {
      await (await _file).writeAsString(jsonEncode(settings.toJson()));
    } on Object {
      return;
    }
  }
}

class MemoryUserSettingsStore implements UserSettingsStore {
  SettingsPatch value = const SettingsPatch();

  @override
  Future<SettingsPatch> read() async => value;

  @override
  Future<void> write(SettingsPatch settings) async => value = settings;
}

/// [settings] with `ui.sortByPing` set and every other key kept.
SettingsPatch withSortByPing(SettingsPatch settings, bool value) {
  final ui = settings.ui;
  return SettingsPatch(
    routing: settings.routing,
    dns: settings.dns,
    net: settings.net,
    perApp: settings.perApp,
    ping: settings.ping,
    connect: settings.connect,
    ui: UiPatch(sortByPing: value, locale: ui?.locale, theme: ui?.theme),
    whitelist: settings.whitelist,
  );
}
