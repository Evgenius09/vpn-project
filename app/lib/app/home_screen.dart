import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/login_controller.dart';
import '../features/connection/application/connection_controller.dart';
import '../features/connection/presentation/connection_panel.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/domain/profile_state.dart';
import '../features/servers/presentation/server_picker.dart';
import '../features/whitelist/application/auto_switch_controller.dart';
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

AccentKind _accentOf(TunnelMode mode) => switch (mode) {
  TunnelMode.regular => AccentKind.regular,
  TunnelMode.whitelist => AccentKind.whitelist,
};

/// The two mode screens. Changing the page never touches the tunnel: a swipe,
/// a dot, the arrow keys, and the ModeSwitch only move the pager.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The fractional page under the finger. The chrome reads it, so its accent
  /// and the ModeSwitch thumb travel with the swipe instead of jumping.
  late final _position = ValueNotifier<double>(
    ref.read(homePageProvider).toDouble(),
  );

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  /// Wears the accent between the two modes at the current swipe position.
  Widget _blended(Widget child) => ValueListenableBuilder<double>(
    valueListenable: _position,
    child: child,
    builder: (context, page, child) {
      final colors = context.colors;
      return AccentTheme(
        accent: AppAccent.lerp(
          colors.regular,
          colors.whitelist,
          page.clamp(0.0, 1.0),
        ),
        child: child!,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop(position: _position)),
          SafeArea(
            child: AppShell(
              // The arrows also work from the settings button and the dots,
              // which sit outside the pager (tech.md 33).
              child: ModeScreenKeys(
                index: index,
                count: pages.length,
                onChanged: show,
                child: Column(
                  children: [
                    _blended(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                size: AppSizes.topBarIcon,
                              ),
                              tooltip: strings.settingsTooltip,
                              onPressed: () =>
                                  context.push(RoutePaths.settings),
                            ),
                            const Spacer(),
                            PageDots(
                              count: pages.length,
                              index: index,
                              onTap: show,
                            ),
                            const Spacer(),
                            const _TelegramButton(),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ModePager(
                        pages: pages,
                        index: index,
                        onChanged: show,
                        position: _position,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: _blended(
                        ModeSwitch(
                          labels: [for (final page in pages) page.title],
                          index: index,
                          onChanged: show,
                          position: _position,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft light of the mode accent behind the PowerButton. The two lights
/// cross-fade with the swipe; blending the hues would pass through mud.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.position});

  static const _glow = 0.24;

  final ValueListenable<double> position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget light(AppAccent accent) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 0.85,
          colors: [
            accent.primary.withValues(alpha: _glow),
            accent.primary.withValues(alpha: 0),
          ],
        ),
      ),
    );
    final regular = light(colors.regular);
    final whitelist = light(colors.whitelist);
    return ColoredBox(
      color: colors.bg,
      child: ValueListenableBuilder<double>(
        valueListenable: position,
        builder: (context, page, _) {
          final t = page.clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: 1 - t, child: regular),
              Opacity(opacity: t, child: whitelist),
            ],
          );
        },
      ),
    );
  }
}

/// Opens the bot of the profile. The bot sells and renews access, so it sits
/// one tap away on the main screen.
class _TelegramButton extends ConsumerWidget {
  const _TelegramButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(profileControllerProvider);
    final bot = profile is ProfileReady ? profile.profile.endpoints.bot : null;
    final uri = bot == null ? null : Uri.tryParse(bot);
    if (uri == null) {
      return const SizedBox.square(dimension: AppSpacing.xxxl);
    }
    return IconButton(
      tooltip: AppLocalizations.of(context).telegramTooltip,
      onPressed: () => ref.read(urlOpenerProvider)(uri),
      icon: Container(
        width: AppSizes.topBarIcon + AppSpacing.sm,
        height: AppSizes.topBarIcon + AppSpacing.sm,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.telegram,
        ),
        child: Icon(
          Icons.telegram,
          color: colors.onPrimary,
          size: AppSizes.topBarIcon,
        ),
      ),
    );
  }
}

/// One mode screen: the wordmark, the PowerButton and the server sheet. As the
/// sheet opens, the wordmark folds away and the button shrinks, so the list
/// gets the room (tech.md 43).
class _ModeScreen extends StatefulWidget {
  const _ModeScreen(this.title, this.mode);

  final String title;
  final TunnelMode mode;

  @override
  State<_ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<_ModeScreen> {
  /// Three server rows under the sheet header.
  static const _sheetRows = 3;
  static const _collapsedSheet =
      ServerSheet.headerHeight +
      _sheetRows * (AppSizes.serverTileHeight + AppSpacing.xs / 2) +
      AppSpacing.md;

  /// The mode title, the small button and its status above an open sheet.
  static const _compactHeader =
      AppSizes.powerButtonCompact + AppSpacing.xxxl * 2 + AppSpacing.md;

  final _open = ValueNotifier<double>(0);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccentTheme(
      accent: context.colors.accentOf(_accentOf(widget.mode)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final minExtent = (_collapsedSheet / height).clamp(0.2, 0.6);
          final maxExtent = ((height - _compactHeader) / height).clamp(
            minExtent + 0.05,
            0.92,
          );
          return Stack(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _open,
                builder: (context, open, _) {
                  final extent = lerpDouble(minExtent, maxExtent, open)!;
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: height * (1 - extent) - AppSpacing.sm,
                    child: _Header(
                      title: widget.title,
                      mode: widget.mode,
                      open: open,
                      width: constraints.maxWidth,
                    ),
                  );
                },
              ),
              ServerPicker(
                group: widget.mode,
                minExtent: minExtent,
                maxExtent: maxExtent,
                onExtent: (value) => _open.value = value,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.mode,
    required this.open,
    required this.width,
  });

  final String title;
  final TunnelMode mode;
  final double open;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = AppLocalizations.of(context);
    // The wordmark is gone by the middle of the pull, the button keeps going.
    final fold = Curves.easeOut.transform((open * 1.8).clamp(0.0, 1.0));
    // Centered in its room while the sheet is low, pinned up as it opens.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.lerp(Alignment.center, Alignment.topCenter, open)!,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: lerpDouble(AppSpacing.sm, 0, fold)),
              ClipRect(
                child: Align(
                  heightFactor: 1 - fold,
                  child: Opacity(
                    opacity: 1 - fold,
                    child: Text(
                      strings.brandWordmark,
                      style: AppText.wordmark.copyWith(color: colors.text),
                    ),
                  ),
                ),
              ),
              Text(
                title,
                style: AppText.bodyStrong.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: lerpDouble(AppSpacing.lg, AppSpacing.sm, open)),
              ConnectionPanel(mode: mode, compact: open),
              if (mode == TunnelMode.whitelist && fold < 1)
                Opacity(
                  opacity: 1 - fold,
                  child: ClipRect(
                    child: Align(
                      heightFactor: 1 - fold,
                      child: const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: _AutoSwitchCard(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The auto switch toggle of the whitelist screen in a card, so it reads as a
/// control and not as loose text (tech.md 34.1).
class _AutoSwitchCard extends ConsumerWidget {
  const _AutoSwitchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(autoSwitchToggleProvider) == null) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.border, width: AppSizes.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const AutoSwitchToggle(),
    );
  }
}
