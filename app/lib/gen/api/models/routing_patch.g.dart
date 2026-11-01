// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutingPatch _$RoutingPatchFromJson(Map<String, dynamic> json) => RoutingPatch(
  enabled: json['enabled'] as bool?,
  preset: $enumDecodeNullable(_$RoutingPresetEnumMap, json['preset']),
  rules: (json['rules'] as List<dynamic>?)
      ?.map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RoutingPatchToJson(RoutingPatch instance) =>
    <String, dynamic>{
      'enabled': ?instance.enabled,
      'preset': ?instance.preset?.toJson(),
      'rules': ?instance.rules?.map((e) => e.toJson()).toList(),
    };

const _$RoutingPresetEnumMap = {
  RoutingPreset.ruDirect: 'ru_direct',
  RoutingPreset.allProxy: 'all_proxy',
  RoutingPreset.custom: 'custom',
};
