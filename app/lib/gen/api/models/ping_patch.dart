// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ping_type.dart';

part 'ping_patch.g.dart';

@JsonSerializable()
class PingPatch {
  const PingPatch({this.type, this.url, this.timeoutMs, this.onOpen});

  factory PingPatch.fromJson(Map<String, Object?> json) =>
      _$PingPatchFromJson(json);

  final PingType? type;
  final String? url;
  final int? timeoutMs;
  final bool? onOpen;

  Map<String, Object?> toJson() => _$PingPatchToJson(this);
}
