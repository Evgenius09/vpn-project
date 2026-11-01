// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ModeSwitchReason {
  @JsonValue('user')
  user('user'),
  @JsonValue('network_cellular')
  networkCellular('network_cellular'),
  @JsonValue('network_wifi')
  networkWifi('network_wifi'),
  @JsonValue('override_cleared')
  overrideCleared('override_cleared'),
  @JsonValue('no_whitelist_servers')
  noWhitelistServers('no_whitelist_servers');

  const ModeSwitchReason(this.json);

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
