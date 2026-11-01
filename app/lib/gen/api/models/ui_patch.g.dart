// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ui_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UiPatch _$UiPatchFromJson(Map<String, dynamic> json) => UiPatch(
  sortByPing: json['sortByPing'] as bool?,
  locale: $enumDecodeNullable(_$UiLocaleEnumMap, json['locale']),
  theme: $enumDecodeNullable(_$UiThemeEnumMap, json['theme']),
);

Map<String, dynamic> _$UiPatchToJson(UiPatch instance) => <String, dynamic>{
  'sortByPing': ?instance.sortByPing,
  'locale': ?instance.locale?.toJson(),
  'theme': ?instance.theme?.toJson(),
};

const _$UiLocaleEnumMap = {
  UiLocale.system: 'system',
  UiLocale.ru: 'ru',
  UiLocale.en: 'en',
};

const _$UiThemeEnumMap = {
  UiTheme.system: 'system',
  UiTheme.light: 'light',
  UiTheme.dark: 'dark',
};
