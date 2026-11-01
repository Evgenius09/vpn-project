// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'per_app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PerAppSettings _$PerAppSettingsFromJson(Map<String, dynamic> json) =>
    PerAppSettings(
      mode: $enumDecode(_$PerAppModeEnumMap, json['mode']),
      apps: (json['apps'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PerAppSettingsToJson(PerAppSettings instance) =>
    <String, dynamic>{'mode': instance.mode.toJson(), 'apps': instance.apps};

const _$PerAppModeEnumMap = {
  PerAppMode.off: 'off',
  PerAppMode.include: 'include',
  PerAppMode.exclude: 'exclude',
};
