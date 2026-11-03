import 'dart:convert';
import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/api/fallback_api_client.dart';
import '../../../gen/api/export.dart';

/// A saved profile with the ETag it came with.
class CachedProfile {
  const CachedProfile(this.profile, this.etag);

  final ProfileV1 profile;
  final String? etag;
}

abstract interface class ProfileCache {
  Future<CachedProfile?> read();
  Future<void> write(CachedProfile cached);
  Future<void> clear();
}

/// Stores the profile in the private app directory. It holds server
/// credentials, so it must never move to shared storage.
class FileProfileCache implements ProfileCache {
  FileProfileCache(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/profile.json');

  @override
  Future<CachedProfile?> read() async {
    final file = await _file;
    if (!file.existsSync()) {
      return null;
    }
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return CachedProfile(
        ProfileV1.fromJson(json['profile']! as Map<String, Object?>),
        json['etag'] as String?,
      );
    } on Object {
      // A cache from an older app version is not worth failing the start.
      return null;
    }
  }

  @override
  Future<void> write(CachedProfile cached) async {
    final file = await _file;
    await file.writeAsString(
      jsonEncode({'etag': cached.etag, 'profile': cached.profile.toJson()}),
    );
  }

  @override
  Future<void> clear() async {
    final file = await _file;
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

class MemoryProfileCache implements ProfileCache {
  CachedProfile? value;

  @override
  Future<CachedProfile?> read() async => value;

  @override
  Future<void> write(CachedProfile cached) async => value = cached;

  @override
  Future<void> clear() async => value = null;
}

class ProfileLoad {
  const ProfileLoad(this.profile, {this.fromCache = false, this.retryAfterSec});

  final ProfileV1 profile;
  final bool fromCache;
  final int? retryAfterSec;
}

class ProfileRepository {
  ProfileRepository(this._api, this._cache, this._endpoints);

  final ApiClient _api;
  final ProfileCache _cache;
  final ApiEndpoints _endpoints;

  /// Loads the profile. Failure to reach the API falls back to the cache, so
  /// a signed-in device keeps working (tech.md 18.5).
  Future<ProfileLoad> load() async {
    final cached = await _cache.read();
    if (cached != null) {
      // The first request after a start already knows the fallback addresses.
      _endpoints.learn(cached.profile.endpoints.api);
    }
    final ProfileFetch fetch;
    try {
      fetch = await _api.fetchProfile(etag: cached?.etag);
    } on ApiUnavailable {
      if (cached != null) {
        return ProfileLoad(cached.profile, fromCache: true);
      }
      rethrow;
    } on ApiProblem catch (problem) {
      if (problem.isUnauthorized) {
        await _cache.clear();
      }
      rethrow;
    }

    final profile = fetch.profile;
    if (profile == null) {
      return ProfileLoad(cached!.profile);
    }
    _endpoints.learn(profile.endpoints.api);
    await _cache.write(CachedProfile(profile, fetch.etag));
    return ProfileLoad(profile, retryAfterSec: fetch.retryAfterSec);
  }
}
