// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppRelease _$AppReleaseFromJson(Map<String, dynamic> json) => AppRelease(
  version: json['version'] as String,
  url: json['url'] as String,
  sha256: json['sha256'] as String,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$AppReleaseToJson(AppRelease instance) =>
    <String, dynamic>{
      'version': instance.version,
      'url': instance.url,
      'sha256': instance.sha256,
      'notes': ?instance.notes,
    };
