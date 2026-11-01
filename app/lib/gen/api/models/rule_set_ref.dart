// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'rule_set_ref.g.dart';

@JsonSerializable()
class RuleSetRef {
  const RuleSetRef({
    required this.id,
    required this.url,
    required this.sha256,
  });
  
  factory RuleSetRef.fromJson(Map<String, Object?> json) => _$RuleSetRefFromJson(json);
  
  final String id;
  final String url;
  final String sha256;

  Map<String, Object?> toJson() => _$RuleSetRefToJson(this);
}
