import '../../gen/api/export.dart';
import 'api_client.dart';

/// Each address gets this long to connect and this long to answer
/// (tech.md 35.1).
const apiAttemptTimeout = Duration(seconds: 9);

/// The order of API addresses: those of the last profile, then the build's,
/// without repeats (tech.md 35.1).
class ApiEndpoints {
  ApiEndpoints(this._built);

  final List<String> _built;
  List<String> _fromProfile = const [];

  void learn(List<String> fromProfile) =>
      _fromProfile = List.unmodifiable(fromProfile);

  List<String> get ordered => {..._fromProfile, ..._built}.toList();
}

/// Tries the addresses of [ApiEndpoints] in order. A server's answer, even an
/// error, ends the search.
class FallbackApiClient implements ApiClient {
  FallbackApiClient(this._endpoints, this._clientFor);

  final ApiEndpoints _endpoints;
  final ApiClient Function(String baseUrl) _clientFor;
  final _clients = <String, ApiClient>{};

  /// [repeatable] false moves on only when the request never left: a second
  /// start trips the cooldown and a second verify burns the one-time code.
  Future<T> _each<T>(
    Future<T> Function(ApiClient client) call, {
    required bool repeatable,
  }) async {
    var failure = const ApiUnavailable(requestSent: false);
    for (final url in _endpoints.ordered) {
      try {
        return await call(_clients.putIfAbsent(url, () => _clientFor(url)));
      } on ApiUnavailable catch (error) {
        if (!repeatable && error.requestSent) {
          rethrow;
        }
        failure = error;
      }
    }
    throw failure;
  }

  @override
  Future<ProfileFetch> fetchProfile({String? etag}) =>
      _each((client) => client.fetchProfile(etag: etag), repeatable: true);

  @override
  Future<TelegramLoginChallenge> startTelegramLogin(TelegramLoginStart body) =>
      _each((client) => client.startTelegramLogin(body), repeatable: false);

  @override
  Future<AuthResult> verifyTelegramLogin(TelegramLoginVerify body) =>
      _each((client) => client.verifyTelegramLogin(body), repeatable: false);

  @override
  Future<void> logout() =>
      _each((client) => client.logout(), repeatable: false);
}
