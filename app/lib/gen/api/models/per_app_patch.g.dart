// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'per_app_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PerAppPatch _$PerAppPatchFromJson(Map<String, dynamic> json) => PerAppPatch(
  mode: $enumDecodeNullable(_$PerAppModeEnumMap, json['mode']),
  apps: (json['apps'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$PerAppPatchToJson(PerAppPatch instance) =>
    <String, dynamic>{'mode': ?instance.mode?.toJson(), 'apps': ?instance.apps};

const _$PerAppModeEnumMap = {
  PerAppMode.off: 'off',
  PerAppMode.include: 'include',
  PerAppMode.exclude: 'exclude',
};
