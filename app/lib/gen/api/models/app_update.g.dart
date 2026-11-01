// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUpdate _$AppUpdateFromJson(Map<String, dynamic> json) => AppUpdate(
  android: json['android'] == null
      ? null
      : AppRelease.fromJson(json['android'] as Map<String, dynamic>),
  windows: json['windows'] == null
      ? null
      : AppRelease.fromJson(json['windows'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AppUpdateToJson(AppUpdate instance) => <String, dynamic>{
  'android': ?instance.android?.toJson(),
  'windows': ?instance.windows?.toJson(),
};
