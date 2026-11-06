// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'VPN Client';

  @override
  String get modeRegular => 'Обычный VPN';

  @override
  String get modeWhitelist => 'Белые списки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsTooltip => 'Открыть настройки';

  @override
  String get lockedByProvider => 'Задано провайдером';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get pingUnknown => '—';

  @override
  String get pingUnreachable => 'Нет связи';

  @override
  String get emptyScreenTitle => 'Скоро здесь будет экран';

  @override
  String get powerButtonLabel => 'Подключение';

  @override
  String get kitchenSinkTitle => 'Витрина компонентов';

  @override
  String get themeLight => 'Светлая тема';

  @override
  String get themeDark => 'Тёмная тема';

  @override
  String pingMs(int value) {
    return '$value мс';
  }

  @override
  String speedBytes(String value) {
    return '$value Б/с';
  }

  @override
  String speedKilobytes(String value) {
    return '$value КБ/с';
  }

  @override
  String speedMegabytes(String value) {
    return '$value МБ/с';
  }

  @override
  String get serversTitle => 'Серверы';

  @override
  String get serversEmpty => 'Серверов пока нет';

  @override
  String get pingRefresh => 'Проверить пинг';

  @override
  String get pingSortByPing => 'Сортировать по пингу';

  @override
  String get profileLoadFailed => 'Не удалось загрузить профиль';

  @override
  String get profileFromCache =>
      'Нет связи с сервером, показаны сохранённые данные';

  @override
  String get loginUsernameTitle => 'Вход через Telegram';

  @override
  String get loginUsernameMessage =>
      'Введите свой ник в Telegram. Бот пришлёт код для входа.';

  @override
  String get loginUsernameLabel => 'Ник в Telegram';

  @override
  String get loginGetCode => 'Получить код';

  @override
  String get loginInvalidUsername => 'Ник: от 4 до 32 знаков a–z, 0–9 и _';

  @override
  String get loginBotTitle => 'Откройте бота и нажмите Start';

  @override
  String get loginBotMessage =>
      'Бот может написать только тем, кто его запустил. Нажмите Start в боте и вернитесь сюда.';

  @override
  String get loginOpenBot => 'Открыть бота в Telegram';

  @override
  String get loginPressedStart => 'Я нажал Start, отправить код';

  @override
  String get loginChangeUsername => 'Изменить ник';

  @override
  String get loginCodeTitle => 'Введите код';

  @override
  String loginCodeMessage(String username) {
    return 'Бот отправил 6-значный код пользователю @$username.';
  }

  @override
  String loginResendIn(int seconds) {
    return 'Отправить снова через $seconds с';
  }

  @override
  String get loginResend => 'Отправить код снова';

  @override
  String get loginLinkFailed => 'Не удалось открыть ссылку';

  @override
  String get loginErrorUnavailable =>
      'Нет связи с сервером. Попробуйте ещё раз';

  @override
  String get loginErrorUnexpected => 'Неожиданный ответ сервера. Повторите.';

  @override
  String get loginErrorUnauthorized => 'Сессия завершилась. Войдите снова.';

  @override
  String get loginErrorDeviceRevoked =>
      'Это устройство отключено от аккаунта. Войдите снова.';

  @override
  String get loginErrorValidationFailed =>
      'Сервер не принял данные. Проверьте ник и код.';

  @override
  String loginErrorRateLimited(int seconds) {
    return 'Много попыток. Повторите через $seconds с';
  }

  @override
  String get loginErrorRateLimitedLater =>
      'Слишком много попыток. Повторите позже.';

  @override
  String get loginErrorUserNotFound =>
      'Ник не найден среди пользователей бота. Откройте бота и нажмите Start.';

  @override
  String loginErrorCodeInvalid(int attempts) {
    return 'Неверный код. Осталось попыток: $attempts';
  }

  @override
  String get loginErrorCodeInvalidNoCount => 'Неверный код.';

  @override
  String get loginErrorCodeExpired => 'Код истёк. Получите новый код';

  @override
  String get loginErrorDeviceLimit =>
      'Устройств уже 5. Отключите лишнее в боте';

  @override
  String get loginErrorPanelUnavailable =>
      'Нет связи с сервером. Попробуйте ещё раз';

  @override
  String get loginErrorNotFound =>
      'Сервер не нашёл запрос. Начните вход заново.';

  @override
  String get loginErrorInternal => 'Нет связи с сервером. Попробуйте ещё раз';

  @override
  String get settingsAccount => 'Аккаунт';

  @override
  String get logoutButton => 'Выйти из аккаунта';

  @override
  String get logoutConfirmTitle => 'Выйти из аккаунта?';

  @override
  String get logoutConfirmMessage =>
      'VPN отключится, а устройство выйдет из аккаунта. Чтобы вернуться, войдите с новым кодом из бота.';

  @override
  String get logoutConfirm => 'Выйти';

  @override
  String get connectionDisconnected => 'Не подключено';

  @override
  String get connectionConnecting => 'Подключение…';

  @override
  String connectionConnected(String time) {
    return 'Подключено $time';
  }

  @override
  String get connectionDisconnecting => 'Отключение…';

  @override
  String get connectionFailed => 'Ошибка подключения';

  @override
  String connectionActiveElsewhere(String mode) {
    return 'Сейчас активен: $mode';
  }

  @override
  String get connectionErrorConfigInvalid =>
      'Настройки подключения неверны. Обновите приложение или напишите в поддержку.';

  @override
  String get connectionErrorStartFailed =>
      'Не удалось запустить VPN. Попробуйте ещё раз или выберите другой сервер.';

  @override
  String get connectionErrorNoServers => 'Для этого режима пока нет серверов.';

  @override
  String get connectionErrorPermissionDenied =>
      'Разрешите VPN-подключение, чтобы включить VPN.';

  @override
  String get connectionErrorTunFailed =>
      'Не удалось создать VPN-интерфейс. Перезагрузите устройство и попробуйте ещё раз.';

  @override
  String get connectionErrorRevoked =>
      'Подключение перехватило другое VPN-приложение.';

  @override
  String get connectionErrorServiceUnavailable =>
      'Служба VPN не отвечает. Переустановите приложение.';

  @override
  String get connectionErrorVersionMismatch =>
      'Версии службы VPN и приложения не совпадают. Переустановите приложение.';

  @override
  String get connectionErrorInternal =>
      'Внутренняя ошибка VPN. Попробуйте ещё раз.';

  @override
  String modeNoticeCellular(String mode) {
    return 'Мобильная сеть: включён режим «$mode»';
  }

  @override
  String modeNoticeWifi(String mode) {
    return 'Сеть сменилась: включён режим «$mode»';
  }

  @override
  String modeNoticeOverrideCleared(String mode) {
    return 'Автопереход снова следит за сетью: включён режим «$mode»';
  }

  @override
  String modeNoticeNoWhitelist(String mode) {
    return 'Серверов белых списков нет: работает режим «$mode»';
  }

  @override
  String get autoSwitchTitle => 'Автопереход на белые списки';

  @override
  String get autoSwitchSubtitle => 'Когда Wi-Fi сменяется мобильной сетью';

  @override
  String get settingsConnection => 'Подключение';

  @override
  String get brandWordmark => 'СВОИ.';

  @override
  String get brandTagline => 'Свой VPN без лишних настроек';

  @override
  String get telegramTooltip => 'Открыть бота в Telegram';

  @override
  String get connectionTapToConnect => 'Нажмите, чтобы подключиться';

  @override
  String get connectionTapToSwitch => 'Нажмите, чтобы переключиться сюда';

  @override
  String get pingSortByPingShort => 'По пингу';

  @override
  String get pingSortByOrder => 'По порядку';

  @override
  String get modeSwitchHint => 'Переключить экран режима';

  @override
  String get settingsBasics => 'Основное';

  @override
  String get accountTrial => 'Пробный период';

  @override
  String get accountActive => 'Подписка активна';

  @override
  String get accountExpired => 'Подписка закончилась';

  @override
  String get accountBlocked => 'Аккаунт заблокирован';

  @override
  String get accountProvisioning => 'Готовим доступ…';

  @override
  String accountUntil(String date) {
    return 'до $date';
  }

  @override
  String get accountTraffic => 'Трафик';

  @override
  String get accountTrafficUnlimited => 'Без ограничений';

  @override
  String accountTrafficUsed(String used, String limit) {
    return '$used из $limit';
  }

  @override
  String get accountRenew => 'Продлить в боте';

  @override
  String get loginCodeLabel => 'Код из Telegram';

  @override
  String get loginUsernameHint =>
      'Ник есть в Telegram → Настройки → Имя пользователя';

  @override
  String get loginBotFooter =>
      'Ещё не запускали бота? Откройте его и нажмите Start';

  @override
  String get loginCodeFooter => 'Код не пришёл? Проверьте чат с ботом';

  @override
  String get protocolVlessReality => 'VLESS Reality';

  @override
  String get protocolHysteria2 => 'Hysteria2';

  @override
  String get setSectionBasics => 'Основное';

  @override
  String get setAutoSwitch => 'Автопереход на белые списки';

  @override
  String get setAutoSwitchHint => 'Когда Wi-Fi сменяется мобильной сетью';

  @override
  String get setConnectOnOpen => 'Подключаться при открытии';

  @override
  String get setConnectOnOpenHint => 'Сразу после запуска приложения';

  @override
  String get setSectionThroughVpn => 'Что идёт через VPN';

  @override
  String get setTunneling => 'Раздельное туннелирование (приложения)';

  @override
  String get setRulesProfile => 'Профиль правил (сайты)';

  @override
  String get setSectionLook => 'Внешний вид';

  @override
  String get setTheme => 'Тема';

  @override
  String get setLanguage => 'Язык';

  @override
  String get setSectionMore => 'Дополнительно';

  @override
  String get setSupport => 'Поддержка';

  @override
  String get setSupportHint => 'Написать в Telegram';

  @override
  String get setAdvanced => 'Для опытных';

  @override
  String get setAdvancedHint => 'Маршрутизация, DNS, сеть, пинг';

  @override
  String get setTrafficRegular => 'Трафик обычного VPN';

  @override
  String get setTrafficWhitelist => 'Трафик белых списков';

  @override
  String get setUnlimited => '∞  Без ограничений';

  @override
  String get tunTitle => 'Туннелирование';

  @override
  String get tunIntro =>
      'Раздельное туннелирование: выберите приложения, которые пойдут мимо VPN. Например, банки и Госуслуги.';

  @override
  String get tunSectionMode => 'Режим';

  @override
  String get tunOff => 'Выключено';

  @override
  String get tunOffHint => 'Все приложения идут через VPN';

  @override
  String get tunExcept => 'Все, кроме выбранных';

  @override
  String get tunExceptHint => 'Отмеченные приложения работают без VPN';

  @override
  String get tunOnly => 'Только выбранные';

  @override
  String get tunOnlyHint => 'Через VPN идут только отмеченные';

  @override
  String get tunAppsBypass => 'Приложения без VPN';

  @override
  String get tunAppsThrough => 'Приложения через VPN';

  @override
  String get tunSearch => 'Поиск приложений';

  @override
  String get tunNoApps => 'Приложения не найдены';

  @override
  String get rulesTitle => 'Профиль правил';

  @override
  String get rulesSection => 'Как идут сайты';

  @override
  String get rulesRuDirect => 'Россия напрямую';

  @override
  String get rulesRuDirectHint =>
      'Российские сайты без VPN, остальные через VPN';

  @override
  String get rulesRuDirectShort => 'Россия напрямую, остальное через VPN';

  @override
  String get rulesAll => 'Всё через VPN';

  @override
  String get rulesAllHint => 'Весь трафик идёт через сервер';

  @override
  String get rulesCustom => 'Только свои правила';

  @override
  String get rulesCustomHint => 'Работают только ваши правила';

  @override
  String get themeSection => 'Оформление';

  @override
  String get themeDarkName => 'Тёмная';

  @override
  String get themeDarkHint => 'Бережёт глаза и батарею';

  @override
  String get themeLightName => 'Светлая';

  @override
  String get themeLightHint => 'Светлый фон, тёмный текст';

  @override
  String get themeSystemName => 'Как в системе';

  @override
  String get themeSystemHint => 'Меняется вместе с телефоном';

  @override
  String get langSection => 'Язык приложения';

  @override
  String get langRu => 'Русский';

  @override
  String get langRuHint => 'Русский язык';

  @override
  String get langEn => 'English';

  @override
  String get langEnHint => 'Английский';

  @override
  String get langSystem => 'Как в системе';

  @override
  String get langSystemHint => 'Язык телефона';

  @override
  String get supSectionContact => 'Связаться с нами';

  @override
  String get supWrite => 'Написать в поддержку';

  @override
  String get supWriteHint => '@svoi_support в Telegram';

  @override
  String get supBot => 'Открыть бота';

  @override
  String get supBotHint => 'Подписка, продление, устройства';

  @override
  String get supSectionAbout => 'О приложении';

  @override
  String get supSite => 'Сайт';

  @override
  String get supSiteHint => 'svoi.app';

  @override
  String get supVersion => 'Версия';

  @override
  String supVersionValue(String version) {
    return '$version · Android';
  }

  @override
  String get supFooter =>
      'Ответим в Telegram в течение дня.\nМы не храним историю ваших подключений.';

  @override
  String get advSectionRouting => 'Маршрутизация';

  @override
  String get advRouting => 'Маршрутизация';

  @override
  String get advRoutingHint => 'Российские сайты открываются напрямую';

  @override
  String get advCustomRules => 'Свои правила';

  @override
  String advCustomRulesHint(int count) {
    return '$count правила · домены и IP-адреса';
  }

  @override
  String get advSectionDns => 'DNS';

  @override
  String get advDnsRemote => 'DNS через VPN';

  @override
  String get advDnsDirect => 'Прямой DNS';

  @override
  String get advAddressOrder => 'Порядок адресов';

  @override
  String get advSectionNetwork => 'Сеть';

  @override
  String get advIpv6 => 'IPv6';

  @override
  String get advIpv6Hint => 'Обычно не нужен, без него стабильнее';

  @override
  String get advSniffing => 'Определение сайтов (sniffing)';

  @override
  String get advSniffingHint => 'Помогает правилам маршрутизации';

  @override
  String get advTlsFragment => 'Фрагментация TLS';

  @override
  String get advTlsFragmentHint => 'Включите, если сайты не открываются';

  @override
  String get advBypassLan => 'Обход локальной сети';

  @override
  String get advBypassLanHint => 'Роутер и принтеры доступны напрямую';

  @override
  String get advMtu => 'MTU';

  @override
  String get advTunMode => 'Режим TUN';

  @override
  String get advExcluded => 'Исключённые адреса';

  @override
  String get advExcludedNone => 'Не заданы';

  @override
  String get advSectionPing => 'Пинг';

  @override
  String get advPingMethod => 'Способ проверки';

  @override
  String get advPingUrl => 'Адрес проверки';

  @override
  String get advPingTimeout => 'Таймаут';

  @override
  String get advPingOnOpen => 'Проверять при открытии';

  @override
  String get advPingOnOpenHint => 'Пинг серверов при запуске приложения';

  @override
  String get advSectionConnect => 'Подключение';

  @override
  String get advAutoConnect => 'Сервер для автоподключения';

  @override
  String get addrSection => 'Версия IP';

  @override
  String get addrV4First => 'Сначала IPv4';

  @override
  String get addrV4FirstHint => 'Рекомендуем: работает в любой сети';

  @override
  String get addrV6First => 'Сначала IPv6';

  @override
  String get addrV6FirstHint => 'Если ваша сеть поддерживает IPv6';

  @override
  String get addrV4Only => 'Только IPv4';

  @override
  String get addrV4OnlyHint => 'IPv6 не используется';

  @override
  String get addrV6Only => 'Только IPv6';

  @override
  String get addrV6OnlyHint => 'Для сетей, где есть только IPv6';

  @override
  String get tunModeSection => 'Режим работы';

  @override
  String get tunGvisorHint => 'Надёжный, подходит большинству';

  @override
  String get tunSystemHint => 'Быстрее, но работает не на всех телефонах';

  @override
  String get tunMixedHint => 'Смешанный режим';

  @override
  String get pingMethodSection => 'Как проверять пинг';

  @override
  String get pingTcpHint => 'Быстро: проверяет, отвечает ли сервер';

  @override
  String get pingUrlTest => 'URL-тест';

  @override
  String get pingUrlTestHint => 'Точнее: загружает страницу через сервер';

  @override
  String get timeoutSection => 'Сколько ждать ответа';

  @override
  String get timeout1 => '1 секунда';

  @override
  String get timeout1Hint => 'Быстро, но медленные серверы пропадут';

  @override
  String get timeout3 => '3 секунды';

  @override
  String get timeout3Hint => 'Рекомендуем';

  @override
  String get timeout5 => '5 секунд';

  @override
  String get timeout5Hint => 'Для медленного интернета';

  @override
  String get autoSection => 'Какой сервер выбирать';

  @override
  String get autoLast => 'Последний использованный';

  @override
  String get autoLastHint => 'Тот, к которому вы подключались в прошлый раз';

  @override
  String get autoBest => 'С лучшим пингом';

  @override
  String get autoBestHint => 'Самый быстрый на момент запуска';

  @override
  String get autoRandom => 'Случайный';

  @override
  String get autoRandomHint => 'Любой доступный сервер';

  @override
  String get inputQuick => 'Быстрый выбор';

  @override
  String get dnsAddress => 'Адрес DNS-сервера';

  @override
  String get dnsRemoteNote =>
      'Адрес DoH-сервера. Запросы идут через VPN и не видны оператору связи.';

  @override
  String get dnsDirectNote =>
      'IP-адрес или DoH. Используется для сайтов, которые открываются без VPN.';

  @override
  String get dnsYandex => 'Яндекс';

  @override
  String get mtuSection => 'Размер пакета';

  @override
  String get mtuNote =>
      'От 1280 до 9000. Если сайты грузятся не полностью, попробуйте 1400.';

  @override
  String get mtu1500Hint => 'Стандарт, рекомендуем';

  @override
  String get mtu1400Hint => 'Если сайты грузятся не полностью';

  @override
  String get mtu1280Hint => 'Минимальное значение';

  @override
  String get pingUrlSection => 'Адрес страницы';

  @override
  String get pingUrlNote =>
      'Страница, которую загружает URL-тест, чтобы измерить пинг через сервер.';

  @override
  String get crSection => 'Правила';

  @override
  String get crFooter =>
      'Правила проверяются сверху вниз, срабатывает первое подходящее. Зажмите правило, чтобы поменять порядок.';

  @override
  String get crAdd => 'Добавить';

  @override
  String crRuleLine(String match, String action) {
    return '$match → $action';
  }

  @override
  String get exTitle => 'Исключения';

  @override
  String get exSection => 'Адреса мимо VPN';

  @override
  String get exFooter =>
      'Эти адреса и подсети всегда идут мимо VPN. Например, домашний роутер или рабочая сеть.';

  @override
  String get exHome => 'Домашняя сеть';

  @override
  String get exWork => 'Рабочая сеть';

  @override
  String get exRemove => 'Удалить';

  @override
  String get nrTitle => 'Новое правило';

  @override
  String get nrAddress => 'Адрес сайта или IP';

  @override
  String get nrMatchSection => 'Что проверять';

  @override
  String get nrSuffix => 'Домен и поддомены';

  @override
  String nrSuffixHint(String host) {
    return '$host, m.$host и другие';
  }

  @override
  String get nrExact => 'Точный домен';

  @override
  String nrExactHint(String host) {
    return 'Только $host';
  }

  @override
  String get nrKeyword => 'Содержит слово';

  @override
  String nrKeywordHint(String word) {
    return 'Любой адрес со словом $word';
  }

  @override
  String get nrIp => 'IP-адрес или подсеть';

  @override
  String get nrIpHint => 'Например, 8.8.8.8 или 10.0.0.0/8';

  @override
  String get nrActionSection => 'Что делать';

  @override
  String get nrProxy => 'Через VPN';

  @override
  String get nrProxyHint => 'Открывать через сервер';

  @override
  String get nrDirect => 'Напрямую';

  @override
  String get nrDirectHint => 'Открывать без VPN';

  @override
  String get nrBlock => 'Блокировать';

  @override
  String get nrBlockHint => 'Не открывать совсем, например рекламу';

  @override
  String get nrActionProxyShort => 'через VPN';

  @override
  String get nrActionDirectShort => 'напрямую';

  @override
  String get nrActionBlockShort => 'блокировать';

  @override
  String get connectionNotConnected => 'Не подключено';

  @override
  String get connectionConnectedShort => 'Подключено';

  @override
  String get connectionUnavailable => 'Недоступно';

  @override
  String get pingSortByAlphabet => 'По алфавиту';

  @override
  String get freeServer => 'Бесплатный сервер';

  @override
  String get freeServerHint => 'Только для Telegram';

  @override
  String get freeGetFull => 'Получить полный доступ в Telegram-боте';

  @override
  String get freeHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get freeWhitelistHint =>
      'В бесплатном режиме нет обхода белых списков';

  @override
  String get freeWhitelistTitle => 'Белые списки недоступны';

  @override
  String get freeWhitelistText =>
      'Режим нужен, когда мобильный интернет ограничен белыми списками. Он откроется после входа через Telegram-бота.';

  @override
  String get loginOpenBotTelegram => 'Открыть бота в Telegram';

  @override
  String get loginSignIn => 'Войти';

  @override
  String get loginNewCode => 'Получить новый код';

  @override
  String loginResendInTimer(String time) {
    return 'Отправить код повторно через $time';
  }

  @override
  String get loginBotNotFound => 'Ник не найден среди пользователей бота';

  @override
  String get loginNoNickFooter =>
      'Нет ника в Telegram? Бот подскажет, как его задать';

  @override
  String loginCodeIntro(String username) {
    return 'Бот отправил 6 цифр в Telegram для @$username. Код действует 5 минут.';
  }

  @override
  String loginBotIntro(String username) {
    return 'Не нашли @$username среди пользователей бота. Откройте бота, нажмите Start и вернитесь сюда.';
  }

  @override
  String get loginBotHeading => 'Откройте бота';

  @override
  String get unitGb => 'ГБ';

  @override
  String get advAutoConnectTitle => 'Автоподключение';
}
