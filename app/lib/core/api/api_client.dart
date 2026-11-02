import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../gen/api/export.dart';
import '../storage/token_store.dart';

const _fakeProfileAsset = 'assets/gen/profile.json';

/// The answer to a profile request. A null profile means 304.
class ProfileFetch {
  const ProfileFetch({this.profile, this.etag, this.retryAfterSec});

  const ProfileFetch.notModified() : this();

  final ProfileV1? profile;
  final String? etag;
  final int? retryAfterSec;
}

sealed class ApiException implements Exception {
  const ApiException();
}

/// The server answered with a problem (tech.md 5.2).
final class ApiProblem extends ApiException {
  const ApiProblem(this.status, this.code);

  final int status;
  final ProblemCode? code;

  bool get isUnauthorized =>
      code == ProblemCode.unauthorized || code == ProblemCode.deviceRevoked;

  @override
  String toString() => 'ApiProblem($status, ${code?.json})';
}

/// No usable answer: the network failed or the server is broken. Callers may
/// fall back to cached data.
final class ApiUnavailable extends ApiException {
  const ApiUnavailable();
}

/// What features use. The generated client and the fake stay behind it.
abstract interface class ApiClient {
  Future<ProfileFetch> fetchProfile({String? etag});
}

class HttpApiClient implements ApiClient {
  HttpApiClient(this._client);

  final VpnApiClient _client;

  static const _serverErrorStart = 500;
  static const _notModified = 304;

  static Object _translate(DioException error) {
    final response = error.response;
    if (response == null || response.statusCode == null) {
      return const ApiUnavailable();
    }
    final status = response.statusCode!;
    if (status >= _serverErrorStart) {
      return const ApiUnavailable();
    }
    final body = response.data;
    final raw = body is Map<String, Object?> ? body['code'] : null;
    return ApiProblem(
      status,
      ProblemCode.values.where((code) => code.json == raw).firstOrNull,
    );
  }

  @override
  Future<ProfileFetch> fetchProfile({String? etag}) async {
    try {
      final response = await _client.profile.getProfile(ifNoneMatch: etag);
      final headers = response.response.headers;
      return ProfileFetch(
        profile: response.data,
        etag: headers.value('etag'),
        retryAfterSec: int.tryParse(headers.value('retry-after') ?? ''),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == _notModified) {
        return const ProfileFetch.notModified();
      }
      throw _translate(error);
    }
  }
}

/// Serves the seed profile without a backend (FAKE_API=true, tech.md 9).
class FakeApiClient implements ApiClient {
  FakeApiClient({Future<String> Function()? load})
    : _load = load ?? (() => rootBundle.loadString(_fakeProfileAsset));

  final Future<String> Function() _load;

  /// Thrown instead of answering, to script failures in tests.
  ApiException? failure;
  ProfileFetch? scripted;
  int fetches = 0;

  static const _etag = '"fake"';

  @override
  Future<ProfileFetch> fetchProfile({String? etag}) async {
    fetches++;
    final scriptedFailure = failure;
    if (scriptedFailure != null) {
      throw scriptedFailure;
    }
    final answer = scripted;
    if (answer != null) {
      return answer;
    }
    if (etag == _etag) {
      return const ProfileFetch.notModified();
    }
    final json = jsonDecode(await _load()) as Map<String, Object?>;
    return ProfileFetch(profile: ProfileV1.fromJson(json), etag: _etag);
  }
}

/// Adds the device token to every request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);

  final TokenStore _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

VpnApiClient createGeneratedClient({
  required String baseUrl,
  required TokenStore tokens,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl))
    ..interceptors.add(AuthInterceptor(tokens));
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return VpnApiClient(dio, baseUrl: baseUrl);
}
