// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'dns_strategy.dart';

part 'dns_settings.g.dart';

@JsonSerializable()
class DnsSettings {
  const DnsSettings({
    required this.remote,
    required this.direct,
    required this.strategy,
  });
  
  factory DnsSettings.fromJson(Map<String, Object?> json) => _$DnsSettingsFromJson(json);
  
  final String remote;
  final String direct;
  final DnsStrategy strategy;

  Map<String, Object?> toJson() => _$DnsSettingsToJson(this);
}
