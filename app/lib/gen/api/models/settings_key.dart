// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum SettingsKey {
  @JsonValue('routing.enabled')
  routingEnabled('routing.enabled'),
  @JsonValue('routing.preset')
  routingPreset('routing.preset'),
  @JsonValue('routing.rules')
  routingRules('routing.rules'),
  @JsonValue('dns.remote')
  dnsRemote('dns.remote'),
  @JsonValue('dns.direct')
  dnsDirect('dns.direct'),
  @JsonValue('dns.strategy')
  dnsStrategy('dns.strategy'),
  @JsonValue('net.ipv6')
  netIpv6('net.ipv6'),
  @JsonValue('net.sniffing')
  netSniffing('net.sniffing'),
  @JsonValue('net.tlsFragment')
  netTlsFragment('net.tlsFragment'),
  @JsonValue('net.mtu')
  netMtu('net.mtu'),
  @JsonValue('net.tunStack')
  netTunStack('net.tunStack'),
  @JsonValue('net.excludeRoutes')
  netExcludeRoutes('net.excludeRoutes'),
  @JsonValue('net.bypassLan')
  netBypassLan('net.bypassLan'),
  @JsonValue('perApp.mode')
  perAppMode('perApp.mode'),
  @JsonValue('perApp.apps')
  perAppApps('perApp.apps'),
  @JsonValue('ping.type')
  pingType('ping.type'),
  @JsonValue('ping.url')
  pingUrl('ping.url'),
  @JsonValue('ping.timeoutMs')
  pingTimeoutMs('ping.timeoutMs'),
  @JsonValue('ping.onOpen')
  pingOnOpen('ping.onOpen'),
  @JsonValue('connect.autoConnect')
  connectAutoConnect('connect.autoConnect'),
  @JsonValue('connect.autoConnectStrategy')
  connectAutoConnectStrategy('connect.autoConnectStrategy'),
  @JsonValue('connect.autostart')
  connectAutostart('connect.autostart'),
  @JsonValue('ui.sortByPing')
  uiSortByPing('ui.sortByPing'),
  @JsonValue('ui.locale')
  uiLocale('ui.locale'),
  @JsonValue('ui.theme')
  uiTheme('ui.theme'),
  @JsonValue('whitelist.autoOnCellular')
  whitelistAutoOnCellular('whitelist.autoOnCellular');

  const SettingsKey(this.json);

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
