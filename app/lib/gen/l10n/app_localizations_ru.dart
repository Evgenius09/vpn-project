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
  String get profileLoadFailed => 'Не удалось загрузить профиль';

  @override
  String get profileFromCache =>
      'Нет связи с сервером, показаны сохранённые данные';

  @override
  String get loginUsernameTitle => 'Вход через Telegram';

  @override
  String get loginUsernameMessage =>
      'Введите ваш ник в Telegram. Бот пришлёт код для входа.';

  @override
  String get loginUsernameLabel => 'Ник в Telegram';

  @override
  String get loginGetCode => 'Получить код';

  @override
  String get loginInvalidUsername =>
      'Ник: от 4 до 32 латинских букв, цифр или знаков подчёркивания';

  @override
  String get loginBotTitle => 'Откройте бота и нажмите Start';

  @override
  String get loginBotMessage =>
      'Бот может написать только тем, кто его запустил. Нажмите Start в боте и вернитесь сюда.';

  @override
  String get loginOpenBot => 'Открыть бота';

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
      'Нет связи с сервером. Проверьте интернет и повторите.';

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
    return 'Слишком много попыток. Повторите через $seconds с.';
  }

  @override
  String get loginErrorRateLimitedLater =>
      'Слишком много попыток. Повторите позже.';

  @override
  String get loginErrorUserNotFound =>
      'Ник не найден среди пользователей бота. Откройте бота и нажмите Start.';

  @override
  String loginErrorCodeInvalid(int attempts) {
    return 'Неверный код. Осталось попыток: $attempts.';
  }

  @override
  String get loginErrorCodeInvalidNoCount => 'Неверный код.';

  @override
  String get loginErrorCodeExpired =>
      'Код истёк или попытки закончились. Запросите новый код.';

  @override
  String get loginErrorDeviceLimit =>
      'Достигнут лимит устройств аккаунта. Отключите другое устройство и введите код снова.';

  @override
  String get loginErrorPanelUnavailable =>
      'Сервис VPN временно недоступен. Повторите позже.';

  @override
  String get loginErrorNotFound =>
      'Сервер не нашёл запрос. Начните вход заново.';

  @override
  String get loginErrorInternal => 'Ошибка на сервере. Повторите позже.';

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
  String get connectionDisconnected => 'Отключено';

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
}
