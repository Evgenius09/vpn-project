// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vless_reality_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VlessRealityParams _$VlessRealityParamsFromJson(Map<String, dynamic> json) =>
    VlessRealityParams(
      uuid: json['uuid'] as String,
      flow: $enumDecode(_$VlessRealityParamsFlowEnumMap, json['flow']),
      serverName: json['serverName'] as String,
      publicKey: json['publicKey'] as String,
      shortId: json['shortId'] as String,
      fingerprint: $enumDecode(_$UtlsFingerprintEnumMap, json['fingerprint']),
    );

Map<String, dynamic> _$VlessRealityParamsToJson(VlessRealityParams instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'flow': instance.flow.toJson(),
      'serverName': instance.serverName,
      'publicKey': instance.publicKey,
      'shortId': instance.shortId,
      'fingerprint': instance.fingerprint.toJson(),
    };

const _$VlessRealityParamsFlowEnumMap = {
  VlessRealityParamsFlow.vision: 'xtls-rprx-vision',
  VlessRealityParamsFlow.none: '',
};

const _$UtlsFingerprintEnumMap = {
  UtlsFingerprint.chrome: 'chrome',
  UtlsFingerprint.firefox: 'firefox',
  UtlsFingerprint.safari: 'safari',
  UtlsFingerprint.ios: 'ios',
  UtlsFingerprint.android: 'android',
  UtlsFingerprint.edge: 'edge',
  UtlsFingerprint.random: 'random',
};
