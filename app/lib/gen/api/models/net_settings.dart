// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'tls_fragment.dart';
import 'tun_stack.dart';

part 'net_settings.g.dart';

@JsonSerializable()
class NetSettings {
  const NetSettings({
    required this.ipv6,
    required this.sniffing,
    required this.tlsFragment,
    required this.mtu,
    required this.tunStack,
    required this.excludeRoutes,
    required this.bypassLan,
  });

  factory NetSettings.fromJson(Map<String, Object?> json) =>
      _$NetSettingsFromJson(json);

  final bool ipv6;
  final bool sniffing;
  final TlsFragment tlsFragment;
  final int mtu;
  final TunStack tunStack;
  final List<String> excludeRoutes;
  final bool bypassLan;

  Map<String, Object?> toJson() => _$NetSettingsToJson(this);
}
