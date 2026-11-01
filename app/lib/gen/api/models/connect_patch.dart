// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'auto_connect_strategy.dart';

part 'connect_patch.g.dart';

@JsonSerializable()
class ConnectPatch {
  const ConnectPatch({
    this.autoConnect,
    this.autoConnectStrategy,
    this.autostart,
  });
  
  factory ConnectPatch.fromJson(Map<String, Object?> json) => _$ConnectPatchFromJson(json);
  
  final bool? autoConnect;
  final AutoConnectStrategy? autoConnectStrategy;
  final bool? autostart;

  Map<String, Object?> toJson() => _$ConnectPatchToJson(this);
}
