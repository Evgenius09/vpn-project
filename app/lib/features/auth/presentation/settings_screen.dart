import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../whitelist/application/auto_switch_controller.dart';
import '../../whitelist/presentation/auto_switch_toggle.dart';
import '../application/logout_controller.dart';

/// The minimal settings of tech.md 19.9 and 34.1: the auto switch toggle and
/// logout. S3-01 replaces it.
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
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: AppShell(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // An empty section would remain when the provider keeps the
            // feature off.
            if (ref.watch(autoSwitchToggleProvider) != null) ...[
              SettingsSection(
                title: strings.settingsConnection,
                children: const [AutoSwitchToggle()],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            SettingsSection(
              title: strings.settingsAccount,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: strings.logoutButton,
                    icon: Icons.logout,
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
