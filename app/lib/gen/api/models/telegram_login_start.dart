// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'telegram_login_start.g.dart';

@JsonSerializable()
class TelegramLoginStart {
  const TelegramLoginStart({
    required this.username,
    required this.installId,
    required this.model,
  });

  factory TelegramLoginStart.fromJson(Map<String, Object?> json) =>
      _$TelegramLoginStartFromJson(json);

  final String username;
  final String installId;
  final String model;

  Map<String, Object?> toJson() => _$TelegramLoginStartToJson(this);
}
