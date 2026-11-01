// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_release.dart';

part 'app_update.g.dart';

@JsonSerializable()
class AppUpdate {
  const AppUpdate({this.android, this.windows});

  factory AppUpdate.fromJson(Map<String, Object?> json) =>
      _$AppUpdateFromJson(json);

  final AppRelease? android;
  final AppRelease? windows;

  Map<String, Object?> toJson() => _$AppUpdateToJson(this);
}
