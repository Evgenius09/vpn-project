import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/profile/presentation/server_list.dart';
import '../gen/api/export.dart';
import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';
import 'routes.dart';

class HomePageNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void show(int page) => state = page;
}

final homePageProvider = NotifierProvider<HomePageNotifier, int>(
  HomePageNotifier.new,
);

/// The two mode screens. Changing the page never touches the tunnel.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final index = ref.watch(homePageProvider);
    final show = ref.read(homePageProvider.notifier).show;
    final pages = [
      ModePage(
        title: strings.modeRegular,
        child: _ModeScreen(strings.modeRegular, TunnelMode.regular),
      ),
      ModePage(
        title: strings.modeWhitelist,
        child: _ModeScreen(strings.modeWhitelist, null),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppShell(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: strings.settingsTooltip,
                    onPressed: () => context.push(RoutePaths.settings),
                  ),
                  const Spacer(),
                  PageDots(count: pages.length, index: index, onTap: show),
                  const Spacer(),
                  const SizedBox.square(dimension: AppSpacing.xxxl),
                ],
              ),
              Expanded(
                child: ModePager(pages: pages, index: index, onChanged: show),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeScreen extends StatelessWidget {
  const _ModeScreen(this.title, this.group);

  final String title;

  /// The server group of this screen. S2-01 sets it for whitelists.
  final TunnelMode? group;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    return Stack(
      children: [
        EmptyState(icon: Icons.shield_outlined, title: title),
        if (group != null) ServerList(group: group),
      ],
    );
  }
}
