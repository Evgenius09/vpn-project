// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_update.dart';
import 'min_app_version.dart';
import 'policy_flags.dart';
import 'policy_ping.dart';
import 'rule_set_ref.dart';
import 'settings_key.dart';
import 'settings_patch.dart';

part 'client_policy.g.dart';

@JsonSerializable()
class ClientPolicy {
  const ClientPolicy({
    required this.defaults,
    required this.locked,
    required this.flags,
    required this.ping,
    required this.ruleSets,
    required this.minAppVersion,
    this.appUpdate,
  });
  
  factory ClientPolicy.fromJson(Map<String, Object?> json) => _$ClientPolicyFromJson(json);
  
  final SettingsPatch defaults;
  final List<SettingsKey> locked;
  final PolicyFlags flags;
  final PolicyPing ping;
  final List<RuleSetRef> ruleSets;
  final MinAppVersion minAppVersion;
  final AppUpdate? appUpdate;

  Map<String, Object?> toJson() => _$ClientPolicyToJson(this);
}
