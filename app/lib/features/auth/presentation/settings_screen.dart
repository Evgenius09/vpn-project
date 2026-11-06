import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../../whitelist/application/auto_switch_controller.dart';
import '../../whitelist/presentation/auto_switch_toggle.dart';
import '../application/login_controller.dart';
import '../application/logout_controller.dart';

/// The minimal settings of tech.md 19.9 and 34.1: the account, the auto switch
/// toggle and logout. S3-01 replaces it.
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
    final strings = AppLocalizations.of(context);
    final busy = ref.watch(logoutControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: AppShell(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (profile is ProfileReady) ...[
              _Account(profile.profile),
              const SizedBox(height: AppSpacing.xl),
            ],
            // An empty section would remain when the provider keeps the
            // feature off.
            if (ref.watch(autoSwitchToggleProvider) != null)
              SettingsSection(
                title: strings.settingsConnection,
                children: const [AutoSwitchToggle()],
              ),
            SettingsSection(
              title: strings.settingsAccount,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: strings.logoutButton,
                    icon: Icons.logout_rounded,
                    variant: AppButtonVariant.danger,
                    loading: busy,
                    onPressed: () => _logout(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The signed-in account from the profile: nick, plan and traffic.
class _Account extends ConsumerWidget {
  const _Account(this.profile);

  static const _gigabyte = 1024 * 1024 * 1024;

  final ProfileV1 profile;

  String _bytes(int bytes) {
    final gb = bytes / _gigabyte;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final account = profile.account;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = switch (account.status) {
      AccountStatus.provisioning => strings.accountProvisioning,
      AccountStatus.trial => strings.accountTrial,
      AccountStatus.active => strings.accountActive,
      AccountStatus.expired => strings.accountExpired,
      AccountStatus.blocked => strings.accountBlocked,
    };
    final expires = account.expiresAt;
    final until = expires == null
        ? null
        : strings.accountUntil(
            DateFormat.MMMMd(locale).format(expires.toLocal()),
          );
    final limit = account.trafficLimitBytes;
    final bot = Uri.tryParse(profile.endpoints.bot);
    return AccountCard(
      title: account.telegramUsername == null
          ? strings.settingsAccount
          : '@${account.telegramUsername}',
      subtitle: [status, ?until].join(' · '),
      action: bot == null
          ? null
          : SheetChip(
              label: strings.accountRenew,
              onPressed: () => ref.read(urlOpenerProvider)(bot),
            ),
      meterLabel: strings.accountTraffic,
      meterValue: limit == 0
          ? strings.accountTrafficUnlimited
          : strings.accountTrafficUsed(
              _bytes(account.trafficUsedBytes),
              _bytes(limit),
            ),
      progress: limit == 0 ? null : account.trafficUsedBytes / limit,
    );
  }
}
