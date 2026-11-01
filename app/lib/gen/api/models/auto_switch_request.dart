// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'auto_switch_request.g.dart';

@JsonSerializable()
class AutoSwitchRequest {
  const AutoSwitchRequest({required this.enabled});

  factory AutoSwitchRequest.fromJson(Map<String, Object?> json) =>
      _$AutoSwitchRequestFromJson(json);

  final bool enabled;

  Map<String, Object?> toJson() => _$AutoSwitchRequestToJson(this);
}
