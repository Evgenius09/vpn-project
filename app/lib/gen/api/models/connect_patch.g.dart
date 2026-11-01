// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectPatch _$ConnectPatchFromJson(Map<String, dynamic> json) => ConnectPatch(
  autoConnect: json['autoConnect'] as bool?,
  autoConnectStrategy: $enumDecodeNullable(
    _$AutoConnectStrategyEnumMap,
    json['autoConnectStrategy'],
  ),
  autostart: json['autostart'] as bool?,
);

Map<String, dynamic> _$ConnectPatchToJson(ConnectPatch instance) =>
    <String, dynamic>{
      'autoConnect': ?instance.autoConnect,
      'autoConnectStrategy': ?instance.autoConnectStrategy?.toJson(),
      'autostart': ?instance.autostart,
    };

const _$AutoConnectStrategyEnumMap = {
  AutoConnectStrategy.lastUsed: 'last_used',
  AutoConnectStrategy.lowestPing: 'lowest_ping',
  AutoConnectStrategy.random: 'random',
};
