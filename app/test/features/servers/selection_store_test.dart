import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/servers/data/selection_store.dart';
import 'package:vpnclient/gen/api/export.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('selection'));
  tearDown(() => directory.deleteSync(recursive: true));

  FileSelectionStore store() => FileSelectionStore(() async => directory);

  test('nothing stored reads as no choice', () async {
    expect((await store().read()).toJson(), <String, Object?>{});
  });

  test('the choice of each group survives a restart', () async {
    await store().write(const SelectedServers(regular: 'a', whitelist: 'b'));

    final read = await store().read();

    expect(read.regular, 'a');
    expect(read.whitelist, 'b');
  });

  test('a damaged file reads as no choice', () async {
    File('${directory.path}/selected_servers.json')
        .writeAsStringSync('{broken');

    expect((await store().read()).toJson(), <String, Object?>{});
  });

  test('a missing directory reads as no choice and writes nothing', () async {
    final broken = FileSelectionStore(
      () async => throw const FileSystemException('no directory'),
    );

    expect((await broken.read()).toJson(), <String, Object?>{});
    await broken.write(const SelectedServers(regular: 'a'));
  });
}
