// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'core_error_code.dart';

part 'error_payload.g.dart';

@JsonSerializable()
class ErrorPayload {
  const ErrorPayload({
    required this.code,
    required this.message,
  });
  
  factory ErrorPayload.fromJson(Map<String, Object?> json) => _$ErrorPayloadFromJson(json);
  
  final CoreErrorCode code;
  final String message;

  Map<String, Object?> toJson() => _$ErrorPayloadToJson(this);
}
