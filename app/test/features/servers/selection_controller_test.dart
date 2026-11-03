import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';
import 'package:vpnclient/features/profile/application/profile_controller.dart';
import 'package:vpnclient/features/profile/data/profile_repository.dart';
import 'package:vpnclient/features/servers/application/selection_controller.dart';
import 'package:vpnclient/features/servers/data/selection_store.dart';
import 'package:vpnclient/gen/api/export.dart';

String _fixture(String name) =>
    File('../contracts/fixtures/profile/$name.json').readAsStringSync();

const _frankfurt = '10000000-0000-4000-8000-000000000001';
const _amsterdam = '10000000-0000-4000-8000-000000000002';
const _moscow = '10000000-0000-4000-8000-000000000004';
const _petersburg = '10000000-0000-4000-8000-000000000005';

ProviderContainer _container(
  MemorySelectionStore store, {
  String profile = 'seed',
}) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(
        FakeApiClient(load: () async => _fixture(profile)),
      ),
      profileCacheProvider.overrideWithValue(MemoryProfileCache()),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore('t')),
      initialTokenProvider.overrideWithValue('t'),
      selectionStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  container
    ..listen(chosenServerProvider(TunnelMode.regular), (_, _) {})
    ..listen(chosenServerProvider(TunnelMode.whitelist), (_, _) {});
  return container;
}

String? _chosen(ProviderContainer c, TunnelMode group) =>
    c.read(chosenServerProvider(group));

void main() {
  test('no choice before the profile arrives', () {
    final c = _container(MemorySelectionStore());

    expect(_chosen(c, TunnelMode.regular), isNull);
    expect(_chosen(c, TunnelMode.whitelist), isNull);
  });

  for (final name in ['seed', 'trial', 'expired', 'provisioning']) {
    test(
      '$name: each group starts on its first server by sortWeight',
      () async {
        final c = _container(MemorySelectionStore(), profile: name);
        await pumpEventQueue();

        final profile = ProfileV1.fromJson(
          jsonDecode(_fixture(name)) as Map<String, Object?>,
        );
        for (final group in TunnelMode.values) {
          final members =
              profile.servers.where((s) => s.group == group).toList()
                ..sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
          expect(
            _chosen(c, group),
            members.firstOrNull?.id,
            reason: group.json,
          );
        }
      },
    );
  }

  test('a choice changes its own group only', () async {
    final store = MemorySelectionStore();
    final c = _container(store);
    await pumpEventQueue();

    await c
        .read(selectionControllerProvider.notifier)
        .remember(TunnelMode.whitelist, _petersburg);

    expect(_chosen(c, TunnelMode.whitelist), _petersburg);
    expect(_chosen(c, TunnelMode.regular), _frankfurt);
    expect(store.value.toJson(), {'whitelist': _petersburg});
  });

  test('the choice of each group survives a restart', () async {
    final store = MemorySelectionStore();
    final first = _container(store);
    await pumpEventQueue();
    final notifier = first.read(selectionControllerProvider.notifier);
    await notifier.remember(TunnelMode.regular, _amsterdam);
    await notifier.remember(TunnelMode.whitelist, _petersburg);
    first.dispose();

    final second = _container(store);
    await pumpEventQueue();

    expect(_chosen(second, TunnelMode.regular), _amsterdam);
    expect(_chosen(second, TunnelMode.whitelist), _petersburg);
  });

  test(
    'a stored server that left the profile falls back to the first',
    () async {
      final store = MemorySelectionStore()
        ..value = const SelectedServers(
          regular: 'gone',
          whitelist: _petersburg,
        );
      final c = _container(store);
      await pumpEventQueue();

      expect(_chosen(c, TunnelMode.regular), _frankfurt);
      expect(_chosen(c, TunnelMode.whitelist), _petersburg);
      expect(
        store.value.regular,
        'gone',
        reason: 'a server may come back after a catalog sync',
      );
    },
  );

  test('a stored server of the wrong group is not used', () async {
    final store = MemorySelectionStore()
      ..value = const SelectedServers(regular: _moscow);
    final c = _container(store);
    await pumpEventQueue();

    expect(_chosen(c, TunnelMode.regular), _frankfurt);
  });
}
