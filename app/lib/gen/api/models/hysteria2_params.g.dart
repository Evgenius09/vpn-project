// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hysteria2_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Hysteria2Params _$Hysteria2ParamsFromJson(Map<String, dynamic> json) =>
    Hysteria2Params(
      password: json['password'] as String,
      serverName: json['serverName'] as String,
      obfsSalamanderPassword: json['obfsSalamanderPassword'] as String?,
      portHopping: json['portHopping'] == null
          ? null
          : PortHopping.fromJson(json['portHopping'] as Map<String, dynamic>),
      upMbps: (json['upMbps'] as num?)?.toInt(),
      downMbps: (json['downMbps'] as num?)?.toInt(),
    );

Map<String, dynamic> _$Hysteria2ParamsToJson(Hysteria2Params instance) =>
    <String, dynamic>{
      'password': instance.password,
      'serverName': instance.serverName,
      'obfsSalamanderPassword': ?instance.obfsSalamanderPassword,
      'portHopping': ?instance.portHopping?.toJson(),
      'upMbps': ?instance.upMbps,
      'downMbps': ?instance.downMbps,
    };
