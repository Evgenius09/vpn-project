// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'local_rule_set.dart';
import 'routing_preset.dart';
import 'routing_rule.dart';

part 'routing_settings.g.dart';

@JsonSerializable()
class RoutingSettings {
  const RoutingSettings({
    required this.enabled,
    required this.preset,
    required this.rules,
    required this.ruleSets,
  });
  
  factory RoutingSettings.fromJson(Map<String, Object?> json) => _$RoutingSettingsFromJson(json);
  
  final bool enabled;
  final RoutingPreset preset;
  final List<RoutingRule> rules;
  final List<LocalRuleSet> ruleSets;

  Map<String, Object?> toJson() => _$RoutingSettingsToJson(this);
}
