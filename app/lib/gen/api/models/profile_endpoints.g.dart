// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_endpoints.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileEndpoints _$ProfileEndpointsFromJson(Map<String, dynamic> json) =>
    ProfileEndpoints(
      api: (json['api'] as List<dynamic>).map((e) => e as String).toList(),
      bot: json['bot'] as String,
      support: json['support'] as String?,
      web: json['web'] as String?,
    );

Map<String, dynamic> _$ProfileEndpointsToJson(ProfileEndpoints instance) =>
    <String, dynamic>{
      'api': instance.api,
      'bot': instance.bot,
      'support': ?instance.support,
      'web': ?instance.web,
    };
