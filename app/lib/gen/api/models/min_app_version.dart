// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'min_app_version.g.dart';

@JsonSerializable()
class MinAppVersion {
  const MinAppVersion({required this.android, required this.windows});

  factory MinAppVersion.fromJson(Map<String, Object?> json) =>
      _$MinAppVersionFromJson(json);

  final String android;
  final String windows;

  Map<String, Object?> toJson() => _$MinAppVersionToJson(this);
}
