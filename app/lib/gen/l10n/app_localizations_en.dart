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
  String get pingRefresh => 'Check ping';

  @override
  String get pingSortByPing => 'Sort by ping';

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

  @override
  String get connectionDisconnected => 'Disconnected';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String connectionConnected(String time) {
    return 'Connected $time';
  }

  @override
  String get connectionDisconnecting => 'Disconnecting…';

  @override
  String get connectionFailed => 'Connection error';

  @override
  String connectionActiveElsewhere(String mode) {
    return 'Now active: $mode';
  }

  @override
  String get connectionErrorConfigInvalid =>
      'The connection settings are invalid. Update the app or contact support.';

  @override
  String get connectionErrorStartFailed =>
      'Could not start the VPN. Try again or pick another server.';

  @override
  String get connectionErrorNoServers => 'No servers for this mode yet.';

  @override
  String get connectionErrorPermissionDenied =>
      'Allow the VPN connection to turn the VPN on.';

  @override
  String get connectionErrorTunFailed =>
      'Could not create the VPN interface. Restart the device and try again.';

  @override
  String get connectionErrorRevoked =>
      'Another VPN app took over the connection.';

  @override
  String get connectionErrorServiceUnavailable =>
      'The VPN service is not responding. Reinstall the app.';

  @override
  String get connectionErrorVersionMismatch =>
      'The VPN service and the app versions differ. Reinstall the app.';

  @override
  String get connectionErrorInternal =>
      'Something went wrong inside the VPN. Try again.';

  @override
  String modeNoticeCellular(String mode) {
    return 'Mobile network: switched to $mode';
  }

  @override
  String modeNoticeWifi(String mode) {
    return 'Network changed: switched to $mode';
  }

  @override
  String modeNoticeOverrideCleared(String mode) {
    return 'Auto switch follows the network again: switched to $mode';
  }

  @override
  String modeNoticeNoWhitelist(String mode) {
    return 'No whitelist servers: $mode stays on';
  }

  @override
  String get autoSwitchTitle => 'Whitelists on mobile data';

  @override
  String get autoSwitchSubtitle =>
      'Switch to whitelists when Wi-Fi gives way to mobile data';

  @override
  String get settingsConnection => 'Connection';

  @override
  String get brandWordmark => 'СВОИ.';

  @override
  String get brandTagline => 'Your own VPN, no extra settings';

  @override
  String get telegramTooltip => 'Open the bot in Telegram';

  @override
  String get connectionTapToConnect => 'Tap to connect';

  @override
  String get connectionTapToSwitch => 'Tap to switch here';

  @override
  String get pingSortByPingShort => 'By ping';

  @override
  String get pingSortByOrder => 'Default order';

  @override
  String get modeSwitchHint => 'Switch the mode screen';

  @override
  String get settingsBasics => 'Basics';

  @override
  String get accountTrial => 'Trial';

  @override
  String get accountActive => 'Subscription active';

  @override
  String get accountExpired => 'Subscription ended';

  @override
  String get accountBlocked => 'Account blocked';

  @override
  String get accountProvisioning => 'Preparing access…';

  @override
  String accountUntil(String date) {
    return 'until $date';
  }

  @override
  String get accountTraffic => 'Traffic';

  @override
  String get accountTrafficUnlimited => 'Unlimited';

  @override
  String accountTrafficUsed(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String get accountRenew => 'Renew in the bot';

  @override
  String get loginCodeLabel => 'Code from Telegram';

  @override
  String get loginUsernameHint =>
      'Your username is in Telegram → Settings → Username';

  @override
  String get loginBotFooter => 'Never started the bot? Open it and press Start';

  @override
  String get loginCodeFooter => 'No code? Check the chat with the bot';

  @override
  String get protocolVlessReality => 'VLESS Reality';

  @override
  String get protocolHysteria2 => 'Hysteria2';
}
