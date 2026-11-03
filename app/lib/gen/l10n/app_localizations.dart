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

  /// No description provided for @serversTitle.
  ///
  /// In ru, this message translates to:
  /// **'Серверы'**
  String get serversTitle;

  /// No description provided for @serversEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Серверов пока нет'**
  String get serversEmpty;

  /// No description provided for @pingRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Проверить пинг'**
  String get pingRefresh;

  /// No description provided for @pingSortByPing.
  ///
  /// In ru, this message translates to:
  /// **'Сортировать по пингу'**
  String get pingSortByPing;

  /// No description provided for @profileLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить профиль'**
  String get profileLoadFailed;

  /// No description provided for @profileFromCache.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером, показаны сохранённые данные'**
  String get profileFromCache;

  /// No description provided for @loginUsernameTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход через Telegram'**
  String get loginUsernameTitle;

  /// No description provided for @loginUsernameMessage.
  ///
  /// In ru, this message translates to:
  /// **'Введите ваш ник в Telegram. Бот пришлёт код для входа.'**
  String get loginUsernameMessage;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ник в Telegram'**
  String get loginUsernameLabel;

  /// No description provided for @loginGetCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get loginGetCode;

  /// No description provided for @loginInvalidUsername.
  ///
  /// In ru, this message translates to:
  /// **'Ник: от 4 до 32 латинских букв, цифр или знаков подчёркивания'**
  String get loginInvalidUsername;

  /// No description provided for @loginBotTitle.
  ///
  /// In ru, this message translates to:
  /// **'Откройте бота и нажмите Start'**
  String get loginBotTitle;

  /// No description provided for @loginBotMessage.
  ///
  /// In ru, this message translates to:
  /// **'Бот может написать только тем, кто его запустил. Нажмите Start в боте и вернитесь сюда.'**
  String get loginBotMessage;

  /// No description provided for @loginOpenBot.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бота'**
  String get loginOpenBot;

  /// No description provided for @loginPressedStart.
  ///
  /// In ru, this message translates to:
  /// **'Я нажал Start, отправить код'**
  String get loginPressedStart;

  /// No description provided for @loginChangeUsername.
  ///
  /// In ru, this message translates to:
  /// **'Изменить ник'**
  String get loginChangeUsername;

  /// No description provided for @loginCodeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Введите код'**
  String get loginCodeTitle;

  /// No description provided for @loginCodeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Бот отправил 6-значный код пользователю @{username}.'**
  String loginCodeMessage(String username);

  /// No description provided for @loginResendIn.
  ///
  /// In ru, this message translates to:
  /// **'Отправить снова через {seconds} с'**
  String loginResendIn(int seconds);

  /// No description provided for @loginResend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код снова'**
  String get loginResend;

  /// No description provided for @loginLinkFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть ссылку'**
  String get loginLinkFailed;

  /// No description provided for @loginErrorUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Проверьте интернет и повторите.'**
  String get loginErrorUnavailable;

  /// No description provided for @loginErrorUnexpected.
  ///
  /// In ru, this message translates to:
  /// **'Неожиданный ответ сервера. Повторите.'**
  String get loginErrorUnexpected;

  /// No description provided for @loginErrorUnauthorized.
  ///
  /// In ru, this message translates to:
  /// **'Сессия завершилась. Войдите снова.'**
  String get loginErrorUnauthorized;

  /// No description provided for @loginErrorDeviceRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство отключено от аккаунта. Войдите снова.'**
  String get loginErrorDeviceRevoked;

  /// No description provided for @loginErrorValidationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не принял данные. Проверьте ник и код.'**
  String get loginErrorValidationFailed;

  /// No description provided for @loginErrorRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Повторите через {seconds} с.'**
  String loginErrorRateLimited(int seconds);

  /// No description provided for @loginErrorRateLimitedLater.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Повторите позже.'**
  String get loginErrorRateLimitedLater;

  /// No description provided for @loginErrorUserNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Ник не найден среди пользователей бота. Откройте бота и нажмите Start.'**
  String get loginErrorUserNotFound;

  /// No description provided for @loginErrorCodeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код. Осталось попыток: {attempts}.'**
  String loginErrorCodeInvalid(int attempts);

  /// No description provided for @loginErrorCodeInvalidNoCount.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код.'**
  String get loginErrorCodeInvalidNoCount;

  /// No description provided for @loginErrorCodeExpired.
  ///
  /// In ru, this message translates to:
  /// **'Код истёк или попытки закончились. Запросите новый код.'**
  String get loginErrorCodeExpired;

  /// No description provided for @loginErrorDeviceLimit.
  ///
  /// In ru, this message translates to:
  /// **'Достигнут лимит устройств аккаунта. Отключите другое устройство и введите код снова.'**
  String get loginErrorDeviceLimit;

  /// No description provided for @loginErrorPanelUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сервис VPN временно недоступен. Повторите позже.'**
  String get loginErrorPanelUnavailable;

  /// No description provided for @loginErrorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не нашёл запрос. Начните вход заново.'**
  String get loginErrorNotFound;

  /// No description provided for @loginErrorInternal.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка на сервере. Повторите позже.'**
  String get loginErrorInternal;

  /// No description provided for @settingsAccount.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get settingsAccount;

  /// No description provided for @logoutButton.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get logoutButton;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In ru, this message translates to:
  /// **'VPN отключится, а устройство выйдет из аккаунта. Чтобы вернуться, войдите с новым кодом из бота.'**
  String get logoutConfirmMessage;

  /// No description provided for @logoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logoutConfirm;

  /// No description provided for @connectionDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Отключено'**
  String get connectionDisconnected;

  /// No description provided for @connectionConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение…'**
  String get connectionConnecting;

  /// No description provided for @connectionConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключено {time}'**
  String connectionConnected(String time);

  /// No description provided for @connectionDisconnecting.
  ///
  /// In ru, this message translates to:
  /// **'Отключение…'**
  String get connectionDisconnecting;

  /// No description provided for @connectionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения'**
  String get connectionFailed;

  /// No description provided for @connectionActiveElsewhere.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас активен: {mode}'**
  String connectionActiveElsewhere(String mode);

  /// No description provided for @connectionErrorConfigInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Настройки подключения неверны. Обновите приложение или напишите в поддержку.'**
  String get connectionErrorConfigInvalid;

  /// No description provided for @connectionErrorStartFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось запустить VPN. Попробуйте ещё раз или выберите другой сервер.'**
  String get connectionErrorStartFailed;

  /// No description provided for @connectionErrorNoServers.
  ///
  /// In ru, this message translates to:
  /// **'Для этого режима пока нет серверов.'**
  String get connectionErrorNoServers;

  /// No description provided for @connectionErrorPermissionDenied.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите VPN-подключение, чтобы включить VPN.'**
  String get connectionErrorPermissionDenied;

  /// No description provided for @connectionErrorTunFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать VPN-интерфейс. Перезагрузите устройство и попробуйте ещё раз.'**
  String get connectionErrorTunFailed;

  /// No description provided for @connectionErrorRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Подключение перехватило другое VPN-приложение.'**
  String get connectionErrorRevoked;

  /// No description provided for @connectionErrorServiceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Служба VPN не отвечает. Переустановите приложение.'**
  String get connectionErrorServiceUnavailable;

  /// No description provided for @connectionErrorVersionMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Версии службы VPN и приложения не совпадают. Переустановите приложение.'**
  String get connectionErrorVersionMismatch;

  /// No description provided for @connectionErrorInternal.
  ///
  /// In ru, this message translates to:
  /// **'Внутренняя ошибка VPN. Попробуйте ещё раз.'**
  String get connectionErrorInternal;

  /// No description provided for @modeNoticeCellular.
  ///
  /// In ru, this message translates to:
  /// **'Мобильная сеть: включён режим «{mode}»'**
  String modeNoticeCellular(String mode);

  /// No description provided for @modeNoticeWifi.
  ///
  /// In ru, this message translates to:
  /// **'Сеть сменилась: включён режим «{mode}»'**
  String modeNoticeWifi(String mode);

  /// No description provided for @modeNoticeOverrideCleared.
  ///
  /// In ru, this message translates to:
  /// **'Автопереход снова следит за сетью: включён режим «{mode}»'**
  String modeNoticeOverrideCleared(String mode);

  /// No description provided for @modeNoticeNoWhitelist.
  ///
  /// In ru, this message translates to:
  /// **'Серверов белых списков нет: работает режим «{mode}»'**
  String modeNoticeNoWhitelist(String mode);

  /// No description provided for @autoSwitchTitle.
  ///
  /// In ru, this message translates to:
  /// **'Белые списки в мобильной сети'**
  String get autoSwitchTitle;

  /// No description provided for @autoSwitchSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Включать белые списки, когда Wi-Fi сменяется мобильной сетью'**
  String get autoSwitchSubtitle;

  /// No description provided for @settingsConnection.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get settingsConnection;
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
