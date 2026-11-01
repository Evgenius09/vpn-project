// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'port_hopping.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PortHopping _$PortHoppingFromJson(Map<String, dynamic> json) => PortHopping(
  ports: json['ports'] as String,
  intervalSec: (json['intervalSec'] as num).toInt(),
);

Map<String, dynamic> _$PortHoppingToJson(PortHopping instance) =>
    <String, dynamic>{
      'ports': instance.ports,
      'intervalSec': instance.intervalSec,
    };
