// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_test_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UrlTestPayload _$UrlTestPayloadFromJson(Map<String, dynamic> json) =>
    UrlTestPayload(
      results: (json['results'] as List<dynamic>)
          .map((e) => UrlTestResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UrlTestPayloadToJson(UrlTestPayload instance) =>
    <String, dynamic>{
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
