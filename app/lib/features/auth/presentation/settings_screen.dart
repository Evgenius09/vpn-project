import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../../settings/application/local_settings.dart';
import '../../settings/presentation/settings_pages.dart';
import '../../whitelist/application/auto_switch_controller.dart';
import '../../whitelist/presentation/auto_switch_toggle.dart';
import '../application/login_controller.dart';
import '../application/logout_controller.dart';

/// Settings as drawn in Figma (tech.md 43): the account card, then Basics,
/// What goes through VPN, Appearance, More, and logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm(
      context,
      title: strings.logoutConfirmTitle,
      message: strings.logoutConfirmMessage,
      confirmLabel: strings.logoutConfirm,
      danger: true,
    );
    if (confirmed) {
      await ref.read(logoutControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final colors = context.colors;
    final busy = ref.watch(logoutControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final settings = ref.watch(localSettingsProvider);
    final notifier = ref.read(localSettingsProvider.notifier);
    final locale = Localizations.localeOf(context);
    void open(String page) => context.push(SettingsPages.path(page));
    return AppScreen(
      title: s.settingsTitle,
      children: [
        if (profile is ProfileReady) ...[
          _Account(profile.profile),
          const SizedBox(height: AppSpacing.xl),
        ],
        SettingsSection(
          title: s.setSectionBasics,
          children: [
            // The auto switch hides when the provider keeps it off.
            if (ref.watch(autoSwitchToggleProvider) != null)
              const AutoSwitchToggle(),
            SettingsToggleTile(
              title: s.setConnectOnOpen,
              subtitle: s.setConnectOnOpenHint,
              value: settings.connectOnOpen,
              onChanged: (value) =>
                  notifier.update((x) => x.copyWith(connectOnOpen: value)),
            ),
          ],
        ),
        SettingsSection(
          title: s.setSectionThroughVpn,
          children: [
            SettingsNavTile(
              title: s.setTunneling,
              value: SettingsLabels.tunneling(s, settings.tunneling),
              onTap: () => open(SettingsPages.tunneling),
            ),
            SettingsNavTile(
              title: s.setRulesProfile,
              value: SettingsLabels.rules(s, settings.rules),
              onTap: () => open(SettingsPages.rules),
            ),
          ],
        ),
        SettingsSection(
          title: s.setSectionLook,
          children: [
            SettingsNavTile(
              title: s.setTheme,
              value: SettingsLabels.theme(s, settings.theme),
              onTap: () => open(SettingsPages.theme),
            ),
            SettingsNavTile(
              title: s.setLanguage,
              value: SettingsLabels.language(s, settings.language, locale),
              onTap: () => open(SettingsPages.language),
            ),
          ],
        ),
        SettingsSection(
          title: s.setSectionMore,
          children: [
            SettingsNavTile(
              title: s.setSupport,
              value: s.setSupportHint,
              onTap: () => open(SettingsPages.support),
            ),
            SettingsNavTile(
              title: s.setAdvanced,
              value: s.setAdvancedHint,
              onTap: () => open(SettingsPages.advanced),
            ),
          ],
        ),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            onPressed: busy ? null : () => _logout(context, ref),
            child: busy
                ? SizedBox.square(
                    dimension: AppSizes.spinner,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.spinnerStroke,
                      color: colors.danger,
                    ),
                  )
                : Text(
                    s.logoutButton,
                    style: AppText.bodyStrong.copyWith(color: colors.danger),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The signed-in account from the profile: nick, plan and traffic.
class _Account extends ConsumerWidget {
  const _Account(this.profile);

  static const _gigabyte = 1024 * 1024 * 1024;

  final ProfileV1 profile;

  String _bytes(int bytes, String locale) =>
      NumberFormat.decimalPattern(locale)
          .format(double.parse((bytes / _gigabyte).toStringAsFixed(1)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final colors = context.colors;
    final account = profile.account;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = switch (account.status) {
      AccountStatus.provisioning => s.accountProvisioning,
      AccountStatus.trial => s.accountTrial,
      AccountStatus.active => s.accountActive,
      AccountStatus.expired => s.accountExpired,
      AccountStatus.blocked => s.accountBlocked,
    };
    final expires = account.expiresAt;
    final until = expires == null
        ? null
        : s.accountUntil(DateFormat.MMMMd(locale).format(expires.toLocal()));
    final limit = account.trafficLimitBytes;
    final bot = Uri.tryParse(profile.endpoints.bot);
    // The profile carries one traffic counter, and the limit applies to the
    // whitelists, so the regular VPN shows as unlimited (tech.md 43).
    return AccountCard(
      title: account.telegramUsername == null
          ? s.settingsAccount
          : '@${account.telegramUsername}',
      subtitle: [status, ?until].join(' · '),
      action: bot == null
          ? null
          : SheetChip(
              label: s.accountRenew,
              onPressed: () => ref.read(urlOpenerProvider)(bot),
            ),
      meters: [
        AccountMeter(
          label: s.setTrafficRegular,
          value: s.setUnlimited,
          accent: colors.regular,
        ),
        AccountMeter(
          label: s.setTrafficWhitelist,
          value: limit == 0
              ? s.setUnlimited
              : s.accountTrafficUsed(
                  _bytes(account.trafficUsedBytes, locale),
                  '${_bytes(limit, locale)} ${s.unitGb}',
                ),
          accent: colors.whitelist,
          progress: limit == 0 ? null : account.trafficUsedBytes / limit,
        ),
      ],
    );
  }
}
