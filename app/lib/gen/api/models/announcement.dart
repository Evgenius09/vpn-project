// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'announcement_level.dart';

part 'announcement.g.dart';

@JsonSerializable()
class Announcement {
  const Announcement({
    required this.text,
    required this.level,
    this.actionLabel,
    this.actionUrl,
  });
  
  factory Announcement.fromJson(Map<String, Object?> json) => _$AnnouncementFromJson(json);
  
  final String text;
  final AnnouncementLevel level;
  final String? actionLabel;
  final String? actionUrl;

  Map<String, Object?> toJson() => _$AnnouncementToJson(this);
}
