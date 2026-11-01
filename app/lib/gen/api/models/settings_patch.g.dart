// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SettingsPatch _$SettingsPatchFromJson(Map<String, dynamic> json) =>
    SettingsPatch(
      routing: json['routing'] == null
          ? null
          : RoutingPatch.fromJson(json['routing'] as Map<String, dynamic>),
      dns: json['dns'] == null
          ? null
          : DnsPatch.fromJson(json['dns'] as Map<String, dynamic>),
      net: json['net'] == null
          ? null
          : NetPatch.fromJson(json['net'] as Map<String, dynamic>),
      perApp: json['perApp'] == null
          ? null
          : PerAppPatch.fromJson(json['perApp'] as Map<String, dynamic>),
      ping: json['ping'] == null
          ? null
          : PingPatch.fromJson(json['ping'] as Map<String, dynamic>),
      connect: json['connect'] == null
          ? null
          : ConnectPatch.fromJson(json['connect'] as Map<String, dynamic>),
      ui: json['ui'] == null
          ? null
          : UiPatch.fromJson(json['ui'] as Map<String, dynamic>),
      whitelist: json['whitelist'] == null
          ? null
          : WhitelistPatch.fromJson(json['whitelist'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SettingsPatchToJson(SettingsPatch instance) =>
    <String, dynamic>{
      'routing': ?instance.routing?.toJson(),
      'dns': ?instance.dns?.toJson(),
      'net': ?instance.net?.toJson(),
      'perApp': ?instance.perApp?.toJson(),
      'ping': ?instance.ping?.toJson(),
      'connect': ?instance.connect?.toJson(),
      'ui': ?instance.ui?.toJson(),
      'whitelist': ?instance.whitelist?.toJson(),
    };
