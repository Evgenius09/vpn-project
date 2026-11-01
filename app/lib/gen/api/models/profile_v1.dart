// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_info.dart';
import 'announcement.dart';
import 'client_policy.dart';
import 'profile_endpoints.dart';
import 'server_node.dart';

part 'profile_v1.g.dart';

@JsonSerializable()
class ProfileV1 {
  const ProfileV1({
    required this.schemaVersion,
    required this.generatedAt,
    required this.account,
    required this.servers,
    required this.policy,
    required this.endpoints,
    this.announcement,
  });

  factory ProfileV1.fromJson(Map<String, Object?> json) =>
      _$ProfileV1FromJson(json);

  final int schemaVersion;
  final DateTime generatedAt;
  final AccountInfo account;
  final List<ServerNode> servers;
  final ClientPolicy policy;
  final ProfileEndpoints endpoints;
  final Announcement? announcement;

  Map<String, Object?> toJson() => _$ProfileV1ToJson(this);
}
