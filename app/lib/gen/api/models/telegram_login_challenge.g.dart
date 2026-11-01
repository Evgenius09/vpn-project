// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_login_challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelegramLoginChallenge _$TelegramLoginChallengeFromJson(
  Map<String, dynamic> json,
) => TelegramLoginChallenge(
  loginId: json['loginId'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  resendAfterSec: (json['resendAfterSec'] as num).toInt(),
  botUrl: json['botUrl'] as String,
);

Map<String, dynamic> _$TelegramLoginChallengeToJson(
  TelegramLoginChallenge instance,
) => <String, dynamic>{
  'loginId': instance.loginId,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'resendAfterSec': instance.resendAfterSec,
  'botUrl': instance.botUrl,
};
