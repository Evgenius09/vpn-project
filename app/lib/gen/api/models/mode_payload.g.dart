// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mode_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModePayload _$ModePayloadFromJson(Map<String, dynamic> json) => ModePayload(
  from: $enumDecode(_$TunnelModeEnumMap, json['from']),
  to: $enumDecode(_$TunnelModeEnumMap, json['to']),
  reason: $enumDecode(_$ModeSwitchReasonEnumMap, json['reason']),
);

Map<String, dynamic> _$ModePayloadToJson(ModePayload instance) =>
    <String, dynamic>{
      'from': instance.from.toJson(),
      'to': instance.to.toJson(),
      'reason': instance.reason.toJson(),
    };

const _$TunnelModeEnumMap = {
  TunnelMode.regular: 'regular',
  TunnelMode.whitelist: 'whitelist',
};

const _$ModeSwitchReasonEnumMap = {
  ModeSwitchReason.user: 'user',
  ModeSwitchReason.networkCellular: 'network_cellular',
  ModeSwitchReason.networkWifi: 'network_wifi',
  ModeSwitchReason.overrideCleared: 'override_cleared',
  ModeSwitchReason.noWhitelistServers: 'no_whitelist_servers',
};
