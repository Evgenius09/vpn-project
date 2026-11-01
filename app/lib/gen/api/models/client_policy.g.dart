// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientPolicy _$ClientPolicyFromJson(Map<String, dynamic> json) => ClientPolicy(
  defaults: SettingsPatch.fromJson(json['defaults'] as Map<String, dynamic>),
  locked: (json['locked'] as List<dynamic>)
      .map((e) => $enumDecode(_$SettingsKeyEnumMap, e))
      .toList(),
  flags: PolicyFlags.fromJson(json['flags'] as Map<String, dynamic>),
  ping: PolicyPing.fromJson(json['ping'] as Map<String, dynamic>),
  ruleSets: (json['ruleSets'] as List<dynamic>)
      .map((e) => RuleSetRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  minAppVersion: MinAppVersion.fromJson(
    json['minAppVersion'] as Map<String, dynamic>,
  ),
  appUpdate: json['appUpdate'] == null
      ? null
      : AppUpdate.fromJson(json['appUpdate'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ClientPolicyToJson(ClientPolicy instance) =>
    <String, dynamic>{
      'defaults': instance.defaults.toJson(),
      'locked': instance.locked.map((e) => e.toJson()).toList(),
      'flags': instance.flags.toJson(),
      'ping': instance.ping.toJson(),
      'ruleSets': instance.ruleSets.map((e) => e.toJson()).toList(),
      'minAppVersion': instance.minAppVersion.toJson(),
      'appUpdate': ?instance.appUpdate?.toJson(),
    };

const _$SettingsKeyEnumMap = {
  SettingsKey.routingEnabled: 'routing.enabled',
  SettingsKey.routingPreset: 'routing.preset',
  SettingsKey.routingRules: 'routing.rules',
  SettingsKey.dnsRemote: 'dns.remote',
  SettingsKey.dnsDirect: 'dns.direct',
  SettingsKey.dnsStrategy: 'dns.strategy',
  SettingsKey.netIpv6: 'net.ipv6',
  SettingsKey.netSniffing: 'net.sniffing',
  SettingsKey.netTlsFragment: 'net.tlsFragment',
  SettingsKey.netMtu: 'net.mtu',
  SettingsKey.netTunStack: 'net.tunStack',
  SettingsKey.netExcludeRoutes: 'net.excludeRoutes',
  SettingsKey.netBypassLan: 'net.bypassLan',
  SettingsKey.perAppMode: 'perApp.mode',
  SettingsKey.perAppApps: 'perApp.apps',
  SettingsKey.pingType: 'ping.type',
  SettingsKey.pingUrl: 'ping.url',
  SettingsKey.pingTimeoutMs: 'ping.timeoutMs',
  SettingsKey.pingOnOpen: 'ping.onOpen',
  SettingsKey.connectAutoConnect: 'connect.autoConnect',
  SettingsKey.connectAutoConnectStrategy: 'connect.autoConnectStrategy',
  SettingsKey.connectAutostart: 'connect.autostart',
  SettingsKey.uiSortByPing: 'ui.sortByPing',
  SettingsKey.uiLocale: 'ui.locale',
  SettingsKey.uiTheme: 'ui.theme',
  SettingsKey.whitelistAutoOnCellular: 'whitelist.autoOnCellular',
};
