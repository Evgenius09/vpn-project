// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'log_level.dart';

part 'tunnel_log.g.dart';

@JsonSerializable()
class TunnelLog {
  const TunnelLog({
    required this.level,
  });
  
  factory TunnelLog.fromJson(Map<String, Object?> json) => _$TunnelLogFromJson(json);
  
  final LogLevel level;

  Map<String, Object?> toJson() => _$TunnelLogToJson(this);
}
