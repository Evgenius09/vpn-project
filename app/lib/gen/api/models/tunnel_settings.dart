// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'dns_settings.dart';
import 'net_settings.dart';
import 'per_app_settings.dart';
import 'routing_settings.dart';

part 'tunnel_settings.g.dart';

@JsonSerializable()
class TunnelSettings {
  const TunnelSettings({
    required this.routing,
    required this.dns,
    required this.net,
    required this.perApp,
  });

  factory TunnelSettings.fromJson(Map<String, Object?> json) =>
      _$TunnelSettingsFromJson(json);

  final RoutingSettings routing;
  final DnsSettings dns;
  final NetSettings net;
  final PerAppSettings perApp;

  Map<String, Object?> toJson() => _$TunnelSettingsToJson(this);
}
