// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'selected_servers.g.dart';

@JsonSerializable()
class SelectedServers {
  const SelectedServers({
    this.regular,
    this.whitelist,
  });
  
  factory SelectedServers.fromJson(Map<String, Object?> json) => _$SelectedServersFromJson(json);
  
  final String? regular;
  final String? whitelist;

  Map<String, Object?> toJson() => _$SelectedServersToJson(this);
}
