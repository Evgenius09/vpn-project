import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'VPN Client'**
  String get appTitle;

  /// No description provided for @modeRegular.
  ///
  /// In ru, this message translates to:
  /// **'Обычный VPN'**
  String get modeRegular;

  /// No description provided for @modeWhitelist.
  ///
  /// In ru, this message translates to:
  /// **'Белые списки'**
  String get modeWhitelist;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get settingsTooltip;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// No description provided for @lockedByProvider.
  ///
  /// In ru, this message translates to:
  /// **'Задано провайдером'**
  String get lockedByProvider;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @pingUnknown.
  ///
  /// In ru, this message translates to:
  /// **'—'**
  String get pingUnknown;

  /// No description provided for @pingUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи'**
  String get pingUnreachable;

  /// No description provided for @emptyScreenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Скоро здесь будет экран'**
  String get emptyScreenTitle;

  /// No description provided for @powerButtonLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get powerButtonLabel;

  /// No description provided for @kitchenSinkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Витрина компонентов'**
  String get kitchenSinkTitle;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая тема'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get themeDark;

  /// No description provided for @pingMs.
  ///
  /// In ru, this message translates to:
  /// **'{value} мс'**
  String pingMs(int value);

  /// No description provided for @speedBytes.
  ///
  /// In ru, this message translates to:
  /// **'{value} Б/с'**
  String speedBytes(String value);

  /// No description provided for @speedKilobytes.
  ///
  /// In ru, this message translates to:
  /// **'{value} КБ/с'**
  String speedKilobytes(String value);

  /// No description provided for @speedMegabytes.
  ///
  /// In ru, this message translates to:
  /// **'{value} МБ/с'**
  String speedMegabytes(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
