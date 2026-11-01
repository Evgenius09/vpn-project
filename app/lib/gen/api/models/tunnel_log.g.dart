// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelLog _$TunnelLogFromJson(Map<String, dynamic> json) =>
    TunnelLog(level: $enumDecode(_$LogLevelEnumMap, json['level']));

Map<String, dynamic> _$TunnelLogToJson(TunnelLog instance) => <String, dynamic>{
  'level': instance.level.toJson(),
};

const _$LogLevelEnumMap = {
  LogLevel.warn: 'warn',
  LogLevel.info: 'info',
  LogLevel.debug: 'debug',
};
