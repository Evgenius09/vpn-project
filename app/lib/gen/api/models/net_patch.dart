// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'tls_fragment.dart';
import 'tun_stack.dart';

part 'net_patch.g.dart';

@JsonSerializable()
class NetPatch {
  const NetPatch({
    this.ipv6,
    this.sniffing,
    this.tlsFragment,
    this.mtu,
    this.tunStack,
    this.excludeRoutes,
    this.bypassLan,
  });

  factory NetPatch.fromJson(Map<String, Object?> json) =>
      _$NetPatchFromJson(json);

  final bool? ipv6;
  final bool? sniffing;
  final TlsFragment? tlsFragment;
  final int? mtu;
  final TunStack? tunStack;
  final List<String>? excludeRoutes;
  final bool? bypassLan;

  Map<String, Object?> toJson() => _$NetPatchToJson(this);
}
