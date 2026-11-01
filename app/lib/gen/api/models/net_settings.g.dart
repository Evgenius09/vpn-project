// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'net_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetSettings _$NetSettingsFromJson(Map<String, dynamic> json) => NetSettings(
  ipv6: json['ipv6'] as bool,
  sniffing: json['sniffing'] as bool,
  tlsFragment: TlsFragment.fromJson(
    json['tlsFragment'] as Map<String, dynamic>,
  ),
  mtu: (json['mtu'] as num).toInt(),
  tunStack: $enumDecode(_$TunStackEnumMap, json['tunStack']),
  excludeRoutes: (json['excludeRoutes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  bypassLan: json['bypassLan'] as bool,
);

Map<String, dynamic> _$NetSettingsToJson(NetSettings instance) =>
    <String, dynamic>{
      'ipv6': instance.ipv6,
      'sniffing': instance.sniffing,
      'tlsFragment': instance.tlsFragment.toJson(),
      'mtu': instance.mtu,
      'tunStack': instance.tunStack.toJson(),
      'excludeRoutes': instance.excludeRoutes,
      'bypassLan': instance.bypassLan,
    };

const _$TunStackEnumMap = {
  TunStack.system: 'system',
  TunStack.gvisor: 'gvisor',
  TunStack.mixed: 'mixed',
};
