// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'traffic_payload.g.dart';

@JsonSerializable()
class TrafficPayload {
  const TrafficPayload({
    required this.upBps,
    required this.downBps,
    required this.upTotal,
    required this.downTotal,
  });
  
  factory TrafficPayload.fromJson(Map<String, Object?> json) => _$TrafficPayloadFromJson(json);
  
  final int upBps;
  final int downBps;
  final int upTotal;
  final int downTotal;

  Map<String, Object?> toJson() => _$TrafficPayloadToJson(this);
}
