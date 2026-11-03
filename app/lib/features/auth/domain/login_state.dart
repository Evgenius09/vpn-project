/// Why a login step failed. Each problem code of tech.md 5.2 has its own
/// value, so each gets its own text.
enum LoginFailure {
  invalidUsername,
  botLinkFailed,
  unavailable,
  unexpected,
  unauthorized,
  deviceRevoked,
  validationFailed,
  rateLimited,
  telegramUserNotFound,
  codeInvalid,
  codeExpired,
  deviceLimitReached,
  panelUnavailable,
  notFound,
  internal,
}

class LoginError {
  const LoginError(
    this.failure, {
    this.botUrl,
    this.attemptsLeft,
    this.retryAfterSec,
  });

  final LoginFailure failure;
  final String? botUrl;
  final int? attemptsLeft;
  final int? retryAfterSec;
}

class LoginException implements Exception {
  const LoginException(this.error);

  final LoginError error;

  @override
  String toString() => 'LoginException(${error.failure.name})';
}

sealed class LoginState {
  const LoginState({this.error, this.busy = false});

  final LoginError? error;

  /// A request is in flight, so the controls wait.
  final bool busy;
}

/// The nick field.
final class LoginUsername extends LoginState {
  const LoginUsername({this.username = '', super.error, super.busy});

  /// What the field shows: the last nick the user typed.
  final String username;
}

/// The bot has never seen this nick: the user has to press Start first.
final class LoginBotNotStarted extends LoginState {
  const LoginBotNotStarted({
    required this.username,
    required this.botUrl,
    super.error,
    super.busy,
  });

  final String username;
  final String? botUrl;
}

/// The bot sent a code.
final class LoginCode extends LoginState {
  const LoginCode({
    required this.username,
    required this.loginId,
    required this.botUrl,
    required this.resendIn,
    this.attempt = 0,
    super.error,
    super.busy,
  });

  final String username;
  final String loginId;
  final String botUrl;

  /// Seconds until the code can be sent again. Zero means now.
  final int resendIn;

  /// Grows after each rejected code, so the screen starts with empty cells.
  final int attempt;

  LoginCode copyWith({
    int? resendIn,
    int? attempt,
    LoginError? error,
    bool clearError = false,
    bool? busy,
  }) => LoginCode(
    username: username,
    loginId: loginId,
    botUrl: botUrl,
    resendIn: resendIn ?? this.resendIn,
    attempt: attempt ?? this.attempt,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
  );
}
