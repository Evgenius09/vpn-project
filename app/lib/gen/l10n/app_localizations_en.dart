// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VPN Client';

  @override
  String get modeRegular => 'Regular VPN';

  @override
  String get modeWhitelist => 'Whitelists';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Open settings';

  @override
  String get lockedByProvider => 'Set by provider';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get pingUnknown => '—';

  @override
  String get pingUnreachable => 'Unreachable';

  @override
  String get emptyScreenTitle => 'This screen is coming soon';

  @override
  String get powerButtonLabel => 'Connection';

  @override
  String get kitchenSinkTitle => 'Component gallery';

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String pingMs(int value) {
    return '$value ms';
  }

  @override
  String speedBytes(String value) {
    return '$value B/s';
  }

  @override
  String speedKilobytes(String value) {
    return '$value KB/s';
  }

  @override
  String speedMegabytes(String value) {
    return '$value MB/s';
  }

  @override
  String get serversTitle => 'Servers';

  @override
  String get serversEmpty => 'No servers yet';

  @override
  String get profileLoadFailed => 'Could not load the profile';

  @override
  String get profileFromCache => 'Server unreachable, showing saved data';

  @override
  String get loginUsernameTitle => 'Sign in with Telegram';

  @override
  String get loginUsernameMessage =>
      'Enter your Telegram username. The bot will send you a sign-in code.';

  @override
  String get loginUsernameLabel => 'Telegram username';

  @override
  String get loginGetCode => 'Get code';

  @override
  String get loginInvalidUsername =>
      'Use 4 to 32 Latin letters, digits, or underscores';

  @override
  String get loginBotTitle => 'Open the bot and press Start';

  @override
  String get loginBotMessage =>
      'The bot can only write to people who started it. Press Start in the bot, then come back here.';

  @override
  String get loginOpenBot => 'Open bot';

  @override
  String get loginPressedStart => 'I pressed Start, send the code';

  @override
  String get loginChangeUsername => 'Change username';

  @override
  String get loginCodeTitle => 'Enter the code';

  @override
  String loginCodeMessage(String username) {
    return 'The bot sent a 6-digit code to @$username.';
  }

  @override
  String loginResendIn(int seconds) {
    return 'Send again in $seconds s';
  }

  @override
  String get loginResend => 'Send the code again';

  @override
  String get loginLinkFailed => 'Could not open the link';

  @override
  String get loginErrorUnavailable =>
      'No connection to the server. Check the internet and try again.';

  @override
  String get loginErrorUnexpected =>
      'Unexpected answer from the server. Try again.';

  @override
  String get loginErrorUnauthorized => 'Your session has ended. Sign in again.';

  @override
  String get loginErrorDeviceRevoked =>
      'This device was disconnected from the account. Sign in again.';

  @override
  String get loginErrorValidationFailed =>
      'The server did not accept the data. Check the username and the code.';

  @override
  String loginErrorRateLimited(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get loginErrorRateLimitedLater =>
      'Too many attempts. Try again later.';

  @override
  String get loginErrorUserNotFound =>
      'No bot user has this username. Open the bot and press Start.';

  @override
  String loginErrorCodeInvalid(int attempts) {
    return 'Wrong code. Attempts left: $attempts.';
  }

  @override
  String get loginErrorCodeInvalidNoCount => 'Wrong code.';

  @override
  String get loginErrorCodeExpired =>
      'The code has expired or the attempts ran out. Request a new code.';

  @override
  String get loginErrorDeviceLimit =>
      'Your account has reached its device limit. Disconnect another device and enter the code again.';

  @override
  String get loginErrorPanelUnavailable =>
      'The VPN service is temporarily unavailable. Try again later.';

  @override
  String get loginErrorNotFound =>
      'The server could not find the request. Start the sign-in again.';

  @override
  String get loginErrorInternal =>
      'Something went wrong on the server. Try again later.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get logoutButton => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage =>
      'The VPN turns off and this device leaves your account. To come back, sign in with a new code from the bot.';

  @override
  String get logoutConfirm => 'Log out now';
}
