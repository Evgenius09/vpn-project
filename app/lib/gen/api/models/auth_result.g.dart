// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResult _$AuthResultFromJson(Map<String, dynamic> json) => AuthResult(
  deviceId: json['deviceId'] as String,
  accountId: json['accountId'] as String,
  token: json['token'] as String,
);

Map<String, dynamic> _$AuthResultToJson(AuthResult instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'accountId': instance.accountId,
      'token': instance.token,
    };
