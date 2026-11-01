// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'local_rule_set.g.dart';

@JsonSerializable()
class LocalRuleSet {
  const LocalRuleSet({required this.id, required this.path});

  factory LocalRuleSet.fromJson(Map<String, Object?> json) =>
      _$LocalRuleSetFromJson(json);

  final String id;
  final String path;

  Map<String, Object?> toJson() => _$LocalRuleSetToJson(this);
}
