// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'port_hopping.g.dart';

@JsonSerializable()
class PortHopping {
  const PortHopping({
    required this.ports,
    required this.intervalSec,
  });
  
  factory PortHopping.fromJson(Map<String, Object?> json) => _$PortHoppingFromJson(json);
  
  /// A range such as 20000-30000 or a list such as 443,8443.
  final String ports;
  final int intervalSec;

  Map<String, Object?> toJson() => _$PortHoppingToJson(this);
}
