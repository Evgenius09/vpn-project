// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Announcement _$AnnouncementFromJson(Map<String, dynamic> json) => Announcement(
  text: json['text'] as String,
  level: $enumDecode(_$AnnouncementLevelEnumMap, json['level']),
  actionLabel: json['actionLabel'] as String?,
  actionUrl: json['actionUrl'] as String?,
);

Map<String, dynamic> _$AnnouncementToJson(Announcement instance) =>
    <String, dynamic>{
      'text': instance.text,
      'level': instance.level.toJson(),
      'actionLabel': ?instance.actionLabel,
      'actionUrl': ?instance.actionUrl,
    };

const _$AnnouncementLevelEnumMap = {
  AnnouncementLevel.info: 'info',
  AnnouncementLevel.warning: 'warning',
};
