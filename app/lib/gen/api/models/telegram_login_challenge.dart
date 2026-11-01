// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'telegram_login_challenge.g.dart';

@JsonSerializable()
class TelegramLoginChallenge {
  const TelegramLoginChallenge({
    required this.loginId,
    required this.expiresAt,
    required this.resendAfterSec,
    required this.botUrl,
  });

  factory TelegramLoginChallenge.fromJson(Map<String, Object?> json) =>
      _$TelegramLoginChallengeFromJson(json);

  final String loginId;
  final DateTime expiresAt;
  final int resendAfterSec;
  final String botUrl;

  Map<String, Object?> toJson() => _$TelegramLoginChallengeToJson(this);
}
