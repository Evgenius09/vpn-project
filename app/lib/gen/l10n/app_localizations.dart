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
  /// **'Введите свой ник в Telegram. Бот пришлёт код для входа.'**
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
  /// **'Ник: от 4 до 32 знаков a–z, 0–9 и _'**
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
  /// **'Открыть бота в Telegram'**
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
  /// **'Нет связи с сервером. Попробуйте ещё раз'**
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
  /// **'Много попыток. Повторите через {seconds} с'**
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
  /// **'Неверный код. Осталось попыток: {attempts}'**
  String loginErrorCodeInvalid(int attempts);

  /// No description provided for @loginErrorCodeInvalidNoCount.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код.'**
  String get loginErrorCodeInvalidNoCount;

  /// No description provided for @loginErrorCodeExpired.
  ///
  /// In ru, this message translates to:
  /// **'Код истёк. Получите новый код'**
  String get loginErrorCodeExpired;

  /// No description provided for @loginErrorDeviceLimit.
  ///
  /// In ru, this message translates to:
  /// **'Устройств уже 5. Отключите лишнее в боте'**
  String get loginErrorDeviceLimit;

  /// No description provided for @loginErrorPanelUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Попробуйте ещё раз'**
  String get loginErrorPanelUnavailable;

  /// No description provided for @loginErrorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не нашёл запрос. Начните вход заново.'**
  String get loginErrorNotFound;

  /// No description provided for @loginErrorInternal.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Попробуйте ещё раз'**
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
  /// **'Не подключено'**
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
  /// **'Автопереход на белые списки'**
  String get autoSwitchTitle;

  /// No description provided for @autoSwitchSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда Wi-Fi сменяется мобильной сетью'**
  String get autoSwitchSubtitle;

  /// No description provided for @settingsConnection.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get settingsConnection;

  /// No description provided for @brandWordmark.
  ///
  /// In ru, this message translates to:
  /// **'СВОИ.'**
  String get brandWordmark;

  /// No description provided for @brandTagline.
  ///
  /// In ru, this message translates to:
  /// **'Свой VPN без лишних настроек'**
  String get brandTagline;

  /// No description provided for @telegramTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бота в Telegram'**
  String get telegramTooltip;

  /// No description provided for @connectionTapToConnect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы подключиться'**
  String get connectionTapToConnect;

  /// No description provided for @connectionTapToSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы переключиться сюда'**
  String get connectionTapToSwitch;

  /// No description provided for @pingSortByPingShort.
  ///
  /// In ru, this message translates to:
  /// **'По пингу'**
  String get pingSortByPingShort;

  /// No description provided for @pingSortByOrder.
  ///
  /// In ru, this message translates to:
  /// **'По порядку'**
  String get pingSortByOrder;

  /// No description provided for @modeSwitchHint.
  ///
  /// In ru, this message translates to:
  /// **'Переключить экран режима'**
  String get modeSwitchHint;

  /// No description provided for @settingsBasics.
  ///
  /// In ru, this message translates to:
  /// **'Основное'**
  String get settingsBasics;

  /// No description provided for @accountTrial.
  ///
  /// In ru, this message translates to:
  /// **'Пробный период'**
  String get accountTrial;

  /// No description provided for @accountActive.
  ///
  /// In ru, this message translates to:
  /// **'Подписка активна'**
  String get accountActive;

  /// No description provided for @accountExpired.
  ///
  /// In ru, this message translates to:
  /// **'Подписка закончилась'**
  String get accountExpired;

  /// No description provided for @accountBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт заблокирован'**
  String get accountBlocked;

  /// No description provided for @accountProvisioning.
  ///
  /// In ru, this message translates to:
  /// **'Готовим доступ…'**
  String get accountProvisioning;

  /// No description provided for @accountUntil.
  ///
  /// In ru, this message translates to:
  /// **'до {date}'**
  String accountUntil(String date);

  /// No description provided for @accountTraffic.
  ///
  /// In ru, this message translates to:
  /// **'Трафик'**
  String get accountTraffic;

  /// No description provided for @accountTrafficUnlimited.
  ///
  /// In ru, this message translates to:
  /// **'Без ограничений'**
  String get accountTrafficUnlimited;

  /// No description provided for @accountTrafficUsed.
  ///
  /// In ru, this message translates to:
  /// **'{used} из {limit}'**
  String accountTrafficUsed(String used, String limit);

  /// No description provided for @accountRenew.
  ///
  /// In ru, this message translates to:
  /// **'Продлить в боте'**
  String get accountRenew;

  /// No description provided for @loginCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из Telegram'**
  String get loginCodeLabel;

  /// No description provided for @loginUsernameHint.
  ///
  /// In ru, this message translates to:
  /// **'Ник есть в Telegram → Настройки → Имя пользователя'**
  String get loginUsernameHint;

  /// No description provided for @loginBotFooter.
  ///
  /// In ru, this message translates to:
  /// **'Ещё не запускали бота? Откройте его и нажмите Start'**
  String get loginBotFooter;

  /// No description provided for @loginCodeFooter.
  ///
  /// In ru, this message translates to:
  /// **'Код не пришёл? Проверьте чат с ботом'**
  String get loginCodeFooter;

  /// No description provided for @protocolVlessReality.
  ///
  /// In ru, this message translates to:
  /// **'VLESS Reality'**
  String get protocolVlessReality;

  /// No description provided for @protocolHysteria2.
  ///
  /// In ru, this message translates to:
  /// **'Hysteria2'**
  String get protocolHysteria2;

  /// No description provided for @setSectionBasics.
  ///
  /// In ru, this message translates to:
  /// **'Основное'**
  String get setSectionBasics;

  /// No description provided for @setAutoSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Автопереход на белые списки'**
  String get setAutoSwitch;

  /// No description provided for @setAutoSwitchHint.
  ///
  /// In ru, this message translates to:
  /// **'Когда Wi-Fi сменяется мобильной сетью'**
  String get setAutoSwitchHint;

  /// No description provided for @setConnectOnOpen.
  ///
  /// In ru, this message translates to:
  /// **'Подключаться при открытии'**
  String get setConnectOnOpen;

  /// No description provided for @setConnectOnOpenHint.
  ///
  /// In ru, this message translates to:
  /// **'Сразу после запуска приложения'**
  String get setConnectOnOpenHint;

  /// No description provided for @setSectionThroughVpn.
  ///
  /// In ru, this message translates to:
  /// **'Что идёт через VPN'**
  String get setSectionThroughVpn;

  /// No description provided for @setTunneling.
  ///
  /// In ru, this message translates to:
  /// **'Раздельное туннелирование (приложения)'**
  String get setTunneling;

  /// No description provided for @setRulesProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль правил (сайты)'**
  String get setRulesProfile;

  /// No description provided for @setSectionLook.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get setSectionLook;

  /// No description provided for @setTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get setTheme;

  /// No description provided for @setLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get setLanguage;

  /// No description provided for @setSectionMore.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get setSectionMore;

  /// No description provided for @setSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get setSupport;

  /// No description provided for @setSupportHint.
  ///
  /// In ru, this message translates to:
  /// **'Написать в Telegram'**
  String get setSupportHint;

  /// No description provided for @setAdvanced.
  ///
  /// In ru, this message translates to:
  /// **'Для опытных'**
  String get setAdvanced;

  /// No description provided for @setAdvancedHint.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация, DNS, сеть, пинг'**
  String get setAdvancedHint;

  /// No description provided for @setTrafficRegular.
  ///
  /// In ru, this message translates to:
  /// **'Трафик обычного VPN'**
  String get setTrafficRegular;

  /// No description provided for @setTrafficWhitelist.
  ///
  /// In ru, this message translates to:
  /// **'Трафик белых списков'**
  String get setTrafficWhitelist;

  /// No description provided for @setUnlimited.
  ///
  /// In ru, this message translates to:
  /// **'∞  Без ограничений'**
  String get setUnlimited;

  /// No description provided for @tunTitle.
  ///
  /// In ru, this message translates to:
  /// **'Туннелирование'**
  String get tunTitle;

  /// No description provided for @tunIntro.
  ///
  /// In ru, this message translates to:
  /// **'Раздельное туннелирование: выберите приложения, которые пойдут мимо VPN. Например, банки и Госуслуги.'**
  String get tunIntro;

  /// No description provided for @tunSectionMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим'**
  String get tunSectionMode;

  /// No description provided for @tunOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключено'**
  String get tunOff;

  /// No description provided for @tunOffHint.
  ///
  /// In ru, this message translates to:
  /// **'Все приложения идут через VPN'**
  String get tunOffHint;

  /// No description provided for @tunExcept.
  ///
  /// In ru, this message translates to:
  /// **'Все, кроме выбранных'**
  String get tunExcept;

  /// No description provided for @tunExceptHint.
  ///
  /// In ru, this message translates to:
  /// **'Отмеченные приложения работают без VPN'**
  String get tunExceptHint;

  /// No description provided for @tunOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только выбранные'**
  String get tunOnly;

  /// No description provided for @tunOnlyHint.
  ///
  /// In ru, this message translates to:
  /// **'Через VPN идут только отмеченные'**
  String get tunOnlyHint;

  /// No description provided for @tunAppsBypass.
  ///
  /// In ru, this message translates to:
  /// **'Приложения без VPN'**
  String get tunAppsBypass;

  /// No description provided for @tunAppsThrough.
  ///
  /// In ru, this message translates to:
  /// **'Приложения через VPN'**
  String get tunAppsThrough;

  /// No description provided for @tunSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск приложений'**
  String get tunSearch;

  /// No description provided for @tunNoApps.
  ///
  /// In ru, this message translates to:
  /// **'Приложения не найдены'**
  String get tunNoApps;

  /// No description provided for @rulesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль правил'**
  String get rulesTitle;

  /// No description provided for @rulesSection.
  ///
  /// In ru, this message translates to:
  /// **'Как идут сайты'**
  String get rulesSection;

  /// No description provided for @rulesRuDirect.
  ///
  /// In ru, this message translates to:
  /// **'Россия напрямую'**
  String get rulesRuDirect;

  /// No description provided for @rulesRuDirectHint.
  ///
  /// In ru, this message translates to:
  /// **'Российские сайты без VPN, остальные через VPN'**
  String get rulesRuDirectHint;

  /// No description provided for @rulesRuDirectShort.
  ///
  /// In ru, this message translates to:
  /// **'Россия напрямую, остальное через VPN'**
  String get rulesRuDirectShort;

  /// No description provided for @rulesAll.
  ///
  /// In ru, this message translates to:
  /// **'Всё через VPN'**
  String get rulesAll;

  /// No description provided for @rulesAllHint.
  ///
  /// In ru, this message translates to:
  /// **'Весь трафик идёт через сервер'**
  String get rulesAllHint;

  /// No description provided for @rulesCustom.
  ///
  /// In ru, this message translates to:
  /// **'Только свои правила'**
  String get rulesCustom;

  /// No description provided for @rulesCustomHint.
  ///
  /// In ru, this message translates to:
  /// **'Работают только ваши правила'**
  String get rulesCustomHint;

  /// No description provided for @themeSection.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get themeSection;

  /// No description provided for @themeDarkName.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDarkName;

  /// No description provided for @themeDarkHint.
  ///
  /// In ru, this message translates to:
  /// **'Бережёт глаза и батарею'**
  String get themeDarkHint;

  /// No description provided for @themeLightName.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLightName;

  /// No description provided for @themeLightHint.
  ///
  /// In ru, this message translates to:
  /// **'Светлый фон, тёмный текст'**
  String get themeLightHint;

  /// No description provided for @themeSystemName.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeSystemName;

  /// No description provided for @themeSystemHint.
  ///
  /// In ru, this message translates to:
  /// **'Меняется вместе с телефоном'**
  String get themeSystemHint;

  /// No description provided for @langSection.
  ///
  /// In ru, this message translates to:
  /// **'Язык приложения'**
  String get langSection;

  /// No description provided for @langRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRu;

  /// No description provided for @langRuHint.
  ///
  /// In ru, this message translates to:
  /// **'Русский язык'**
  String get langRuHint;

  /// No description provided for @langEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langEnHint.
  ///
  /// In ru, this message translates to:
  /// **'Английский'**
  String get langEnHint;

  /// No description provided for @langSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get langSystem;

  /// No description provided for @langSystemHint.
  ///
  /// In ru, this message translates to:
  /// **'Язык телефона'**
  String get langSystemHint;

  /// No description provided for @supSectionContact.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с нами'**
  String get supSectionContact;

  /// No description provided for @supWrite.
  ///
  /// In ru, this message translates to:
  /// **'Написать в поддержку'**
  String get supWrite;

  /// No description provided for @supWriteHint.
  ///
  /// In ru, this message translates to:
  /// **'@svoi_support в Telegram'**
  String get supWriteHint;

  /// No description provided for @supBot.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бота'**
  String get supBot;

  /// No description provided for @supBotHint.
  ///
  /// In ru, this message translates to:
  /// **'Подписка, продление, устройства'**
  String get supBotHint;

  /// No description provided for @supSectionAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get supSectionAbout;

  /// No description provided for @supSite.
  ///
  /// In ru, this message translates to:
  /// **'Сайт'**
  String get supSite;

  /// No description provided for @supSiteHint.
  ///
  /// In ru, this message translates to:
  /// **'svoi.app'**
  String get supSiteHint;

  /// No description provided for @supVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия'**
  String get supVersion;

  /// No description provided for @supVersionValue.
  ///
  /// In ru, this message translates to:
  /// **'{version} · Android'**
  String supVersionValue(String version);

  /// No description provided for @supFooter.
  ///
  /// In ru, this message translates to:
  /// **'Ответим в Telegram в течение дня.\nМы не храним историю ваших подключений.'**
  String get supFooter;

  /// No description provided for @advSectionRouting.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация'**
  String get advSectionRouting;

  /// No description provided for @advRouting.
  ///
  /// In ru, this message translates to:
  /// **'Маршрутизация'**
  String get advRouting;

  /// No description provided for @advRoutingHint.
  ///
  /// In ru, this message translates to:
  /// **'Российские сайты открываются напрямую'**
  String get advRoutingHint;

  /// No description provided for @advCustomRules.
  ///
  /// In ru, this message translates to:
  /// **'Свои правила'**
  String get advCustomRules;

  /// No description provided for @advCustomRulesHint.
  ///
  /// In ru, this message translates to:
  /// **'{count} правила · домены и IP-адреса'**
  String advCustomRulesHint(int count);

  /// No description provided for @advSectionDns.
  ///
  /// In ru, this message translates to:
  /// **'DNS'**
  String get advSectionDns;

  /// No description provided for @advDnsRemote.
  ///
  /// In ru, this message translates to:
  /// **'DNS через VPN'**
  String get advDnsRemote;

  /// No description provided for @advDnsDirect.
  ///
  /// In ru, this message translates to:
  /// **'Прямой DNS'**
  String get advDnsDirect;

  /// No description provided for @advAddressOrder.
  ///
  /// In ru, this message translates to:
  /// **'Порядок адресов'**
  String get advAddressOrder;

  /// No description provided for @advSectionNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get advSectionNetwork;

  /// No description provided for @advIpv6.
  ///
  /// In ru, this message translates to:
  /// **'IPv6'**
  String get advIpv6;

  /// No description provided for @advIpv6Hint.
  ///
  /// In ru, this message translates to:
  /// **'Обычно не нужен, без него стабильнее'**
  String get advIpv6Hint;

  /// No description provided for @advSniffing.
  ///
  /// In ru, this message translates to:
  /// **'Определение сайтов (sniffing)'**
  String get advSniffing;

  /// No description provided for @advSniffingHint.
  ///
  /// In ru, this message translates to:
  /// **'Помогает правилам маршрутизации'**
  String get advSniffingHint;

  /// No description provided for @advTlsFragment.
  ///
  /// In ru, this message translates to:
  /// **'Фрагментация TLS'**
  String get advTlsFragment;

  /// No description provided for @advTlsFragmentHint.
  ///
  /// In ru, this message translates to:
  /// **'Включите, если сайты не открываются'**
  String get advTlsFragmentHint;

  /// No description provided for @advBypassLan.
  ///
  /// In ru, this message translates to:
  /// **'Обход локальной сети'**
  String get advBypassLan;

  /// No description provided for @advBypassLanHint.
  ///
  /// In ru, this message translates to:
  /// **'Роутер и принтеры доступны напрямую'**
  String get advBypassLanHint;

  /// No description provided for @advMtu.
  ///
  /// In ru, this message translates to:
  /// **'MTU'**
  String get advMtu;

  /// No description provided for @advTunMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим TUN'**
  String get advTunMode;

  /// No description provided for @advExcluded.
  ///
  /// In ru, this message translates to:
  /// **'Исключённые адреса'**
  String get advExcluded;

  /// No description provided for @advExcludedNone.
  ///
  /// In ru, this message translates to:
  /// **'Не заданы'**
  String get advExcludedNone;

  /// No description provided for @advSectionPing.
  ///
  /// In ru, this message translates to:
  /// **'Пинг'**
  String get advSectionPing;

  /// No description provided for @advPingMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ проверки'**
  String get advPingMethod;

  /// No description provided for @advPingUrl.
  ///
  /// In ru, this message translates to:
  /// **'Адрес проверки'**
  String get advPingUrl;

  /// No description provided for @advPingTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Таймаут'**
  String get advPingTimeout;

  /// No description provided for @advPingOnOpen.
  ///
  /// In ru, this message translates to:
  /// **'Проверять при открытии'**
  String get advPingOnOpen;

  /// No description provided for @advPingOnOpenHint.
  ///
  /// In ru, this message translates to:
  /// **'Пинг серверов при запуске приложения'**
  String get advPingOnOpenHint;

  /// No description provided for @advSectionConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get advSectionConnect;

  /// No description provided for @advAutoConnect.
  ///
  /// In ru, this message translates to:
  /// **'Сервер для автоподключения'**
  String get advAutoConnect;

  /// No description provided for @addrSection.
  ///
  /// In ru, this message translates to:
  /// **'Версия IP'**
  String get addrSection;

  /// No description provided for @addrV4First.
  ///
  /// In ru, this message translates to:
  /// **'Сначала IPv4'**
  String get addrV4First;

  /// No description provided for @addrV4FirstHint.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуем: работает в любой сети'**
  String get addrV4FirstHint;

  /// No description provided for @addrV6First.
  ///
  /// In ru, this message translates to:
  /// **'Сначала IPv6'**
  String get addrV6First;

  /// No description provided for @addrV6FirstHint.
  ///
  /// In ru, this message translates to:
  /// **'Если ваша сеть поддерживает IPv6'**
  String get addrV6FirstHint;

  /// No description provided for @addrV4Only.
  ///
  /// In ru, this message translates to:
  /// **'Только IPv4'**
  String get addrV4Only;

  /// No description provided for @addrV4OnlyHint.
  ///
  /// In ru, this message translates to:
  /// **'IPv6 не используется'**
  String get addrV4OnlyHint;

  /// No description provided for @addrV6Only.
  ///
  /// In ru, this message translates to:
  /// **'Только IPv6'**
  String get addrV6Only;

  /// No description provided for @addrV6OnlyHint.
  ///
  /// In ru, this message translates to:
  /// **'Для сетей, где есть только IPv6'**
  String get addrV6OnlyHint;

  /// No description provided for @tunModeSection.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get tunModeSection;

  /// No description provided for @tunGvisorHint.
  ///
  /// In ru, this message translates to:
  /// **'Надёжный, подходит большинству'**
  String get tunGvisorHint;

  /// No description provided for @tunSystemHint.
  ///
  /// In ru, this message translates to:
  /// **'Быстрее, но работает не на всех телефонах'**
  String get tunSystemHint;

  /// No description provided for @tunMixedHint.
  ///
  /// In ru, this message translates to:
  /// **'Смешанный режим'**
  String get tunMixedHint;

  /// No description provided for @pingMethodSection.
  ///
  /// In ru, this message translates to:
  /// **'Как проверять пинг'**
  String get pingMethodSection;

  /// No description provided for @pingTcpHint.
  ///
  /// In ru, this message translates to:
  /// **'Быстро: проверяет, отвечает ли сервер'**
  String get pingTcpHint;

  /// No description provided for @pingUrlTest.
  ///
  /// In ru, this message translates to:
  /// **'URL-тест'**
  String get pingUrlTest;

  /// No description provided for @pingUrlTestHint.
  ///
  /// In ru, this message translates to:
  /// **'Точнее: загружает страницу через сервер'**
  String get pingUrlTestHint;

  /// No description provided for @timeoutSection.
  ///
  /// In ru, this message translates to:
  /// **'Сколько ждать ответа'**
  String get timeoutSection;

  /// No description provided for @timeout1.
  ///
  /// In ru, this message translates to:
  /// **'1 секунда'**
  String get timeout1;

  /// No description provided for @timeout1Hint.
  ///
  /// In ru, this message translates to:
  /// **'Быстро, но медленные серверы пропадут'**
  String get timeout1Hint;

  /// No description provided for @timeout3.
  ///
  /// In ru, this message translates to:
  /// **'3 секунды'**
  String get timeout3;

  /// No description provided for @timeout3Hint.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуем'**
  String get timeout3Hint;

  /// No description provided for @timeout5.
  ///
  /// In ru, this message translates to:
  /// **'5 секунд'**
  String get timeout5;

  /// No description provided for @timeout5Hint.
  ///
  /// In ru, this message translates to:
  /// **'Для медленного интернета'**
  String get timeout5Hint;

  /// No description provided for @autoSection.
  ///
  /// In ru, this message translates to:
  /// **'Какой сервер выбирать'**
  String get autoSection;

  /// No description provided for @autoLast.
  ///
  /// In ru, this message translates to:
  /// **'Последний использованный'**
  String get autoLast;

  /// No description provided for @autoLastHint.
  ///
  /// In ru, this message translates to:
  /// **'Тот, к которому вы подключались в прошлый раз'**
  String get autoLastHint;

  /// No description provided for @autoBest.
  ///
  /// In ru, this message translates to:
  /// **'С лучшим пингом'**
  String get autoBest;

  /// No description provided for @autoBestHint.
  ///
  /// In ru, this message translates to:
  /// **'Самый быстрый на момент запуска'**
  String get autoBestHint;

  /// No description provided for @autoRandom.
  ///
  /// In ru, this message translates to:
  /// **'Случайный'**
  String get autoRandom;

  /// No description provided for @autoRandomHint.
  ///
  /// In ru, this message translates to:
  /// **'Любой доступный сервер'**
  String get autoRandomHint;

  /// No description provided for @inputQuick.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый выбор'**
  String get inputQuick;

  /// No description provided for @dnsAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес DNS-сервера'**
  String get dnsAddress;

  /// No description provided for @dnsRemoteNote.
  ///
  /// In ru, this message translates to:
  /// **'Адрес DoH-сервера. Запросы идут через VPN и не видны оператору связи.'**
  String get dnsRemoteNote;

  /// No description provided for @dnsDirectNote.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес или DoH. Используется для сайтов, которые открываются без VPN.'**
  String get dnsDirectNote;

  /// No description provided for @dnsYandex.
  ///
  /// In ru, this message translates to:
  /// **'Яндекс'**
  String get dnsYandex;

  /// No description provided for @mtuSection.
  ///
  /// In ru, this message translates to:
  /// **'Размер пакета'**
  String get mtuSection;

  /// No description provided for @mtuNote.
  ///
  /// In ru, this message translates to:
  /// **'От 1280 до 9000. Если сайты грузятся не полностью, попробуйте 1400.'**
  String get mtuNote;

  /// No description provided for @mtu1500Hint.
  ///
  /// In ru, this message translates to:
  /// **'Стандарт, рекомендуем'**
  String get mtu1500Hint;

  /// No description provided for @mtu1400Hint.
  ///
  /// In ru, this message translates to:
  /// **'Если сайты грузятся не полностью'**
  String get mtu1400Hint;

  /// No description provided for @mtu1280Hint.
  ///
  /// In ru, this message translates to:
  /// **'Минимальное значение'**
  String get mtu1280Hint;

  /// No description provided for @pingUrlSection.
  ///
  /// In ru, this message translates to:
  /// **'Адрес страницы'**
  String get pingUrlSection;

  /// No description provided for @pingUrlNote.
  ///
  /// In ru, this message translates to:
  /// **'Страница, которую загружает URL-тест, чтобы измерить пинг через сервер.'**
  String get pingUrlNote;

  /// No description provided for @crSection.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get crSection;

  /// No description provided for @crFooter.
  ///
  /// In ru, this message translates to:
  /// **'Правила проверяются сверху вниз, срабатывает первое подходящее. Зажмите правило, чтобы поменять порядок.'**
  String get crFooter;

  /// No description provided for @crAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get crAdd;

  /// No description provided for @crRuleLine.
  ///
  /// In ru, this message translates to:
  /// **'{match} → {action}'**
  String crRuleLine(String match, String action);

  /// No description provided for @exTitle.
  ///
  /// In ru, this message translates to:
  /// **'Исключения'**
  String get exTitle;

  /// No description provided for @exSection.
  ///
  /// In ru, this message translates to:
  /// **'Адреса мимо VPN'**
  String get exSection;

  /// No description provided for @exFooter.
  ///
  /// In ru, this message translates to:
  /// **'Эти адреса и подсети всегда идут мимо VPN. Например, домашний роутер или рабочая сеть.'**
  String get exFooter;

  /// No description provided for @exHome.
  ///
  /// In ru, this message translates to:
  /// **'Домашняя сеть'**
  String get exHome;

  /// No description provided for @exWork.
  ///
  /// In ru, this message translates to:
  /// **'Рабочая сеть'**
  String get exWork;

  /// No description provided for @exRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get exRemove;

  /// No description provided for @nrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новое правило'**
  String get nrTitle;

  /// No description provided for @nrAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес сайта или IP'**
  String get nrAddress;

  /// No description provided for @nrMatchSection.
  ///
  /// In ru, this message translates to:
  /// **'Что проверять'**
  String get nrMatchSection;

  /// No description provided for @nrSuffix.
  ///
  /// In ru, this message translates to:
  /// **'Домен и поддомены'**
  String get nrSuffix;

  /// No description provided for @nrSuffixHint.
  ///
  /// In ru, this message translates to:
  /// **'{host}, m.{host} и другие'**
  String nrSuffixHint(String host);

  /// No description provided for @nrExact.
  ///
  /// In ru, this message translates to:
  /// **'Точный домен'**
  String get nrExact;

  /// No description provided for @nrExactHint.
  ///
  /// In ru, this message translates to:
  /// **'Только {host}'**
  String nrExactHint(String host);

  /// No description provided for @nrKeyword.
  ///
  /// In ru, this message translates to:
  /// **'Содержит слово'**
  String get nrKeyword;

  /// No description provided for @nrKeywordHint.
  ///
  /// In ru, this message translates to:
  /// **'Любой адрес со словом {word}'**
  String nrKeywordHint(String word);

  /// No description provided for @nrIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес или подсеть'**
  String get nrIp;

  /// No description provided for @nrIpHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, 8.8.8.8 или 10.0.0.0/8'**
  String get nrIpHint;

  /// No description provided for @nrActionSection.
  ///
  /// In ru, this message translates to:
  /// **'Что делать'**
  String get nrActionSection;

  /// No description provided for @nrProxy.
  ///
  /// In ru, this message translates to:
  /// **'Через VPN'**
  String get nrProxy;

  /// No description provided for @nrProxyHint.
  ///
  /// In ru, this message translates to:
  /// **'Открывать через сервер'**
  String get nrProxyHint;

  /// No description provided for @nrDirect.
  ///
  /// In ru, this message translates to:
  /// **'Напрямую'**
  String get nrDirect;

  /// No description provided for @nrDirectHint.
  ///
  /// In ru, this message translates to:
  /// **'Открывать без VPN'**
  String get nrDirectHint;

  /// No description provided for @nrBlock.
  ///
  /// In ru, this message translates to:
  /// **'Блокировать'**
  String get nrBlock;

  /// No description provided for @nrBlockHint.
  ///
  /// In ru, this message translates to:
  /// **'Не открывать совсем, например рекламу'**
  String get nrBlockHint;

  /// No description provided for @nrActionProxyShort.
  ///
  /// In ru, this message translates to:
  /// **'через VPN'**
  String get nrActionProxyShort;

  /// No description provided for @nrActionDirectShort.
  ///
  /// In ru, this message translates to:
  /// **'напрямую'**
  String get nrActionDirectShort;

  /// No description provided for @nrActionBlockShort.
  ///
  /// In ru, this message translates to:
  /// **'блокировать'**
  String get nrActionBlockShort;

  /// No description provided for @connectionNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключено'**
  String get connectionNotConnected;

  /// No description provided for @connectionConnectedShort.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get connectionConnectedShort;

  /// No description provided for @connectionUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно'**
  String get connectionUnavailable;

  /// No description provided for @pingSortByAlphabet.
  ///
  /// In ru, this message translates to:
  /// **'По алфавиту'**
  String get pingSortByAlphabet;

  /// No description provided for @freeServer.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатный сервер'**
  String get freeServer;

  /// No description provided for @freeServerHint.
  ///
  /// In ru, this message translates to:
  /// **'Только для Telegram'**
  String get freeServerHint;

  /// No description provided for @freeGetFull.
  ///
  /// In ru, this message translates to:
  /// **'Получить полный доступ в Telegram-боте'**
  String get freeGetFull;

  /// No description provided for @freeHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get freeHaveAccount;

  /// No description provided for @freeWhitelistHint.
  ///
  /// In ru, this message translates to:
  /// **'В бесплатном режиме нет обхода белых списков'**
  String get freeWhitelistHint;

  /// No description provided for @freeWhitelistTitle.
  ///
  /// In ru, this message translates to:
  /// **'Белые списки недоступны'**
  String get freeWhitelistTitle;

  /// No description provided for @freeWhitelistText.
  ///
  /// In ru, this message translates to:
  /// **'Режим нужен, когда мобильный интернет ограничен белыми списками. Он откроется после входа через Telegram-бота.'**
  String get freeWhitelistText;

  /// No description provided for @loginOpenBotTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Открыть бота в Telegram'**
  String get loginOpenBotTelegram;

  /// No description provided for @loginSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginSignIn;

  /// No description provided for @loginNewCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить новый код'**
  String get loginNewCode;

  /// No description provided for @loginResendInTimer.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код повторно через {time}'**
  String loginResendInTimer(String time);

  /// No description provided for @loginBotNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Ник не найден среди пользователей бота'**
  String get loginBotNotFound;

  /// No description provided for @loginNoNickFooter.
  ///
  /// In ru, this message translates to:
  /// **'Нет ника в Telegram? Бот подскажет, как его задать'**
  String get loginNoNickFooter;

  /// No description provided for @loginCodeIntro.
  ///
  /// In ru, this message translates to:
  /// **'Бот отправил 6 цифр в Telegram для @{username}. Код действует 5 минут.'**
  String loginCodeIntro(String username);

  /// No description provided for @loginBotIntro.
  ///
  /// In ru, this message translates to:
  /// **'Не нашли @{username} среди пользователей бота. Откройте бота, нажмите Start и вернитесь сюда.'**
  String loginBotIntro(String username);

  /// No description provided for @loginBotHeading.
  ///
  /// In ru, this message translates to:
  /// **'Откройте бота'**
  String get loginBotHeading;

  /// No description provided for @unitGb.
  ///
  /// In ru, this message translates to:
  /// **'ГБ'**
  String get unitGb;

  /// No description provided for @advAutoConnectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Автоподключение'**
  String get advAutoConnectTitle;
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
