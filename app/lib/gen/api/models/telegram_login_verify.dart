// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'platform.dart';

part 'telegram_login_verify.g.dart';

@JsonSerializable()
class TelegramLoginVerify {
  const TelegramLoginVerify({
    required this.loginId,
    required this.code,
    required this.installId,
    required this.platform,
    required this.model,
    required this.appVersion,
  });
  
  factory TelegramLoginVerify.fromJson(Map<String, Object?> json) => _$TelegramLoginVerifyFromJson(json);
  
  final String loginId;
  final String code;
  final String installId;
  final Platform platform;
  final String model;
  final String appVersion;

  Map<String, Object?> toJson() => _$TelegramLoginVerifyToJson(this);
}
