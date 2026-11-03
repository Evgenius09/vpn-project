import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../gen/api/export.dart';
import '../storage/token_store.dart';
import 'fallback_api_client.dart';

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
  const ApiProblem(
    this.status,
    this.code, {
    this.botUrl,
    this.attemptsLeft,
    this.retryAfterSec,
  });

  final int status;
  final ProblemCode? code;

  /// Set for telegram_user_not_found.
  final String? botUrl;

  /// Set for code_invalid.
  final int? attemptsLeft;

  /// Set for rate_limited.
  final int? retryAfterSec;

  bool get isUnauthorized =>
      code == ProblemCode.unauthorized || code == ProblemCode.deviceRevoked;

  @override
  String toString() => 'ApiProblem($status, ${code?.json})';
}

/// No usable answer: the network failed or the server is broken. Callers may
/// fall back to cached data.
final class ApiUnavailable extends ApiException {
  const ApiUnavailable({this.requestSent = true});

  /// False when the connection failed, so the server never saw the request
  /// and another address may take it (tech.md 35.1).
  final bool requestSent;
}

/// What features use. The generated client and the fake stay behind it.
abstract interface class ApiClient {
  Future<ProfileFetch> fetchProfile({String? etag});

  Future<TelegramLoginChallenge> startTelegramLogin(TelegramLoginStart body);

  Future<AuthResult> verifyTelegramLogin(TelegramLoginVerify body);

  /// Revokes the current device. The server answers 204.
  Future<void> logout();
}

class HttpApiClient implements ApiClient {
  HttpApiClient(this._client);

  final VpnApiClient _client;

  static const _serverErrorStart = 500;
  static const _notModified = 304;

  static Object _translate(DioException error) {
    final response = error.response;
    if (response == null || response.statusCode == null) {
      return ApiUnavailable(
        requestSent:
            error.type != DioExceptionType.connectionTimeout &&
            error.type != DioExceptionType.connectionError,
      );
    }
    final status = response.statusCode!;
    if (status >= _serverErrorStart) {
      return const ApiUnavailable();
    }
    final body = response.data;
    final fields = body is Map<String, Object?>
        ? body
        : const <String, Object?>{};
    final raw = fields['code'];
    return ApiProblem(
      status,
      ProblemCode.values.where((code) => code.json == raw).firstOrNull,
      botUrl: fields['botUrl'] is String ? fields['botUrl']! as String : null,
      attemptsLeft: _int(fields['attemptsLeft']),
      retryAfterSec: _int(fields['retryAfterSec']),
    );
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<TelegramLoginChallenge> startTelegramLogin(TelegramLoginStart body) =>
      _guard(() async {
        final response = await _client.auth.startTelegramLogin(body: body);
        return response.data;
      });

  @override
  Future<AuthResult> verifyTelegramLogin(TelegramLoginVerify body) =>
      _guard(() async {
        final response = await _client.auth.verifyTelegramLogin(body: body);
        return response.data;
      });

  @override
  Future<void> logout() => _guard(_client.auth.logout);

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

  /// Thrown by start, verify, and logout instead of answering.
  ApiException? authFailure;
  final starts = <TelegramLoginStart>[];
  final verifies = <TelegramLoginVerify>[];
  int logouts = 0;

  static const _fakeId = '00000000-0000-4000-8000-000000000001';
  static const _resendAfterSec = 60;
  static const _codeLifetime = Duration(minutes: 5);

  void _failIfScripted() {
    final scriptedFailure = authFailure;
    if (scriptedFailure != null) {
      throw scriptedFailure;
    }
  }

  @override
  Future<TelegramLoginChallenge> startTelegramLogin(
    TelegramLoginStart body,
  ) async {
    starts.add(body);
    _failIfScripted();
    return TelegramLoginChallenge(
      loginId: _fakeId,
      expiresAt: DateTime.now().toUtc().add(_codeLifetime),
      resendAfterSec: _resendAfterSec,
      botUrl: 'https://t.me/vpnclient_bot',
    );
  }

  @override
  Future<AuthResult> verifyTelegramLogin(TelegramLoginVerify body) async {
    verifies.add(body);
    _failIfScripted();
    return const AuthResult(
      deviceId: _fakeId,
      accountId: _fakeId,
      token: 'fake-device-token',
    );
  }

  @override
  Future<void> logout() async {
    logouts++;
    _failIfScripted();
  }

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
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: apiAttemptTimeout,
      receiveTimeout: apiAttemptTimeout,
    ),
  )..interceptors.add(AuthInterceptor(tokens));
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return VpnApiClient(dio, baseUrl: baseUrl);
}
