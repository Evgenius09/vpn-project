// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorPayload _$ErrorPayloadFromJson(Map<String, dynamic> json) => ErrorPayload(
  code: $enumDecode(_$CoreErrorCodeEnumMap, json['code']),
  message: json['message'] as String,
);

Map<String, dynamic> _$ErrorPayloadToJson(ErrorPayload instance) =>
    <String, dynamic>{
      'code': instance.code.toJson(),
      'message': instance.message,
    };

const _$CoreErrorCodeEnumMap = {
  CoreErrorCode.configInvalid: 'config_invalid',
  CoreErrorCode.startFailed: 'start_failed',
  CoreErrorCode.noServersInGroup: 'no_servers_in_group',
  CoreErrorCode.permissionDenied: 'permission_denied',
  CoreErrorCode.tunFailed: 'tun_failed',
  CoreErrorCode.revoked: 'revoked',
  CoreErrorCode.serviceUnavailable: 'service_unavailable',
  CoreErrorCode.ipcVersionMismatch: 'ipc_version_mismatch',
  CoreErrorCode.internal: 'internal',
};
