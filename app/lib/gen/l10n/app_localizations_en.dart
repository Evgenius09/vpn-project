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
  String get loginTitle => 'Sign in';

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
}
