// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'rule_action.dart';
import 'rule_match.dart';

part 'routing_rule.g.dart';

@JsonSerializable()
class RoutingRule {
  const RoutingRule({
    required this.id,
    required this.match,
    required this.value,
    required this.action,
  });

  factory RoutingRule.fromJson(Map<String, Object?> json) =>
      _$RoutingRuleFromJson(json);

  final String id;
  final RuleMatch match;

  /// For match app, a package on Android and a process on Windows.
  final String value;
  final RuleAction action;

  Map<String, Object?> toJson() => _$RoutingRuleToJson(this);
}
