// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_servers.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SelectedServers _$SelectedServersFromJson(Map<String, dynamic> json) =>
    SelectedServers(
      regular: json['regular'] as String?,
      whitelist: json['whitelist'] as String?,
    );

Map<String, dynamic> _$SelectedServersToJson(SelectedServers instance) =>
    <String, dynamic>{
      'regular': ?instance.regular,
      'whitelist': ?instance.whitelist,
    };
