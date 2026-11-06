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

  @override
  String get setSectionBasics => 'Basics';

  @override
  String get setAutoSwitch => 'Auto switch to whitelists';

  @override
  String get setAutoSwitchHint => 'When Wi-Fi gives way to mobile data';

  @override
  String get setConnectOnOpen => 'Connect on open';

  @override
  String get setConnectOnOpenHint => 'Right after the app starts';

  @override
  String get setSectionThroughVpn => 'What goes through VPN';

  @override
  String get setTunneling => 'Split tunneling (apps)';

  @override
  String get setRulesProfile => 'Rules profile (sites)';

  @override
  String get setSectionLook => 'Appearance';

  @override
  String get setTheme => 'Theme';

  @override
  String get setLanguage => 'Language';

  @override
  String get setSectionMore => 'More';

  @override
  String get setSupport => 'Support';

  @override
  String get setSupportHint => 'Write in Telegram';

  @override
  String get setAdvanced => 'Advanced';

  @override
  String get setAdvancedHint => 'Routing, DNS, network, ping';

  @override
  String get setTrafficRegular => 'Regular VPN traffic';

  @override
  String get setTrafficWhitelist => 'Whitelist traffic';

  @override
  String get setUnlimited => '∞  Unlimited';

  @override
  String get tunTitle => 'Tunneling';

  @override
  String get tunIntro =>
      'Split tunneling: pick the apps that bypass the VPN, such as banks and government services.';

  @override
  String get tunSectionMode => 'Mode';

  @override
  String get tunOff => 'Off';

  @override
  String get tunOffHint => 'Every app goes through the VPN';

  @override
  String get tunExcept => 'All but the selected';

  @override
  String get tunExceptHint => 'The checked apps work without the VPN';

  @override
  String get tunOnly => 'Only the selected';

  @override
  String get tunOnlyHint => 'Only the checked apps go through the VPN';

  @override
  String get tunAppsBypass => 'Apps without VPN';

  @override
  String get tunAppsThrough => 'Apps through VPN';

  @override
  String get tunSearch => 'Search apps';

  @override
  String get tunNoApps => 'No apps found';

  @override
  String get rulesTitle => 'Rules profile';

  @override
  String get rulesSection => 'How sites go';

  @override
  String get rulesRuDirect => 'Russia direct';

  @override
  String get rulesRuDirectHint =>
      'Russian sites without VPN, the rest through VPN';

  @override
  String get rulesRuDirectShort => 'Russia direct, the rest through VPN';

  @override
  String get rulesAll => 'Everything through VPN';

  @override
  String get rulesAllHint => 'All traffic goes through the server';

  @override
  String get rulesCustom => 'Only my rules';

  @override
  String get rulesCustomHint => 'Only your rules apply';

  @override
  String get themeSection => 'Look';

  @override
  String get themeDarkName => 'Dark';

  @override
  String get themeDarkHint => 'Easy on the eyes and the battery';

  @override
  String get themeLightName => 'Light';

  @override
  String get themeLightHint => 'Light background, dark text';

  @override
  String get themeSystemName => 'As in the system';

  @override
  String get themeSystemHint => 'Follows the phone';

  @override
  String get langSection => 'App language';

  @override
  String get langRu => 'Русский';

  @override
  String get langRuHint => 'Russian';

  @override
  String get langEn => 'English';

  @override
  String get langEnHint => 'English';

  @override
  String get langSystem => 'As in the system';

  @override
  String get langSystemHint => 'The phone language';

  @override
  String get supSectionContact => 'Contact us';

  @override
  String get supWrite => 'Write to support';

  @override
  String get supWriteHint => '@svoi_support in Telegram';

  @override
  String get supBot => 'Open the bot';

  @override
  String get supBotHint => 'Plan, renewal, devices';

  @override
  String get supSectionAbout => 'About the app';

  @override
  String get supSite => 'Website';

  @override
  String get supSiteHint => 'svoi.app';

  @override
  String get supVersion => 'Version';

  @override
  String supVersionValue(String version) {
    return '$version · Android';
  }

  @override
  String get supFooter =>
      'We answer in Telegram within a day.\nWe keep no history of your connections.';

  @override
  String get advSectionRouting => 'Routing';

  @override
  String get advRouting => 'Routing';

  @override
  String get advRoutingHint => 'Russian sites open directly';

  @override
  String get advCustomRules => 'My rules';

  @override
  String advCustomRulesHint(int count) {
    return '$count rules · domains and IP addresses';
  }

  @override
  String get advSectionDns => 'DNS';

  @override
  String get advDnsRemote => 'DNS through VPN';

  @override
  String get advDnsDirect => 'Direct DNS';

  @override
  String get advAddressOrder => 'Address order';

  @override
  String get advSectionNetwork => 'Network';

  @override
  String get advIpv6 => 'IPv6';

  @override
  String get advIpv6Hint => 'Rarely needed, steadier without it';

  @override
  String get advSniffing => 'Site detection (sniffing)';

  @override
  String get advSniffingHint => 'Helps the routing rules';

  @override
  String get advTlsFragment => 'TLS fragmentation';

  @override
  String get advTlsFragmentHint => 'Turn on if sites do not open';

  @override
  String get advBypassLan => 'Bypass the local network';

  @override
  String get advBypassLanHint => 'The router and printers stay reachable';

  @override
  String get advMtu => 'MTU';

  @override
  String get advTunMode => 'TUN mode';

  @override
  String get advExcluded => 'Excluded addresses';

  @override
  String get advExcludedNone => 'None';

  @override
  String get advSectionPing => 'Ping';

  @override
  String get advPingMethod => 'Check method';

  @override
  String get advPingUrl => 'Check address';

  @override
  String get advPingTimeout => 'Timeout';

  @override
  String get advPingOnOpen => 'Check on open';

  @override
  String get advPingOnOpenHint => 'Ping the servers when the app starts';

  @override
  String get advSectionConnect => 'Connection';

  @override
  String get advAutoConnect => 'Server for auto connect';

  @override
  String get addrSection => 'IP version';

  @override
  String get addrV4First => 'IPv4 first';

  @override
  String get addrV4FirstHint => 'Recommended: works on any network';

  @override
  String get addrV6First => 'IPv6 first';

  @override
  String get addrV6FirstHint => 'If your network supports IPv6';

  @override
  String get addrV4Only => 'IPv4 only';

  @override
  String get addrV4OnlyHint => 'IPv6 is not used';

  @override
  String get addrV6Only => 'IPv6 only';

  @override
  String get addrV6OnlyHint => 'For IPv6-only networks';

  @override
  String get tunModeSection => 'Mode';

  @override
  String get tunGvisorHint => 'Reliable, suits most phones';

  @override
  String get tunSystemHint => 'Faster, but not on every phone';

  @override
  String get tunMixedHint => 'Mixed mode';

  @override
  String get pingMethodSection => 'How to check ping';

  @override
  String get pingTcpHint => 'Fast: checks that the server answers';

  @override
  String get pingUrlTest => 'URL test';

  @override
  String get pingUrlTestHint => 'More exact: loads a page through the server';

  @override
  String get timeoutSection => 'How long to wait';

  @override
  String get timeout1 => '1 second';

  @override
  String get timeout1Hint => 'Fast, but slow servers drop out';

  @override
  String get timeout3 => '3 seconds';

  @override
  String get timeout3Hint => 'Recommended';

  @override
  String get timeout5 => '5 seconds';

  @override
  String get timeout5Hint => 'For slow internet';

  @override
  String get autoSection => 'Which server to pick';

  @override
  String get autoLast => 'Last used';

  @override
  String get autoLastHint => 'The one you used last time';

  @override
  String get autoBest => 'Best ping';

  @override
  String get autoBestHint => 'The fastest at launch';

  @override
  String get autoRandom => 'Random';

  @override
  String get autoRandomHint => 'Any available server';

  @override
  String get inputQuick => 'Quick pick';

  @override
  String get dnsAddress => 'DNS server address';

  @override
  String get dnsRemoteNote =>
      'A DoH server address. Queries go through the VPN and stay hidden from the carrier.';

  @override
  String get dnsDirectNote =>
      'An IP address or DoH. Used for sites that open without the VPN.';

  @override
  String get dnsYandex => 'Yandex';

  @override
  String get mtuSection => 'Packet size';

  @override
  String get mtuNote => 'From 1280 to 9000. If sites load partly, try 1400.';

  @override
  String get mtu1500Hint => 'Standard, recommended';

  @override
  String get mtu1400Hint => 'If sites load partly';

  @override
  String get mtu1280Hint => 'The minimum';

  @override
  String get pingUrlSection => 'Page address';

  @override
  String get pingUrlNote =>
      'The page a URL test loads to measure ping through the server.';

  @override
  String get crSection => 'Rules';

  @override
  String get crFooter =>
      'Rules apply top down, the first match wins. Hold a rule to change the order.';

  @override
  String get crAdd => 'Add';

  @override
  String crRuleLine(String match, String action) {
    return '$match → $action';
  }

  @override
  String get exTitle => 'Exclusions';

  @override
  String get exSection => 'Addresses past the VPN';

  @override
  String get exFooter =>
      'These addresses and subnets always bypass the VPN, such as a home router or a work network.';

  @override
  String get exHome => 'Home network';

  @override
  String get exWork => 'Work network';

  @override
  String get exRemove => 'Remove';

  @override
  String get nrTitle => 'New rule';

  @override
  String get nrAddress => 'Site address or IP';

  @override
  String get nrMatchSection => 'What to match';

  @override
  String get nrSuffix => 'Domain and subdomains';

  @override
  String nrSuffixHint(String host) {
    return '$host, m.$host and more';
  }

  @override
  String get nrExact => 'Exact domain';

  @override
  String nrExactHint(String host) {
    return 'Only $host';
  }

  @override
  String get nrKeyword => 'Contains a word';

  @override
  String nrKeywordHint(String word) {
    return 'Any address with the word $word';
  }

  @override
  String get nrIp => 'IP address or subnet';

  @override
  String get nrIpHint => 'For example, 8.8.8.8 or 10.0.0.0/8';

  @override
  String get nrActionSection => 'What to do';

  @override
  String get nrProxy => 'Through VPN';

  @override
  String get nrProxyHint => 'Open through the server';

  @override
  String get nrDirect => 'Direct';

  @override
  String get nrDirectHint => 'Open without the VPN';

  @override
  String get nrBlock => 'Block';

  @override
  String get nrBlockHint => 'Never open, such as ads';

  @override
  String get nrActionProxyShort => 'through VPN';

  @override
  String get nrActionDirectShort => 'direct';

  @override
  String get nrActionBlockShort => 'block';

  @override
  String get connectionNotConnected => 'Not connected';

  @override
  String get connectionConnectedShort => 'Connected';

  @override
  String get connectionUnavailable => 'Unavailable';

  @override
  String get pingSortByAlphabet => 'Alphabetically';

  @override
  String get freeServer => 'Free server';

  @override
  String get freeServerHint => 'Telegram only';

  @override
  String get freeGetFull => 'Get full access in the Telegram bot';

  @override
  String get freeHaveAccount => 'Have an account? Sign in';

  @override
  String get freeWhitelistHint => 'The free mode has no whitelist bypass';

  @override
  String get freeWhitelistTitle => 'Whitelists unavailable';

  @override
  String get freeWhitelistText =>
      'This mode helps when mobile internet is limited to whitelists. It opens after you sign in through the Telegram bot.';

  @override
  String get loginOpenBotTelegram => 'Open the bot in Telegram';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginNewCode => 'Get a new code';

  @override
  String loginResendInTimer(String time) {
    return 'Send the code again in $time';
  }

  @override
  String get loginBotNotFound => 'The nick is not among the bot users';

  @override
  String get loginNoNickFooter =>
      'No nick in Telegram? The bot explains how to set one';

  @override
  String loginCodeIntro(String username) {
    return 'The bot sent 6 digits in Telegram to @$username. The code works for 5 minutes.';
  }

  @override
  String loginBotIntro(String username) {
    return '@$username is not among the bot users. Open the bot, press Start and come back.';
  }

  @override
  String get loginBotHeading => 'Open the bot';

  @override
  String get unitGb => 'GB';

  @override
  String get advAutoConnectTitle => 'Auto connect';
}
