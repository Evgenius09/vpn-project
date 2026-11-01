// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'traffic_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrafficPayload _$TrafficPayloadFromJson(Map<String, dynamic> json) =>
    TrafficPayload(
      upBps: (json['upBps'] as num).toInt(),
      downBps: (json['downBps'] as num).toInt(),
      upTotal: (json['upTotal'] as num).toInt(),
      downTotal: (json['downTotal'] as num).toInt(),
    );

Map<String, dynamic> _$TrafficPayloadToJson(TrafficPayload instance) =>
    <String, dynamic>{
      'upBps': instance.upBps,
      'downBps': instance.downBps,
      'upTotal': instance.upTotal,
      'downTotal': instance.downTotal,
    };
