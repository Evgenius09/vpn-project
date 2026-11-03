import '../../../gen/api/export.dart';

/// Values for keys the policy leaves out (tech.md 27.2). They match
/// backend/config/policy.yaml, so a profile without defaults behaves like the
/// shipped policy.
const builtInSettings = TunnelSettings(
  routing: RoutingSettings(
    enabled: true,
    preset: RoutingPreset.ruDirect,
    rules: [],
    ruleSets: [],
  ),
  dns: DnsSettings(
    remote: 'https://1.1.1.1/dns-query',
    direct: 'https://77.88.8.8/dns-query',
    strategy: DnsStrategy.preferIpv4,
  ),
  net: NetSettings(
    ipv6: false,
    sniffing: true,
    tlsFragment: TlsFragment(enabled: false, record: false),
    mtu: 1500,
    tunStack: TunStack.mixed,
    excludeRoutes: [],
    bypassLan: true,
  ),
  perApp: PerAppSettings(mode: PerAppMode.off, apps: []),
);

const builtInAutoOnCellular = true;

/// The tunnel settings of [patch] over the built-in values. S3-01 adds the
/// user's own values and `locked` on top.
TunnelSettings tunnelSettingsFrom(SettingsPatch patch) {
  const base = builtInSettings;
  final routing = patch.routing;
  final dns = patch.dns;
  final net = patch.net;
  final perApp = patch.perApp;
  return TunnelSettings(
    routing: RoutingSettings(
      enabled: routing?.enabled ?? base.routing.enabled,
      preset: routing?.preset ?? base.routing.preset,
      rules: routing?.rules ?? base.routing.rules,
      // The app downloads rule sets in S3-02.
      ruleSets: base.routing.ruleSets,
    ),
    dns: DnsSettings(
      remote: dns?.remote ?? base.dns.remote,
      direct: dns?.direct ?? base.dns.direct,
      strategy: dns?.strategy ?? base.dns.strategy,
    ),
    net: NetSettings(
      ipv6: net?.ipv6 ?? base.net.ipv6,
      sniffing: net?.sniffing ?? base.net.sniffing,
      tlsFragment: net?.tlsFragment ?? base.net.tlsFragment,
      mtu: net?.mtu ?? base.net.mtu,
      tunStack: net?.tunStack ?? base.net.tunStack,
      excludeRoutes: net?.excludeRoutes ?? base.net.excludeRoutes,
      bypassLan: net?.bypassLan ?? base.net.bypassLan,
    ),
    perApp: PerAppSettings(
      mode: perApp?.mode ?? base.perApp.mode,
      apps: perApp?.apps ?? base.perApp.apps,
    ),
  );
}

/// Whether [mode] has a server to start with. The core rejects a request
/// without one, so the app explains it instead of calling start.
bool hasServersIn(ProfileV1 profile, TunnelMode mode) =>
    profile.servers.any((server) => server.group == mode);

/// The request a tap on the PowerButton sends (tech.md 5.4, 27.2). It carries
/// the servers of both groups, so setUserMode switches without a restart.
TunnelRequest buildTunnelRequest({
  required Platform platform,
  required TunnelMode userMode,
  required ProfileV1 profile,
}) {
  final policy = profile.policy;
  final autoOnCellular =
      policy.defaults.whitelist?.autoOnCellular ?? builtInAutoOnCellular;
  return TunnelRequest(
    schemaVersion: 1,
    platform: platform,
    userMode: userMode,
    // S1-09 fills the selection; until then the core takes the first server
    // of each group by sortWeight (C3).
    selected: const SelectedServers(),
    servers: profile.servers,
    autoSwitch: AutoSwitchRequest(
      enabled: policy.flags.autoWhitelist && autoOnCellular,
    ),
    settings: tunnelSettingsFrom(policy.defaults),
    log: const TunnelLog(level: LogLevel.warn),
  );
}
