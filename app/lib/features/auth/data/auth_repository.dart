import '../../../core/api/api_client.dart';
import '../../../core/device/device_identity.dart';
import '../../../gen/api/export.dart';
import '../domain/login_state.dart';

/// Translates an API failure into what the login screen shows.
LoginError loginErrorOf(ApiException exception) => switch (exception) {
  ApiUnavailable() => const LoginError(LoginFailure.unavailable),
  ApiProblem(
    :final code,
    :final botUrl,
    :final attemptsLeft,
    :final retryAfterSec,
  ) =>
    LoginError(
      _failureOf(code),
      botUrl: botUrl,
      attemptsLeft: attemptsLeft,
      retryAfterSec: retryAfterSec,
    ),
};

LoginFailure _failureOf(ProblemCode? code) => switch (code) {
  null => LoginFailure.unexpected,
  ProblemCode.unauthorized => LoginFailure.unauthorized,
  ProblemCode.deviceRevoked => LoginFailure.deviceRevoked,
  ProblemCode.validationFailed => LoginFailure.validationFailed,
  ProblemCode.rateLimited => LoginFailure.rateLimited,
  ProblemCode.telegramUserNotFound => LoginFailure.telegramUserNotFound,
  ProblemCode.codeInvalid => LoginFailure.codeInvalid,
  ProblemCode.codeExpired => LoginFailure.codeExpired,
  ProblemCode.deviceLimitReached => LoginFailure.deviceLimitReached,
  ProblemCode.panelUnavailable => LoginFailure.panelUnavailable,
  ProblemCode.notFound => LoginFailure.notFound,
  ProblemCode.internal => LoginFailure.internal,
};

class AuthRepository {
  AuthRepository(this._api, this._device, {required this.appVersion});

  final ApiClient _api;
  final Future<DeviceIdentity> Function() _device;
  final String appVersion;

  static Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (exception) {
      throw LoginException(loginErrorOf(exception));
    }
  }

  /// Asks the bot to send a code to [username], which is already normalized.
  Future<TelegramLoginChallenge> start(String username) async {
    final device = await _device();
    return _call(
      () => _api.startTelegramLogin(
        TelegramLoginStart(
          username: username,
          installId: device.installId,
          model: device.model,
        ),
      ),
    );
  }

  /// Exchanges the code for a device token.
  Future<String> verify(String loginId, String code) async {
    final device = await _device();
    final result = await _call(
      () => _api.verifyTelegramLogin(
        TelegramLoginVerify(
          loginId: loginId,
          code: code,
          installId: device.installId,
          platform: device.platform,
          model: device.model,
          appVersion: appVersion,
        ),
      ),
    );
    return result.token;
  }

  /// Revokes the device on the server. A failure must not keep the user
  /// signed in on this device, so it is ignored.
  Future<void> logout() async {
    try {
      await _api.logout();
    } on ApiException {
      // An offline or already revoked device still signs out locally.
    }
  }
}
