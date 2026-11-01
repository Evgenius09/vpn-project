// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountInfo _$AccountInfoFromJson(Map<String, dynamic> json) => AccountInfo(
  status: $enumDecode(_$AccountStatusEnumMap, json['status']),
  trafficUsedBytes: (json['trafficUsedBytes'] as num).toInt(),
  trafficLimitBytes: (json['trafficLimitBytes'] as num).toInt(),
  deviceLimit: (json['deviceLimit'] as num).toInt(),
  telegramUsername: json['telegramUsername'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$AccountInfoToJson(AccountInfo instance) =>
    <String, dynamic>{
      'status': instance.status.toJson(),
      'telegramUsername': ?instance.telegramUsername,
      'expiresAt': ?instance.expiresAt?.toIso8601String(),
      'trafficUsedBytes': instance.trafficUsedBytes,
      'trafficLimitBytes': instance.trafficLimitBytes,
      'deviceLimit': instance.deviceLimit,
    };

const _$AccountStatusEnumMap = {
  AccountStatus.provisioning: 'provisioning',
  AccountStatus.trial: 'trial',
  AccountStatus.active: 'active',
  AccountStatus.expired: 'expired',
  AccountStatus.blocked: 'blocked',
};
