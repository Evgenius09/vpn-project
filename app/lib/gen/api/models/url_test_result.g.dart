// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_test_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UrlTestResult _$UrlTestResultFromJson(Map<String, dynamic> json) =>
    UrlTestResult(
      serverId: json['serverId'] as String,
      delayMs: (json['delayMs'] as num?)?.toInt(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$UrlTestResultToJson(UrlTestResult instance) =>
    <String, dynamic>{
      'serverId': instance.serverId,
      'delayMs': ?instance.delayMs,
      'error': ?instance.error,
    };
