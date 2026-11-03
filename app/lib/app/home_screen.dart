import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/connection/application/connection_controller.dart';
import '../features/connection/presentation/connection_panel.dart';
import '../features/servers/presentation/server_picker.dart';
import '../features/whitelist/presentation/auto_switch_toggle.dart';
import '../features/whitelist/presentation/mode_screen_keys.dart';
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
    // The auto switch moved the tunnel, so the pager follows it (tech.md 34.2).
    ref.listen(connectionControllerProvider.select((state) => state.notice), (
      _,
      notice,
    ) {
      if (notice != null) {
        show(notice.to.index);
      }
    });
    final pages = [
      ModePage(
        title: strings.modeRegular,
        child: _ModeScreen(strings.modeRegular, TunnelMode.regular),
      ),
      ModePage(
        title: strings.modeWhitelist,
        child: _ModeScreen(strings.modeWhitelist, TunnelMode.whitelist),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppShell(
          // The arrows also work from the settings button and the dots, which
          // sit outside the pager (tech.md 33).
          child: ModeScreenKeys(
            index: index,
            count: pages.length,
            onChanged: show,
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
      ),
    );
  }
}

class _ModeScreen extends StatelessWidget {
  const _ModeScreen(this.title, this.mode);

  final String title;
  final TunnelMode mode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  title,
                  style: AppText.title.copyWith(color: context.colors.text),
                ),
                const SizedBox(height: AppSpacing.lg),
                ConnectionPanel(mode: mode),
                if (mode == TunnelMode.whitelist) const AutoSwitchToggle(),
              ],
            ),
          ),
        ),
        ServerPicker(group: mode),
      ],
    );
  }
}
