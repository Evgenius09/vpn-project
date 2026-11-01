// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dns_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DnsSettings _$DnsSettingsFromJson(Map<String, dynamic> json) => DnsSettings(
  remote: json['remote'] as String,
  direct: json['direct'] as String,
  strategy: $enumDecode(_$DnsStrategyEnumMap, json['strategy']),
);

Map<String, dynamic> _$DnsSettingsToJson(DnsSettings instance) =>
    <String, dynamic>{
      'remote': instance.remote,
      'direct': instance.direct,
      'strategy': instance.strategy.toJson(),
    };

const _$DnsStrategyEnumMap = {
  DnsStrategy.preferIpv4: 'prefer_ipv4',
  DnsStrategy.preferIpv6: 'prefer_ipv6',
  DnsStrategy.ipv4Only: 'ipv4_only',
  DnsStrategy.ipv6Only: 'ipv6_only',
};
