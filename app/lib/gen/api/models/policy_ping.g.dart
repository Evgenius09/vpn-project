// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'policy_ping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolicyPing _$PolicyPingFromJson(Map<String, dynamic> json) => PolicyPing(
  url: json['url'] as String,
  timeoutMs: (json['timeoutMs'] as num).toInt(),
);

Map<String, dynamic> _$PolicyPingToJson(PolicyPing instance) =>
    <String, dynamic>{'url': instance.url, 'timeoutMs': instance.timeoutMs};
