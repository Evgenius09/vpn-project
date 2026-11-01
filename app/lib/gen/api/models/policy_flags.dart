// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'policy_flags.g.dart';

@JsonSerializable()
class PolicyFlags {
  const PolicyFlags({required this.autoWhitelist});

  factory PolicyFlags.fromJson(Map<String, Object?> json) =>
      _$PolicyFlagsFromJson(json);

  final bool autoWhitelist;

  Map<String, Object?> toJson() => _$PolicyFlagsToJson(this);
}
