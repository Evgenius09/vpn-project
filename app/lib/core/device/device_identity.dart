import 'dart:io' as io;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../gen/api/export.dart';

/// What the login sends about this device (tech.md 26.2).
class DeviceIdentity {
  const DeviceIdentity({
    required this.platform,
    required this.model,
    required this.installId,
  });

  final Platform platform;
  final String model;
  final String installId;
}

/// The backend rejects a longer model (tech.md 25.1).
const maxModelLength = 64;

/// Collapses spaces and bounds the length. An empty model names the platform,
/// because the backend requires at least one character.
String deviceModel(String raw, Platform platform) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) {
    return platform.json!;
  }
  if (collapsed.length <= maxModelLength) {
    return collapsed;
  }
  return collapsed.substring(0, maxModelLength).trimRight();
}

/// A random UUID v4.
String newInstallId([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final text = hex.join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
      '${text.substring(12, 16)}-${text.substring(16, 20)}-'
      '${text.substring(20)}';
}

/// Keeps the install id. A logout leaves it, so the next login gets the same
/// deviceId back (tech.md 19.9).
abstract interface class InstallIdStore {
  /// Returns the stored id, creating it on the first call.
  Future<String> read();
}

class SecureInstallIdStore implements InstallIdStore {
  SecureInstallIdStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'install_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String> read() async {
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final created = newInstallId();
    await _storage.write(key: _key, value: created);
    return created;
  }
}

class MemoryInstallIdStore implements InstallIdStore {
  MemoryInstallIdStore([this._id]);

  String? _id;

  @override
  Future<String> read() async => _id ??= newInstallId();
}

Future<DeviceIdentity> readDeviceIdentity(InstallIdStore store) async {
  final info = DeviceInfoPlugin();
  final Platform platform;
  final String raw;
  if (io.Platform.isAndroid) {
    final android = await info.androidInfo;
    platform = Platform.android;
    raw = '${android.manufacturer} ${android.model}';
  } else if (io.Platform.isWindows) {
    final windows = await info.windowsInfo;
    platform = Platform.windows;
    raw = windows.productName;
  } else {
    throw UnsupportedError('login runs only on Android and Windows');
  }
  return DeviceIdentity(
    platform: platform,
    model: deviceModel(raw, platform),
    installId: await store.read(),
  );
}

final installIdStoreProvider = Provider<InstallIdStore>(
  (ref) => SecureInstallIdStore(),
);

final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => readDeviceIdentity(ref.watch(installIdStoreProvider)),
);
