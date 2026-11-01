// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'policy_ping.g.dart';

@JsonSerializable()
class PolicyPing {
  const PolicyPing({required this.url, required this.timeoutMs});

  factory PolicyPing.fromJson(Map<String, Object?> json) =>
      _$PolicyPingFromJson(json);

  final String url;
  final int timeoutMs;

  Map<String, Object?> toJson() => _$PolicyPingToJson(this);
}
