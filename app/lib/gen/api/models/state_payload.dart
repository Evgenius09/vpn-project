// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'tunnel_mode.dart';
import 'tunnel_status.dart';

part 'state_payload.g.dart';

@JsonSerializable()
class StatePayload {
  const StatePayload({
    required this.status,
    required this.userMode,
    required this.effectiveMode,
    this.activeServerId,
    this.connectedSince,
  });

  factory StatePayload.fromJson(Map<String, Object?> json) =>
      _$StatePayloadFromJson(json);

  final TunnelStatus status;
  final TunnelMode userMode;
  final TunnelMode effectiveMode;
  final String? activeServerId;
  final DateTime? connectedSince;

  Map<String, Object?> toJson() => _$StatePayloadToJson(this);
}
