// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutingSettings _$RoutingSettingsFromJson(Map<String, dynamic> json) =>
    RoutingSettings(
      enabled: json['enabled'] as bool,
      preset: $enumDecode(_$RoutingPresetEnumMap, json['preset']),
      rules: (json['rules'] as List<dynamic>)
          .map((e) => RoutingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      ruleSets: (json['ruleSets'] as List<dynamic>)
          .map((e) => LocalRuleSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RoutingSettingsToJson(RoutingSettings instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'preset': instance.preset.toJson(),
      'rules': instance.rules.map((e) => e.toJson()).toList(),
      'ruleSets': instance.ruleSets.map((e) => e.toJson()).toList(),
    };

const _$RoutingPresetEnumMap = {
  RoutingPreset.ruDirect: 'ru_direct',
  RoutingPreset.allProxy: 'all_proxy',
  RoutingPreset.custom: 'custom',
};
