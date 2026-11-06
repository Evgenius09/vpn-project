import 'package:flutter_riverpod/flutter_riverpod.dart';

// The settings drawn in the Figma design that the tunnel does not read yet.
// They live in memory so every screen works and shows its choice; wiring them
// into TunnelRequest comes with stage 3 (tech.md 16).

enum TunnelingMode { off, except, only }

enum RulesProfile { ruDirect, all, custom }

enum ThemeChoice { dark, light, system }

enum LanguageChoice { ru, en, system }

enum AddressOrder { v4First, v6First, v4Only, v6Only }

enum TunStack { gvisor, system, mixed }

enum PingMethod { tcp, urlTest }

enum AutoConnectChoice { last, best, random }

enum RuleMatch { suffix, exact, keyword, ip }

enum RuleAction { proxy, direct, block }

class CustomRule {
  const CustomRule(this.value, this.match, this.action);

  final String value;
  final RuleMatch match;
  final RuleAction action;
}

class ExcludedAddress {
  const ExcludedAddress(this.cidr, this.label);

  final String cidr;

  /// A built-in label key, or null for an address the user typed.
  final String? label;
}

class LocalSettings {
  const LocalSettings({
    this.connectOnOpen = false,
    this.tunneling = TunnelingMode.off,
    this.bypassApps = const {},
    this.rules = RulesProfile.ruDirect,
    this.theme = ThemeChoice.dark,
    this.language = LanguageChoice.system,
    this.routing = true,
    this.customRules = const [
      CustomRule('youtube.com', RuleMatch.suffix, RuleAction.proxy),
      CustomRule('sberbank.ru', RuleMatch.suffix, RuleAction.direct),
      CustomRule('doubleclick.net', RuleMatch.suffix, RuleAction.block),
    ],
    this.dnsRemote = 'https://1.1.1.1/dns-query',
    this.dnsDirect = '77.88.8.8',
    this.addressOrder = AddressOrder.v4First,
    this.ipv6 = false,
    this.sniffing = true,
    this.tlsFragment = false,
    this.bypassLan = true,
    this.mtu = '1500',
    this.tunStack = TunStack.gvisor,
    this.excluded = const [
      ExcludedAddress('192.168.0.0/16', 'home'),
      ExcludedAddress('10.0.0.0/8', 'work'),
    ],
    this.pingMethod = PingMethod.tcp,
    this.pingUrl = 'https://cp.cloudflare.com/generate_204',
    this.pingTimeoutSec = 3,
    this.pingOnOpen = true,
    this.autoConnect = AutoConnectChoice.best,
  });

  final bool connectOnOpen;
  final TunnelingMode tunneling;
  final Set<String> bypassApps;
  final RulesProfile rules;
  final ThemeChoice theme;
  final LanguageChoice language;
  final bool routing;
  final List<CustomRule> customRules;
  final String dnsRemote;
  final String dnsDirect;
  final AddressOrder addressOrder;
  final bool ipv6;
  final bool sniffing;
  final bool tlsFragment;
  final bool bypassLan;
  final String mtu;
  final TunStack tunStack;
  final List<ExcludedAddress> excluded;
  final PingMethod pingMethod;
  final String pingUrl;
  final int pingTimeoutSec;
  final bool pingOnOpen;
  final AutoConnectChoice autoConnect;

  LocalSettings copyWith({
    bool? connectOnOpen,
    TunnelingMode? tunneling,
    Set<String>? bypassApps,
    RulesProfile? rules,
    ThemeChoice? theme,
    LanguageChoice? language,
    bool? routing,
    List<CustomRule>? customRules,
    String? dnsRemote,
    String? dnsDirect,
    AddressOrder? addressOrder,
    bool? ipv6,
    bool? sniffing,
    bool? tlsFragment,
    bool? bypassLan,
    String? mtu,
    TunStack? tunStack,
    List<ExcludedAddress>? excluded,
    PingMethod? pingMethod,
    String? pingUrl,
    int? pingTimeoutSec,
    bool? pingOnOpen,
    AutoConnectChoice? autoConnect,
  }) => LocalSettings(
    connectOnOpen: connectOnOpen ?? this.connectOnOpen,
    tunneling: tunneling ?? this.tunneling,
    bypassApps: bypassApps ?? this.bypassApps,
    rules: rules ?? this.rules,
    theme: theme ?? this.theme,
    language: language ?? this.language,
    routing: routing ?? this.routing,
    customRules: customRules ?? this.customRules,
    dnsRemote: dnsRemote ?? this.dnsRemote,
    dnsDirect: dnsDirect ?? this.dnsDirect,
    addressOrder: addressOrder ?? this.addressOrder,
    ipv6: ipv6 ?? this.ipv6,
    sniffing: sniffing ?? this.sniffing,
    tlsFragment: tlsFragment ?? this.tlsFragment,
    bypassLan: bypassLan ?? this.bypassLan,
    mtu: mtu ?? this.mtu,
    tunStack: tunStack ?? this.tunStack,
    excluded: excluded ?? this.excluded,
    pingMethod: pingMethod ?? this.pingMethod,
    pingUrl: pingUrl ?? this.pingUrl,
    pingTimeoutSec: pingTimeoutSec ?? this.pingTimeoutSec,
    pingOnOpen: pingOnOpen ?? this.pingOnOpen,
    autoConnect: autoConnect ?? this.autoConnect,
  );
}

class LocalSettingsNotifier extends Notifier<LocalSettings> {
  @override
  LocalSettings build() => const LocalSettings();

  void update(LocalSettings Function(LocalSettings current) change) =>
      state = change(state);

  void toggleApp(String id) {
    final apps = {...state.bypassApps};
    if (!apps.remove(id)) {
      apps.add(id);
    }
    state = state.copyWith(bypassApps: apps);
  }
}

final localSettingsProvider =
    NotifierProvider<LocalSettingsNotifier, LocalSettings>(
      LocalSettingsNotifier.new,
    );
