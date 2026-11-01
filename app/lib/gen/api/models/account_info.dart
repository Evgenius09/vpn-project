// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_status.dart';

part 'account_info.g.dart';

@JsonSerializable()
class AccountInfo {
  const AccountInfo({
    required this.status,
    required this.trafficUsedBytes,
    required this.trafficLimitBytes,
    required this.deviceLimit,
    this.telegramUsername,
    this.expiresAt,
  });
  
  factory AccountInfo.fromJson(Map<String, Object?> json) => _$AccountInfoFromJson(json);
  
  final AccountStatus status;
  final String? telegramUsername;
  final DateTime? expiresAt;
  final int trafficUsedBytes;

  /// Zero means no limit.
  final int trafficLimitBytes;
  final int deviceLimit;

  Map<String, Object?> toJson() => _$AccountInfoToJson(this);
}
