// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'url_test_result.g.dart';

@JsonSerializable()
class UrlTestResult {
  const UrlTestResult({required this.serverId, this.delayMs, this.error});

  factory UrlTestResult.fromJson(Map<String, Object?> json) =>
      _$UrlTestResultFromJson(json);

  final String serverId;
  final int? delayMs;
  final String? error;

  Map<String, Object?> toJson() => _$UrlTestResultToJson(this);
}
