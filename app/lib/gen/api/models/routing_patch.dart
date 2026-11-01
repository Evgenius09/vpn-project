// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'routing_preset.dart';
import 'routing_rule.dart';

part 'routing_patch.g.dart';

@JsonSerializable()
class RoutingPatch {
  const RoutingPatch({this.enabled, this.preset, this.rules});

  factory RoutingPatch.fromJson(Map<String, Object?> json) =>
      _$RoutingPatchFromJson(json);

  final bool? enabled;
  final RoutingPreset? preset;
  final List<RoutingRule>? rules;

  Map<String, Object?> toJson() => _$RoutingPatchToJson(this);
}
