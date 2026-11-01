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
  String get loginTitle => 'Вход';

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
}
