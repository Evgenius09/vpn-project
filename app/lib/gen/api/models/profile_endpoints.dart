// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'profile_endpoints.g.dart';

@JsonSerializable()
class ProfileEndpoints {
  const ProfileEndpoints({
    required this.api,
    required this.bot,
    this.support,
    this.web,
  });

  factory ProfileEndpoints.fromJson(Map<String, Object?> json) =>
      _$ProfileEndpointsFromJson(json);

  /// The first entry is primary, the rest are fallbacks.
  final List<String> api;
  final String bot;
  final String? support;
  final String? web;

  Map<String, Object?> toJson() => _$ProfileEndpointsToJson(this);
}
