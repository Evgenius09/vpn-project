// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerNode _$ServerNodeFromJson(Map<String, dynamic> json) => ServerNode(
  id: json['id'] as String,
  group: $enumDecode(_$TunnelModeEnumMap, json['group']),
  name: json['name'] as String,
  protocol: $enumDecode(_$ServerProtocolEnumMap, json['protocol']),
  address: json['address'] as String,
  port: (json['port'] as num).toInt(),
  sortWeight: (json['sortWeight'] as num).toInt(),
  countryCode: json['countryCode'] as String?,
  city: json['city'] as String?,
  vless: json['vless'] == null
      ? null
      : VlessRealityParams.fromJson(json['vless'] as Map<String, dynamic>),
  hysteria2: json['hysteria2'] == null
      ? null
      : Hysteria2Params.fromJson(json['hysteria2'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ServerNodeToJson(ServerNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group': instance.group.toJson(),
      'name': instance.name,
      'countryCode': ?instance.countryCode,
      'city': ?instance.city,
      'protocol': instance.protocol.toJson(),
      'address': instance.address,
      'port': instance.port,
      'vless': ?instance.vless?.toJson(),
      'hysteria2': ?instance.hysteria2?.toJson(),
      'sortWeight': instance.sortWeight,
    };

const _$TunnelModeEnumMap = {
  TunnelMode.regular: 'regular',
  TunnelMode.whitelist: 'whitelist',
};

const _$ServerProtocolEnumMap = {
  ServerProtocol.vlessReality: 'vless_reality',
  ServerProtocol.hysteria2: 'hysteria2',
};
