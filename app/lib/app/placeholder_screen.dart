import 'package:flutter/material.dart';

import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';

/// Replaced by S1-07.
class LoginPlaceholderScreen extends StatelessWidget {
  const LoginPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: AppShell(
        child: EmptyState(icon: Icons.login, title: strings.loginTitle),
      ),
    );
  }
}

/// Replaced by S1-07 and S3-01.
class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: AppShell(
        child: EmptyState(
          icon: Icons.settings,
          title: strings.emptyScreenTitle,
        ),
      ),
    );
  }
}
