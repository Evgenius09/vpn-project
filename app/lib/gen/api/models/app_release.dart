// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'app_release.g.dart';

@JsonSerializable()
class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    required this.sha256,
    this.notes,
  });
  
  factory AppRelease.fromJson(Map<String, Object?> json) => _$AppReleaseFromJson(json);
  
  final String version;
  final String url;
  final String sha256;
  final String? notes;

  Map<String, Object?> toJson() => _$AppReleaseToJson(this);
}
