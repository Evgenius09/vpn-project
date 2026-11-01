// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ping_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PingPatch _$PingPatchFromJson(Map<String, dynamic> json) => PingPatch(
  type: $enumDecodeNullable(_$PingTypeEnumMap, json['type']),
  url: json['url'] as String?,
  timeoutMs: (json['timeoutMs'] as num?)?.toInt(),
  onOpen: json['onOpen'] as bool?,
);

Map<String, dynamic> _$PingPatchToJson(PingPatch instance) => <String, dynamic>{
  'type': ?instance.type?.toJson(),
  'url': ?instance.url,
  'timeoutMs': ?instance.timeoutMs,
  'onOpen': ?instance.onOpen,
};

const _$PingTypeEnumMap = {PingType.tcp: 'tcp', PingType.urlTest: 'url_test'};
