// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StatePayload _$StatePayloadFromJson(Map<String, dynamic> json) => StatePayload(
  status: $enumDecode(_$TunnelStatusEnumMap, json['status']),
  userMode: $enumDecode(_$TunnelModeEnumMap, json['userMode']),
  effectiveMode: $enumDecode(_$TunnelModeEnumMap, json['effectiveMode']),
  activeServerId: json['activeServerId'] as String?,
  connectedSince: json['connectedSince'] == null
      ? null
      : DateTime.parse(json['connectedSince'] as String),
);

Map<String, dynamic> _$StatePayloadToJson(StatePayload instance) =>
    <String, dynamic>{
      'status': instance.status.toJson(),
      'userMode': instance.userMode.toJson(),
      'effectiveMode': instance.effectiveMode.toJson(),
      'activeServerId': ?instance.activeServerId,
      'connectedSince': ?instance.connectedSince?.toIso8601String(),
    };

const _$TunnelStatusEnumMap = {
  TunnelStatus.disconnected: 'disconnected',
  TunnelStatus.connecting: 'connecting',
  TunnelStatus.connected: 'connected',
  TunnelStatus.disconnecting: 'disconnecting',
  TunnelStatus.error: 'error',
};

const _$TunnelModeEnumMap = {
  TunnelMode.regular: 'regular',
  TunnelMode.whitelist: 'whitelist',
};
