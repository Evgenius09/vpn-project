// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'mode_switch_reason.dart';
import 'tunnel_mode.dart';

part 'mode_payload.g.dart';

@JsonSerializable()
class ModePayload {
  const ModePayload({
    required this.from,
    required this.to,
    required this.reason,
  });

  factory ModePayload.fromJson(Map<String, Object?> json) =>
      _$ModePayloadFromJson(json);

  final TunnelMode from;
  final TunnelMode to;
  final ModeSwitchReason reason;

  Map<String, Object?> toJson() => _$ModePayloadToJson(this);
}
