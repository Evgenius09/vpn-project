// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'per_app_mode.dart';

part 'per_app_patch.g.dart';

@JsonSerializable()
class PerAppPatch {
  const PerAppPatch({this.mode, this.apps});

  factory PerAppPatch.fromJson(Map<String, Object?> json) =>
      _$PerAppPatchFromJson(json);

  final PerAppMode? mode;
  final List<String>? apps;

  Map<String, Object?> toJson() => _$PerAppPatchToJson(this);
}
