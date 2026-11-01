// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelRequest _$TunnelRequestFromJson(
  Map<String, dynamic> json,
) => TunnelRequest(
  schemaVersion: (json['schemaVersion'] as num).toInt(),
  platform: $enumDecode(_$PlatformEnumMap, json['platform']),
  userMode: $enumDecode(_$TunnelModeEnumMap, json['userMode']),
  selected: SelectedServers.fromJson(json['selected'] as Map<String, dynamic>),
  servers: (json['servers'] as List<dynamic>)
      .map((e) => ServerNode.fromJson(e as Map<String, dynamic>))
      .toList(),
  autoSwitch: AutoSwitchRequest.fromJson(
    json['autoSwitch'] as Map<String, dynamic>,
  ),
  settings: TunnelSettings.fromJson(json['settings'] as Map<String, dynamic>),
  log: TunnelLog.fromJson(json['log'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TunnelRequestToJson(TunnelRequest instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'platform': instance.platform.toJson(),
      'userMode': instance.userMode.toJson(),
      'selected': instance.selected.toJson(),
      'servers': instance.servers.map((e) => e.toJson()).toList(),
      'autoSwitch': instance.autoSwitch.toJson(),
      'settings': instance.settings.toJson(),
      'log': instance.log.toJson(),
    };

const _$PlatformEnumMap = {
  Platform.android: 'android',
  Platform.windows: 'windows',
};

const _$TunnelModeEnumMap = {
  TunnelMode.regular: 'regular',
  TunnelMode.whitelist: 'whitelist',
};
