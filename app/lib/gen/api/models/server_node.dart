// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'hysteria2_params.dart';
import 'server_protocol.dart';
import 'tunnel_mode.dart';
import 'vless_reality_params.dart';

part 'server_node.g.dart';

@JsonSerializable()
class ServerNode {
  const ServerNode({
    required this.id,
    required this.group,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    required this.sortWeight,
    this.countryCode,
    this.city,
    this.vless,
    this.hysteria2,
  });
  
  factory ServerNode.fromJson(Map<String, Object?> json) => _$ServerNodeFromJson(json);
  
  final String id;
  final TunnelMode group;
  final String name;
  final String? countryCode;
  final String? city;
  final ServerProtocol protocol;
  final String address;
  final int port;
  final VlessRealityParams? vless;
  final Hysteria2Params? hysteria2;
  final int sortWeight;

  Map<String, Object?> toJson() => _$ServerNodeToJson(this);
}
