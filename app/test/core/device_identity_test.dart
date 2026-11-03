import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/core/device/device_identity.dart';
import 'package:vpnclient/gen/api/export.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('newInstallId', () {
    test('is a UUID v4', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(newInstallId(Random(seed)), matches(_uuidV4));
      }
    });

    test('differs between installs', () {
      final ids = {for (var i = 0; i < 100; i++) newInstallId()};
      expect(ids, hasLength(100));
    });
  });

  group('MemoryInstallIdStore', () {
    test('creates the id once and keeps it', () async {
      final store = MemoryInstallIdStore();
      final first = await store.read();
      expect(first, matches(_uuidV4));
      expect(await store.read(), first);
    });
  });

  group('deviceModel', () {
    test('collapses spaces', () {
      expect(
        deviceModel('  samsung   SM-A225F ', Platform.android),
        'samsung SM-A225F',
      );
    });

    test('falls back to the platform name', () {
      expect(deviceModel('   ', Platform.windows), 'windows');
      expect(deviceModel('', Platform.android), 'android');
    });

    // The backend rejects a model over 64 characters (tech.md 25.1).
    Glados2<String, bool>(any.letterOrDigits, any.bool).test(
      'is never empty and never longer than 64',
      (raw, android) {
        final platform = android ? Platform.android : Platform.windows;
        final model = deviceModel(raw * 5, platform);
        expect(model, isNotEmpty);
        expect(model.length, lessThanOrEqualTo(maxModelLength));
        expect(model.trim(), model);
      },
    );
  });
}
