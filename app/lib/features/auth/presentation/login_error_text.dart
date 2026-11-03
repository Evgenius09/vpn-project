import '../../../gen/l10n/app_localizations.dart';
import '../domain/login_state.dart';

String loginErrorText(AppLocalizations strings, LoginError error) =>
    switch (error.failure) {
      LoginFailure.invalidUsername => strings.loginInvalidUsername,
      LoginFailure.botLinkFailed => strings.loginLinkFailed,
      LoginFailure.unavailable => strings.loginErrorUnavailable,
      LoginFailure.unexpected => strings.loginErrorUnexpected,
      LoginFailure.unauthorized => strings.loginErrorUnauthorized,
      LoginFailure.deviceRevoked => strings.loginErrorDeviceRevoked,
      LoginFailure.validationFailed => strings.loginErrorValidationFailed,
      LoginFailure.rateLimited => switch (error.retryAfterSec) {
        final int seconds => strings.loginErrorRateLimited(seconds),
        null => strings.loginErrorRateLimitedLater,
      },
      LoginFailure.telegramUserNotFound => strings.loginErrorUserNotFound,
      LoginFailure.codeInvalid => switch (error.attemptsLeft) {
        final int attempts => strings.loginErrorCodeInvalid(attempts),
        null => strings.loginErrorCodeInvalidNoCount,
      },
      LoginFailure.codeExpired => strings.loginErrorCodeExpired,
      LoginFailure.deviceLimitReached => strings.loginErrorDeviceLimit,
      LoginFailure.panelUnavailable => strings.loginErrorPanelUnavailable,
      LoginFailure.notFound => strings.loginErrorNotFound,
      LoginFailure.internal => strings.loginErrorInternal,
    };
