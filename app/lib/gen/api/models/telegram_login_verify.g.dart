// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_login_verify.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelegramLoginVerify _$TelegramLoginVerifyFromJson(Map<String, dynamic> json) =>
    TelegramLoginVerify(
      loginId: json['loginId'] as String,
      code: json['code'] as String,
      installId: json['installId'] as String,
      platform: $enumDecode(_$PlatformEnumMap, json['platform']),
      model: json['model'] as String,
      appVersion: json['appVersion'] as String,
    );

Map<String, dynamic> _$TelegramLoginVerifyToJson(
  TelegramLoginVerify instance,
) => <String, dynamic>{
  'loginId': instance.loginId,
  'code': instance.code,
  'installId': instance.installId,
  'platform': instance.platform.toJson(),
  'model': instance.model,
  'appVersion': instance.appVersion,
};

const _$PlatformEnumMap = {
  Platform.android: 'android',
  Platform.windows: 'windows',
};
