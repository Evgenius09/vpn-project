// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'auto_switch_request.dart';
import 'platform.dart';
import 'selected_servers.dart';
import 'server_node.dart';
import 'tunnel_log.dart';
import 'tunnel_mode.dart';
import 'tunnel_settings.dart';

part 'tunnel_request.g.dart';

@JsonSerializable()
class TunnelRequest {
  const TunnelRequest({
    required this.schemaVersion,
    required this.platform,
    required this.userMode,
    required this.selected,
    required this.servers,
    required this.autoSwitch,
    required this.settings,
    required this.log,
  });

  factory TunnelRequest.fromJson(Map<String, Object?> json) =>
      _$TunnelRequestFromJson(json);

  final int schemaVersion;
  final Platform platform;
  final TunnelMode userMode;
  final SelectedServers selected;
  final List<ServerNode> servers;
  final AutoSwitchRequest autoSwitch;
  final TunnelSettings settings;
  final TunnelLog log;

  Map<String, Object?> toJson() => _$TunnelRequestToJson(this);
}
