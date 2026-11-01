// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'utls_fingerprint.dart';
import 'vless_reality_params_flow.dart';

part 'vless_reality_params.g.dart';

@JsonSerializable()
class VlessRealityParams {
  const VlessRealityParams({
    required this.uuid,
    required this.flow,
    required this.serverName,
    required this.publicKey,
    required this.shortId,
    required this.fingerprint,
  });

  factory VlessRealityParams.fromJson(Map<String, Object?> json) =>
      _$VlessRealityParamsFromJson(json);

  /// Secret.
  final String uuid;
  final VlessRealityParamsFlow flow;
  final String serverName;
  final String publicKey;
  final String shortId;
  final UtlsFingerprint fingerprint;

  Map<String, Object?> toJson() => _$VlessRealityParamsToJson(this);
}
