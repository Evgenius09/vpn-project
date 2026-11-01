// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'url_test_result.dart';

part 'url_test_payload.g.dart';

@JsonSerializable()
class UrlTestPayload {
  const UrlTestPayload({required this.results});

  factory UrlTestPayload.fromJson(Map<String, Object?> json) =>
      _$UrlTestPayloadFromJson(json);

  final List<UrlTestResult> results;

  Map<String, Object?> toJson() => _$UrlTestPayloadToJson(this);
}
