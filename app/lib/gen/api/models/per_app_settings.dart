// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'per_app_mode.dart';

part 'per_app_settings.g.dart';

@JsonSerializable()
class PerAppSettings {
  const PerAppSettings({
    required this.mode,
    required this.apps,
  });
  
  factory PerAppSettings.fromJson(Map<String, Object?> json) => _$PerAppSettingsFromJson(json);
  
  final PerAppMode mode;
  final List<String> apps;

  Map<String, Object?> toJson() => _$PerAppSettingsToJson(this);
}
