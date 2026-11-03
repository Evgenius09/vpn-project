import 'package:flutter/material.dart';

import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';

/// Replaced by S3-01.
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
