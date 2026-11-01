// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'port_hopping.dart';

part 'hysteria2_params.g.dart';

@JsonSerializable()
class Hysteria2Params {
  const Hysteria2Params({
    required this.password,
    required this.serverName,
    this.obfsSalamanderPassword,
    this.portHopping,
    this.upMbps,
    this.downMbps,
  });
  
  factory Hysteria2Params.fromJson(Map<String, Object?> json) => _$Hysteria2ParamsFromJson(json);
  
  /// Secret.
  final String password;
  final String serverName;
  final String? obfsSalamanderPassword;
  final PortHopping? portHopping;
  final int? upMbps;
  final int? downMbps;

  Map<String, Object?> toJson() => _$Hysteria2ParamsToJson(this);
}
