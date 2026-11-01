// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connect_patch.dart';
import 'dns_patch.dart';
import 'net_patch.dart';
import 'per_app_patch.dart';
import 'ping_patch.dart';
import 'routing_patch.dart';
import 'ui_patch.dart';
import 'whitelist_patch.dart';

part 'settings_patch.g.dart';

@JsonSerializable()
class SettingsPatch {
  const SettingsPatch({
    this.routing,
    this.dns,
    this.net,
    this.perApp,
    this.ping,
    this.connect,
    this.ui,
    this.whitelist,
  });

  factory SettingsPatch.fromJson(Map<String, Object?> json) =>
      _$SettingsPatchFromJson(json);

  final RoutingPatch? routing;
  final DnsPatch? dns;
  final NetPatch? net;
  final PerAppPatch? perApp;
  final PingPatch? ping;
  final ConnectPatch? connect;
  final UiPatch? ui;
  final WhitelistPatch? whitelist;

  Map<String, Object?> toJson() => _$SettingsPatchToJson(this);
}
