// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelSettings _$TunnelSettingsFromJson(Map<String, dynamic> json) =>
    TunnelSettings(
      routing: RoutingSettings.fromJson(
        json['routing'] as Map<String, dynamic>,
      ),
      dns: DnsSettings.fromJson(json['dns'] as Map<String, dynamic>),
      net: NetSettings.fromJson(json['net'] as Map<String, dynamic>),
      perApp: PerAppSettings.fromJson(json['perApp'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TunnelSettingsToJson(TunnelSettings instance) =>
    <String, dynamic>{
      'routing': instance.routing.toJson(),
      'dns': instance.dns.toJson(),
      'net': instance.net.toJson(),
      'perApp': instance.perApp.toJson(),
    };
