import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/ping/data/user_settings_store.dart';
import 'package:vpnclient/gen/api/export.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('settings'));
  tearDown(() => directory.deleteSync(recursive: true));

  FileUserSettingsStore store() => FileUserSettingsStore(() async => directory);

  test('nothing stored reads as no choice', () async {
    expect((await store().read()).toJson(), <String, Object?>{});
  });

  test('the sort choice survives a restart as a SettingsPatch', () async {
    await store().write(withSortByPing(const SettingsPatch(), false));

    expect((await store().read()).ui?.sortByPing, isFalse);
    expect(
      File('${directory.path}/user_settings.json').readAsStringSync(),
      '{"ui":{"sortByPing":false}}',
    );
  });

  test('setting the sort choice keeps every other key', () {
    const before = SettingsPatch(
      net: NetPatch(mtu: 1400),
      ui: UiPatch(locale: UiLocale.en, theme: UiTheme.dark),
    );

    final after = withSortByPing(before, true);

    expect(after.toJson(), {
      'net': {'mtu': 1400},
      'ui': {'sortByPing': true, 'locale': 'en', 'theme': 'dark'},
    });
  });

  test('a damaged file reads as no choice', () async {
    File('${directory.path}/user_settings.json').writeAsStringSync('{broken');

    expect((await store().read()).toJson(), <String, Object?>{});
  });

  test(
    'a missing directory reads as no choice and a write does not throw',
    () async {
      final broken = FileUserSettingsStore(
        () async => throw const FileSystemException('no directory'),
      );

      expect((await broken.read()).toJson(), <String, Object?>{});
      await broken.write(withSortByPing(const SettingsPatch(), true));
    },
  );
}
