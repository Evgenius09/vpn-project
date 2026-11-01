import 'package:flutter/material.dart';

import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';
import 'showcases.dart';

class KitchenSinkScreen extends StatelessWidget {
  const KitchenSinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.kitchenSinkTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.themeLight),
              Tab(text: strings.themeDark),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Gallery(theme: AppTheme.light()),
            _Gallery(theme: AppTheme.dark()),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final showcase in showcases)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(showcase.name, style: AppText.caption),
                    const SizedBox(height: AppSpacing.sm),
                    Builder(builder: showcase.build),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
