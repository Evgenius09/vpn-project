import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/vpn/vpn_bridge.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../auth/application/login_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../application/local_settings.dart';

/// The pages under /settings, named as in the Figma file (tech.md 43).
abstract final class SettingsPages {
  static const tunneling = 'tunneling';
  static const rules = 'rules';
  static const theme = 'theme';
  static const language = 'language';
  static const support = 'support';
  static const advanced = 'advanced';

  static const customRules = 'custom-rules';
  static const newRule = 'new-rule';
  static const dnsRemote = 'dns-remote';
  static const dnsDirect = 'dns-direct';
  static const addressOrder = 'address-order';
  static const mtu = 'mtu';
  static const tunMode = 'tun-mode';
  static const excluded = 'excluded';
  static const pingMethod = 'ping-method';
  static const pingUrl = 'ping-url';
  static const pingTimeout = 'ping-timeout';
  static const autoConnect = 'auto-connect';

  static String path(String page) => '/settings/$page';

  static String advancedPath(String item) => '/settings/$advanced/$item';
}

/// Builds /settings/:section and /settings/:section/:item from the route.
class SettingsPageScreen extends StatelessWidget {
  const SettingsPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).pathParameters;
    final page = params['item'] ?? params['section'] ?? '';
    return switch (page) {
      SettingsPages.tunneling => const _TunnelingScreen(),
      SettingsPages.rules => const _RulesScreen(),
      SettingsPages.theme => const _ThemeScreen(),
      SettingsPages.language => const _LanguageScreen(),
      SettingsPages.support => const _SupportScreen(),
      SettingsPages.advanced => const _AdvancedScreen(),
      SettingsPages.customRules => const _CustomRulesScreen(),
      SettingsPages.newRule => const _NewRuleScreen(),
      SettingsPages.dnsRemote => const _DnsRemoteScreen(),
      SettingsPages.dnsDirect => const _DnsDirectScreen(),
      SettingsPages.addressOrder => const _AddressOrderScreen(),
      SettingsPages.mtu => const _MtuScreen(),
      SettingsPages.tunMode => const _TunModeScreen(),
      SettingsPages.excluded => const _ExcludedScreen(),
      SettingsPages.pingMethod => const _PingMethodScreen(),
      SettingsPages.pingUrl => const _PingUrlScreen(),
      SettingsPages.pingTimeout => const _PingTimeoutScreen(),
      SettingsPages.autoConnect => const _AutoConnectScreen(),
      _ => AppScreen(
        title: AppLocalizations.of(context).settingsTitle,
        children: [
          EmptyState(
            icon: Icons.construction_outlined,
            title: AppLocalizations.of(context).emptyScreenTitle,
          ),
        ],
      ),
    };
  }
}

// ---------------------------------------------------------------- labels

/// The short names the settings rows show under their titles.
abstract final class SettingsLabels {
  static String tunneling(AppLocalizations s, TunnelingMode mode) =>
      switch (mode) {
        TunnelingMode.off => s.tunOff,
        TunnelingMode.except => s.tunExcept,
        TunnelingMode.only => s.tunOnly,
      };

  static String rules(AppLocalizations s, RulesProfile profile) =>
      switch (profile) {
        RulesProfile.ruDirect => s.rulesRuDirectShort,
        RulesProfile.all => s.rulesAll,
        RulesProfile.custom => s.rulesCustom,
      };

  static String theme(AppLocalizations s, ThemeChoice theme) => switch (theme) {
    ThemeChoice.dark => s.themeDarkName,
    ThemeChoice.light => s.themeLightName,
    ThemeChoice.system => s.themeSystemName,
  };

  static String language(
    AppLocalizations s,
    LanguageChoice language,
    Locale shown,
  ) => switch (language) {
    LanguageChoice.ru => s.langRu,
    LanguageChoice.en => s.langEn,
    // "As in the system" names the language the phone gave the app.
    LanguageChoice.system => shown.languageCode == 'ru' ? s.langRu : s.langEn,
  };

  static String addressOrder(AppLocalizations s, AddressOrder order) =>
      switch (order) {
        AddressOrder.v4First => s.addrV4First,
        AddressOrder.v6First => s.addrV6First,
        AddressOrder.v4Only => s.addrV4Only,
        AddressOrder.v6Only => s.addrV6Only,
      };

  static String tunStack(TunStack stack) => switch (stack) {
    TunStack.gvisor => 'gVisor',
    TunStack.system => 'System',
    TunStack.mixed => 'Mixed',
  };

  static String pingMethod(AppLocalizations s, PingMethod method) =>
      switch (method) {
        PingMethod.tcp => 'TCP',
        PingMethod.urlTest => s.pingUrlTest,
      };

  static String timeout(AppLocalizations s, int seconds) => switch (seconds) {
    1 => s.timeout1,
    5 => s.timeout5,
    _ => s.timeout3,
  };

  static String autoConnect(AppLocalizations s, AutoConnectChoice choice) =>
      switch (choice) {
        AutoConnectChoice.last => s.autoLast,
        AutoConnectChoice.best => s.autoBest,
        AutoConnectChoice.random => s.autoRandom,
      };

  static String action(AppLocalizations s, RuleAction action) =>
      switch (action) {
        RuleAction.proxy => s.nrActionProxyShort,
        RuleAction.direct => s.nrActionDirectShort,
        RuleAction.block => s.nrActionBlockShort,
      };

  static String match(AppLocalizations s, RuleMatch match) => switch (match) {
    RuleMatch.suffix => s.nrSuffix,
    RuleMatch.exact => s.nrExact,
    RuleMatch.keyword => s.nrKeyword,
    RuleMatch.ip => s.nrIp,
  };

  /// A DNS address with the name of a known resolver, as in the design.
  static String dnsDirect(AppLocalizations s, String address) =>
      address == '77.88.8.8' ? '$address · ${s.dnsYandex}' : address;

  static String excluded(AppLocalizations s, List<ExcludedAddress> list) =>
      list.isEmpty
      ? s.advExcludedNone
      : list.map((address) => address.cidr).join(', ');

  static String? excludedLabel(AppLocalizations s, ExcludedAddress address) =>
      switch (address.label) {
        'home' => s.exHome,
        'work' => s.exWork,
        _ => null,
      };
}

// ------------------------------------------------------- shared templates

typedef _Choice<T> = ({T value, String title, String? subtitle});

/// A single-choice page: one section of answers, the chosen one checked.
class _ChoiceScreen<T> extends ConsumerWidget {
  const _ChoiceScreen({
    required this.title,
    required this.section,
    required this.choices,
    required this.read,
    required this.write,
  });

  final String title;
  final String section;
  final List<_Choice<T>> choices;
  final T Function(LocalSettings settings) read;
  final LocalSettings Function(LocalSettings settings, T value) write;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = read(ref.watch(localSettingsProvider));
    return AppScreen(
      title: title,
      children: [
        SettingsSection(
          title: section,
          children: [
            for (final choice in choices)
              SettingsChoiceTile(
                title: choice.title,
                subtitle: choice.subtitle,
                selected: choice.value == current,
                onTap: () => ref
                    .read(localSettingsProvider.notifier)
                    .update((settings) => write(settings, choice.value)),
              ),
          ],
        ),
      ],
    );
  }
}

/// A free-form value with quick picks under it and a Save button.
class _InputScreen extends ConsumerStatefulWidget {
  const _InputScreen({
    required this.title,
    required this.field,
    required this.note,
    required this.choices,
    required this.read,
    required this.write,
    this.keyboardType,
  });

  final String title;
  final String field;
  final String note;
  final List<_Choice<String>> choices;
  final String Function(LocalSettings settings) read;
  final LocalSettings Function(LocalSettings settings, String value) write;
  final TextInputType? keyboardType;

  @override
  ConsumerState<_InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<_InputScreen> {
  late final _controller = TextEditingController(
    text: widget.read(ref.read(localSettingsProvider)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    return AppScreen(
      title: widget.title,
      children: [
        AppTextField(
          controller: _controller,
          label: widget.field,
          keyboardType: widget.keyboardType,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Text(
            widget.note,
            style: AppText.caption.copyWith(color: colors.textMuted),
          ),
        ),
        SettingsSection(
          title: strings.inputQuick,
          children: [
            for (final choice in widget.choices)
              SettingsChoiceTile(
                title: choice.title,
                subtitle: choice.subtitle,
                selected: _controller.text.trim() == choice.value,
                onTap: () => setState(() => _controller.text = choice.value),
              ),
          ],
        ),
        AppButton(
          label: strings.save,
          onPressed: () {
            ref
                .read(localSettingsProvider.notifier)
                .update(
                  (settings) => widget.write(settings, _controller.text.trim()),
                );
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ level 1

class _TunnelingScreen extends ConsumerStatefulWidget {
  const _TunnelingScreen();

  @override
  ConsumerState<_TunnelingScreen> createState() => _TunnelingScreenState();
}

class _TunnelingScreenState extends ConsumerState<_TunnelingScreen> {
  final _search = TextEditingController();
  late final Future<List<SelectableApp>> _apps = ref
      .read(vpnBridgeProvider)
      .listSelectableApps()
      .catchError((Object _) => <SelectableApp>[]);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    final settings = ref.watch(localSettingsProvider);
    final notifier = ref.read(localSettingsProvider.notifier);
    final modes = [
      (TunnelingMode.off, strings.tunOff, strings.tunOffHint),
      (TunnelingMode.except, strings.tunExcept, strings.tunExceptHint),
      (TunnelingMode.only, strings.tunOnly, strings.tunOnlyHint),
    ];
    return AppScreen(
      title: strings.tunTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Text(
            strings.tunIntro,
            style: AppText.caption.copyWith(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
        ),
        SettingsSection(
          title: strings.tunSectionMode,
          children: [
            for (final (mode, title, hint) in modes)
              SettingsChoiceTile(
                title: title,
                subtitle: hint,
                selected: settings.tunneling == mode,
                onTap: () =>
                    notifier.update((s) => s.copyWith(tunneling: mode)),
              ),
          ],
        ),
        AnimatedSize(
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          alignment: Alignment.topCenter,
          child: settings.tunneling == TunnelingMode.off
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        (settings.tunneling == TunnelingMode.except
                                ? strings.tunAppsBypass
                                : strings.tunAppsThrough)
                            .toUpperCase(),
                        style: AppText.overline.copyWith(
                          letterSpacing: 0,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    AppTextField(
                      controller: _search,
                      hint: strings.tunSearch,
                      icon: Icons.search_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FutureBuilder<List<SelectableApp>>(
                      future: _apps,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: AppSpacing.xxxl * 2,
                            child: LoadingView(),
                          );
                        }
                        final query = _search.text.trim().toLowerCase();
                        final apps = [
                          for (final app in snapshot.data!)
                            if (query.isEmpty ||
                                app.label.toLowerCase().contains(query) ||
                                app.id.toLowerCase().contains(query))
                              app,
                        ];
                        if (apps.isEmpty) {
                          return EmptyState(
                            icon: Icons.apps_outlined,
                            title: strings.tunNoApps,
                          );
                        }
                        return SettingsSection(
                          title: '',
                          children: [
                            for (final app in apps)
                              SettingsToggleTile(
                                title: app.label,
                                subtitle: app.id,
                                value: settings.bypassApps.contains(app.id),
                                onChanged: (_) => notifier.toggleApp(app.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RulesScreen extends StatelessWidget {
  const _RulesScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<RulesProfile>(
      title: s.rulesTitle,
      section: s.rulesSection,
      choices: [
        (
          value: RulesProfile.ruDirect,
          title: s.rulesRuDirect,
          subtitle: s.rulesRuDirectHint,
        ),
        (value: RulesProfile.all, title: s.rulesAll, subtitle: s.rulesAllHint),
        (
          value: RulesProfile.custom,
          title: s.rulesCustom,
          subtitle: s.rulesCustomHint,
        ),
      ],
      read: (settings) => settings.rules,
      write: (settings, value) => settings.copyWith(rules: value),
    );
  }
}

class _ThemeScreen extends StatelessWidget {
  const _ThemeScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<ThemeChoice>(
      title: s.setTheme,
      section: s.themeSection,
      choices: [
        (
          value: ThemeChoice.dark,
          title: s.themeDarkName,
          subtitle: s.themeDarkHint,
        ),
        (
          value: ThemeChoice.light,
          title: s.themeLightName,
          subtitle: s.themeLightHint,
        ),
        (
          value: ThemeChoice.system,
          title: s.themeSystemName,
          subtitle: s.themeSystemHint,
        ),
      ],
      read: (settings) => settings.theme,
      write: (settings, value) => settings.copyWith(theme: value),
    );
  }
}

class _LanguageScreen extends StatelessWidget {
  const _LanguageScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<LanguageChoice>(
      title: s.setLanguage,
      section: s.langSection,
      choices: [
        (value: LanguageChoice.ru, title: s.langRu, subtitle: s.langRuHint),
        (value: LanguageChoice.en, title: s.langEn, subtitle: s.langEnHint),
        (
          value: LanguageChoice.system,
          title: s.langSystem,
          subtitle: s.langSystemHint,
        ),
      ],
      read: (settings) => settings.language,
      write: (settings, value) => settings.copyWith(language: value),
    );
  }
}

class _SupportScreen extends ConsumerWidget {
  const _SupportScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider);
    final endpoints = profile is ProfileReady
        ? profile.profile.endpoints
        : null;
    VoidCallback? open(String? url) {
      final uri = url == null ? null : Uri.tryParse(url);
      return uri == null ? null : () => ref.read(urlOpenerProvider)(uri);
    }

    return AppScreen(
      title: s.setSupport,
      children: [
        SettingsSection(
          title: s.supSectionContact,
          children: [
            SettingsNavTile(
              title: s.supWrite,
              value: s.supWriteHint,
              onTap: open(endpoints?.support ?? endpoints?.bot),
            ),
            SettingsNavTile(
              title: s.supBot,
              value: s.supBotHint,
              onTap: open(endpoints?.bot),
            ),
          ],
        ),
        SettingsSection(
          title: s.supSectionAbout,
          footer: s.supFooter,
          children: [
            SettingsNavTile(
              title: s.supSite,
              value: s.supSiteHint,
              onTap: open(endpoints?.web),
            ),
            SettingsNavTile(
              title: s.supVersion,
              value: s.supVersionValue(appVersion),
              onTap: null,
              trailing: const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdvancedScreen extends ConsumerWidget {
  const _AdvancedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final settings = ref.watch(localSettingsProvider);
    final notifier = ref.read(localSettingsProvider.notifier);
    void go(String item) => context.push(SettingsPages.advancedPath(item));
    void set(LocalSettings Function(LocalSettings) change) =>
        notifier.update(change);
    return AppScreen(
      title: s.setAdvanced,
      children: [
        SettingsSection(
          title: s.advSectionRouting,
          children: [
            SettingsToggleTile(
              title: s.advRouting,
              subtitle: s.advRoutingHint,
              value: settings.routing,
              onChanged: (value) => set((x) => x.copyWith(routing: value)),
            ),
            SettingsNavTile(
              title: s.rulesTitle,
              value: SettingsLabels.rules(s, settings.rules),
              onTap: () =>
                  context.push(SettingsPages.path(SettingsPages.rules)),
            ),
            SettingsNavTile(
              title: s.advCustomRules,
              value: s.advCustomRulesHint(settings.customRules.length),
              onTap: () => go(SettingsPages.customRules),
            ),
          ],
        ),
        SettingsSection(
          title: s.advSectionDns,
          children: [
            SettingsNavTile(
              title: s.advDnsRemote,
              value: settings.dnsRemote,
              onTap: () => go(SettingsPages.dnsRemote),
            ),
            SettingsNavTile(
              title: s.advDnsDirect,
              value: SettingsLabels.dnsDirect(s, settings.dnsDirect),
              onTap: () => go(SettingsPages.dnsDirect),
            ),
            SettingsNavTile(
              title: s.advAddressOrder,
              value: SettingsLabels.addressOrder(s, settings.addressOrder),
              onTap: () => go(SettingsPages.addressOrder),
            ),
          ],
        ),
        SettingsSection(
          title: s.advSectionNetwork,
          children: [
            SettingsToggleTile(
              title: s.advIpv6,
              subtitle: s.advIpv6Hint,
              value: settings.ipv6,
              onChanged: (value) => set((x) => x.copyWith(ipv6: value)),
            ),
            SettingsToggleTile(
              title: s.advSniffing,
              subtitle: s.advSniffingHint,
              value: settings.sniffing,
              onChanged: (value) => set((x) => x.copyWith(sniffing: value)),
            ),
            SettingsToggleTile(
              title: s.advTlsFragment,
              subtitle: s.advTlsFragmentHint,
              value: settings.tlsFragment,
              onChanged: (value) => set((x) => x.copyWith(tlsFragment: value)),
            ),
            SettingsToggleTile(
              title: s.advBypassLan,
              subtitle: s.advBypassLanHint,
              value: settings.bypassLan,
              onChanged: (value) => set((x) => x.copyWith(bypassLan: value)),
            ),
            SettingsNavTile(
              title: s.advMtu,
              value: settings.mtu,
              onTap: () => go(SettingsPages.mtu),
            ),
            SettingsNavTile(
              title: s.advTunMode,
              value: SettingsLabels.tunStack(settings.tunStack),
              onTap: () => go(SettingsPages.tunMode),
            ),
            SettingsNavTile(
              title: s.advExcluded,
              value: SettingsLabels.excluded(s, settings.excluded),
              onTap: () => go(SettingsPages.excluded),
            ),
          ],
        ),
        SettingsSection(
          title: s.advSectionPing,
          children: [
            SettingsNavTile(
              title: s.advPingMethod,
              value: SettingsLabels.pingMethod(s, settings.pingMethod),
              onTap: () => go(SettingsPages.pingMethod),
            ),
            SettingsNavTile(
              title: s.advPingUrl,
              value: settings.pingUrl.replaceFirst('https://', ''),
              onTap: () => go(SettingsPages.pingUrl),
            ),
            SettingsNavTile(
              title: s.advPingTimeout,
              value: SettingsLabels.timeout(s, settings.pingTimeoutSec),
              onTap: () => go(SettingsPages.pingTimeout),
            ),
            SettingsToggleTile(
              title: s.advPingOnOpen,
              subtitle: s.advPingOnOpenHint,
              value: settings.pingOnOpen,
              onChanged: (value) => set((x) => x.copyWith(pingOnOpen: value)),
            ),
          ],
        ),
        SettingsSection(
          title: s.advSectionConnect,
          children: [
            SettingsNavTile(
              title: s.advAutoConnect,
              value: SettingsLabels.autoConnect(s, settings.autoConnect),
              onTap: () => go(SettingsPages.autoConnect),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ level 2

class _AddressOrderScreen extends StatelessWidget {
  const _AddressOrderScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<AddressOrder>(
      title: s.advAddressOrder,
      section: s.addrSection,
      choices: [
        (
          value: AddressOrder.v4First,
          title: s.addrV4First,
          subtitle: s.addrV4FirstHint,
        ),
        (
          value: AddressOrder.v6First,
          title: s.addrV6First,
          subtitle: s.addrV6FirstHint,
        ),
        (
          value: AddressOrder.v4Only,
          title: s.addrV4Only,
          subtitle: s.addrV4OnlyHint,
        ),
        (
          value: AddressOrder.v6Only,
          title: s.addrV6Only,
          subtitle: s.addrV6OnlyHint,
        ),
      ],
      read: (settings) => settings.addressOrder,
      write: (settings, value) => settings.copyWith(addressOrder: value),
    );
  }
}

class _TunModeScreen extends StatelessWidget {
  const _TunModeScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<TunStack>(
      title: s.advTunMode,
      section: s.tunModeSection,
      choices: [
        (value: TunStack.gvisor, title: 'gVisor', subtitle: s.tunGvisorHint),
        (value: TunStack.system, title: 'System', subtitle: s.tunSystemHint),
        (value: TunStack.mixed, title: 'Mixed', subtitle: s.tunMixedHint),
      ],
      read: (settings) => settings.tunStack,
      write: (settings, value) => settings.copyWith(tunStack: value),
    );
  }
}

class _PingMethodScreen extends StatelessWidget {
  const _PingMethodScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<PingMethod>(
      title: s.advPingMethod,
      section: s.pingMethodSection,
      choices: [
        (value: PingMethod.tcp, title: 'TCP', subtitle: s.pingTcpHint),
        (
          value: PingMethod.urlTest,
          title: s.pingUrlTest,
          subtitle: s.pingUrlTestHint,
        ),
      ],
      read: (settings) => settings.pingMethod,
      write: (settings, value) => settings.copyWith(pingMethod: value),
    );
  }
}

class _PingTimeoutScreen extends StatelessWidget {
  const _PingTimeoutScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<int>(
      title: s.advPingTimeout,
      section: s.timeoutSection,
      choices: [
        (value: 1, title: s.timeout1, subtitle: s.timeout1Hint),
        (value: 3, title: s.timeout3, subtitle: s.timeout3Hint),
        (value: 5, title: s.timeout5, subtitle: s.timeout5Hint),
      ],
      read: (settings) => settings.pingTimeoutSec,
      write: (settings, value) => settings.copyWith(pingTimeoutSec: value),
    );
  }
}

class _AutoConnectScreen extends StatelessWidget {
  const _AutoConnectScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _ChoiceScreen<AutoConnectChoice>(
      title: s.advAutoConnectTitle,
      section: s.autoSection,
      choices: [
        (
          value: AutoConnectChoice.last,
          title: s.autoLast,
          subtitle: s.autoLastHint,
        ),
        (
          value: AutoConnectChoice.best,
          title: s.autoBest,
          subtitle: s.autoBestHint,
        ),
        (
          value: AutoConnectChoice.random,
          title: s.autoRandom,
          subtitle: s.autoRandomHint,
        ),
      ],
      read: (settings) => settings.autoConnect,
      write: (settings, value) => settings.copyWith(autoConnect: value),
    );
  }
}

class _DnsRemoteScreen extends StatelessWidget {
  const _DnsRemoteScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _InputScreen(
      title: s.advDnsRemote,
      field: s.dnsAddress,
      note: s.dnsRemoteNote,
      keyboardType: TextInputType.url,
      choices: const [
        (
          value: 'https://1.1.1.1/dns-query',
          title: 'Cloudflare',
          subtitle: 'https://1.1.1.1/dns-query',
        ),
        (
          value: 'https://dns.google/dns-query',
          title: 'Google',
          subtitle: 'https://dns.google/dns-query',
        ),
        (
          value: 'https://dns.quad9.net/dns-query',
          title: 'Quad9',
          subtitle: 'https://dns.quad9.net/dns-query',
        ),
      ],
      read: (settings) => settings.dnsRemote,
      write: (settings, value) => settings.copyWith(dnsRemote: value),
    );
  }
}

class _DnsDirectScreen extends StatelessWidget {
  const _DnsDirectScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _InputScreen(
      title: s.advDnsDirect,
      field: s.dnsAddress,
      note: s.dnsDirectNote,
      keyboardType: TextInputType.url,
      choices: [
        (value: '77.88.8.8', title: s.dnsYandex, subtitle: '77.88.8.8'),
        (value: '1.1.1.1', title: 'Cloudflare', subtitle: '1.1.1.1'),
        (value: '8.8.8.8', title: 'Google', subtitle: '8.8.8.8'),
      ],
      read: (settings) => settings.dnsDirect,
      write: (settings, value) => settings.copyWith(dnsDirect: value),
    );
  }
}

class _MtuScreen extends StatelessWidget {
  const _MtuScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _InputScreen(
      title: s.advMtu,
      field: s.mtuSection,
      note: s.mtuNote,
      keyboardType: TextInputType.number,
      choices: [
        (value: '1500', title: '1500', subtitle: s.mtu1500Hint),
        (value: '1400', title: '1400', subtitle: s.mtu1400Hint),
        (value: '1280', title: '1280', subtitle: s.mtu1280Hint),
      ],
      read: (settings) => settings.mtu,
      write: (settings, value) => settings.copyWith(mtu: value),
    );
  }
}

class _PingUrlScreen extends StatelessWidget {
  const _PingUrlScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return _InputScreen(
      title: s.advPingUrl,
      field: s.pingUrlSection,
      note: s.pingUrlNote,
      keyboardType: TextInputType.url,
      choices: const [
        (
          value: 'https://cp.cloudflare.com/generate_204',
          title: 'Cloudflare',
          subtitle: 'cp.cloudflare.com/generate_204',
        ),
        (
          value: 'https://www.gstatic.com/generate_204',
          title: 'Google',
          subtitle: 'www.gstatic.com/generate_204',
        ),
        (
          value: 'https://captive.apple.com',
          title: 'Apple',
          subtitle: 'captive.apple.com',
        ),
      ],
      read: (settings) => settings.pingUrl,
      write: (settings, value) => settings.copyWith(pingUrl: value),
    );
  }
}

class _CustomRulesScreen extends ConsumerWidget {
  const _CustomRulesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final rules = ref.watch(localSettingsProvider).customRules;
    return AppScreen(
      title: s.advCustomRules,
      children: [
        SettingsSection(
          title: s.crSection,
          footer: s.crFooter,
          children: [
            for (final rule in rules)
              SettingsNavTile(
                title: rule.value,
                value: s.crRuleLine(
                  SettingsLabels.match(s, rule.match),
                  SettingsLabels.action(s, rule.action),
                ),
                onTap: () {},
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: s.crAdd,
          onPressed: () =>
              context.push(SettingsPages.advancedPath(SettingsPages.newRule)),
        ),
      ],
    );
  }
}

class _ExcludedScreen extends ConsumerStatefulWidget {
  const _ExcludedScreen();

  @override
  ConsumerState<_ExcludedScreen> createState() => _ExcludedScreenState();
}

class _ExcludedScreenState extends ConsumerState<_ExcludedScreen> {
  Future<void> _add() async {
    final s = AppLocalizations.of(context);
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.exSection),
        content: AppTextField(
          controller: controller,
          hint: '192.168.1.0/24',
          keyboardType: TextInputType.url,
        ),
        actions: [
          AppButton(
            label: s.cancel,
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: s.crAdd,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (added != null && added.isNotEmpty) {
      ref
          .read(localSettingsProvider.notifier)
          .update(
            (x) => x.copyWith(
              excluded: [...x.excluded, ExcludedAddress(added, null)],
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final colors = context.colors;
    final list = ref.watch(localSettingsProvider).excluded;
    return AppScreen(
      title: s.exTitle,
      children: [
        SettingsSection(
          title: s.exSection,
          footer: s.exFooter,
          children: [
            for (final address in list)
              SettingsNavTile(
                title: address.cidr,
                value: SettingsLabels.excludedLabel(s, address),
                onTap: null,
                trailing: IconButton(
                  tooltip: s.exRemove,
                  icon: Icon(
                    Icons.close_rounded,
                    size: AppSizes.iconSmall + 2,
                    color: colors.textMuted,
                  ),
                  onPressed: () => ref
                      .read(localSettingsProvider.notifier)
                      .update(
                        (x) => x.copyWith(
                          excluded: [
                            for (final other in x.excluded)
                              if (other != address) other,
                          ],
                        ),
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: s.crAdd, onPressed: _add),
      ],
    );
  }
}

class _NewRuleScreen extends ConsumerStatefulWidget {
  const _NewRuleScreen();

  @override
  ConsumerState<_NewRuleScreen> createState() => _NewRuleScreenState();
}

class _NewRuleScreenState extends ConsumerState<_NewRuleScreen> {
  final _address = TextEditingController(text: 'youtube.com');
  RuleMatch _match = RuleMatch.suffix;
  RuleAction _action = RuleAction.proxy;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final host = _address.text.trim().isEmpty
        ? 'youtube.com'
        : _address.text.trim();
    final word = host.split('.').first;
    final matches = [
      (RuleMatch.suffix, s.nrSuffix, s.nrSuffixHint(host)),
      (RuleMatch.exact, s.nrExact, s.nrExactHint(host)),
      (RuleMatch.keyword, s.nrKeyword, s.nrKeywordHint(word)),
      (RuleMatch.ip, s.nrIp, s.nrIpHint),
    ];
    final actions = [
      (RuleAction.proxy, s.nrProxy, s.nrProxyHint),
      (RuleAction.direct, s.nrDirect, s.nrDirectHint),
      (RuleAction.block, s.nrBlock, s.nrBlockHint),
    ];
    return AppScreen(
      title: s.nrTitle,
      children: [
        AppTextField(
          controller: _address,
          label: s.nrAddress,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        SettingsSection(
          title: s.nrMatchSection,
          children: [
            for (final (match, title, hint) in matches)
              SettingsChoiceTile(
                title: title,
                subtitle: hint,
                selected: _match == match,
                onTap: () => setState(() => _match = match),
              ),
          ],
        ),
        SettingsSection(
          title: s.nrActionSection,
          children: [
            for (final (action, title, hint) in actions)
              SettingsChoiceTile(
                title: title,
                subtitle: hint,
                selected: _action == action,
                onTap: () => setState(() => _action = action),
              ),
          ],
        ),
        AppButton(
          label: s.save,
          onPressed: _address.text.trim().isEmpty
              ? null
              : () {
                  ref
                      .read(localSettingsProvider.notifier)
                      .update(
                        (x) => x.copyWith(
                          customRules: [
                            ...x.customRules,
                            CustomRule(_address.text.trim(), _match, _action),
                          ],
                        ),
                      );
                  Navigator.of(context).maybePop();
                },
        ),
      ],
    );
  }
}
