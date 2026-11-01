// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_v1.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileV1 _$ProfileV1FromJson(Map<String, dynamic> json) => ProfileV1(
  schemaVersion: (json['schemaVersion'] as num).toInt(),
  generatedAt: DateTime.parse(json['generatedAt'] as String),
  account: AccountInfo.fromJson(json['account'] as Map<String, dynamic>),
  servers: (json['servers'] as List<dynamic>)
      .map((e) => ServerNode.fromJson(e as Map<String, dynamic>))
      .toList(),
  policy: ClientPolicy.fromJson(json['policy'] as Map<String, dynamic>),
  endpoints: ProfileEndpoints.fromJson(
    json['endpoints'] as Map<String, dynamic>,
  ),
  announcement: json['announcement'] == null
      ? null
      : Announcement.fromJson(json['announcement'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProfileV1ToJson(ProfileV1 instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'generatedAt': instance.generatedAt.toIso8601String(),
  'account': instance.account.toJson(),
  'servers': instance.servers.map((e) => e.toJson()).toList(),
  'policy': instance.policy.toJson(),
  'endpoints': instance.endpoints.toJson(),
  'announcement': ?instance.announcement?.toJson(),
};
