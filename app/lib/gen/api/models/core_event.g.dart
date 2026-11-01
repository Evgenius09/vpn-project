// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CoreEvent _$CoreEventFromJson(Map<String, dynamic> json) => CoreEvent(
  type: $enumDecode(_$CoreEventTypeEnumMap, json['type']),
  at: DateTime.parse(json['at'] as String),
  state: json['state'] == null
      ? null
      : StatePayload.fromJson(json['state'] as Map<String, dynamic>),
  mode: json['mode'] == null
      ? null
      : ModePayload.fromJson(json['mode'] as Map<String, dynamic>),
  traffic: json['traffic'] == null
      ? null
      : TrafficPayload.fromJson(json['traffic'] as Map<String, dynamic>),
  urlTest: json['urlTest'] == null
      ? null
      : UrlTestPayload.fromJson(json['urlTest'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorPayload.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CoreEventToJson(CoreEvent instance) => <String, dynamic>{
  'type': instance.type.toJson(),
  'at': instance.at.toIso8601String(),
  'state': ?instance.state?.toJson(),
  'mode': ?instance.mode?.toJson(),
  'traffic': ?instance.traffic?.toJson(),
  'urlTest': ?instance.urlTest?.toJson(),
  'error': ?instance.error?.toJson(),
};

const _$CoreEventTypeEnumMap = {
  CoreEventType.state: 'state',
  CoreEventType.mode: 'mode',
  CoreEventType.traffic: 'traffic',
  CoreEventType.urlTest: 'url_test',
  CoreEventType.error: 'error',
};
