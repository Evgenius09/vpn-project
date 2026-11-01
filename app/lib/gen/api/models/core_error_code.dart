// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum CoreErrorCode {
  @JsonValue('config_invalid')
  configInvalid('config_invalid'),
  @JsonValue('start_failed')
  startFailed('start_failed'),
  @JsonValue('no_servers_in_group')
  noServersInGroup('no_servers_in_group'),
  @JsonValue('permission_denied')
  permissionDenied('permission_denied'),
  @JsonValue('tun_failed')
  tunFailed('tun_failed'),
  @JsonValue('revoked')
  revoked('revoked'),
  @JsonValue('service_unavailable')
  serviceUnavailable('service_unavailable'),
  @JsonValue('ipc_version_mismatch')
  ipcVersionMismatch('ipc_version_mismatch'),
  @JsonValue('internal')
  internal('internal');

  const CoreErrorCode(this.json);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to String. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
}
