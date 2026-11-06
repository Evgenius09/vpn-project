import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../auth/application/login_controller.dart';

/// The free mode for a user without an account, from the Figma row
/// «Бесплатно» (tech.md 43): one free server on the regular screen, a locked
/// whitelist screen, and a way to the bot and to login on both. Like the main
/// screen, a swipe or the ModeSwitch only changes the screen.
class FreeScreen extends ConsumerStatefulWidget {
  const FreeScreen({required this.loginPath, super.key});

  final String loginPath;

  @override
  ConsumerState<FreeScreen> createState() => _FreeScreenState();
}

class _FreeScreenState extends ConsumerState<FreeScreen> {
  final _position = ValueNotifier<double>(0);
  int _index = 0;

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  Widget _blended(Widget child) => ValueListenableBuilder<double>(
    valueListenable: _position,
    child: child,
    builder: (context, page, child) => AccentTheme(
      accent: AppAccent.lerp(
        context.colors.regular,
        context.colors.whitelist,
        page.clamp(0.0, 1.0),
      ),
      child: child!,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final bot = ref.watch(appConfigProvider).botUrl;
    final botUri = bot == null ? null : Uri.tryParse(bot);
    void openBot() {
      if (botUri != null) {
        ref.read(urlOpenerProvider)(botUri);
      }
    }

    void login() => context.push(widget.loginPath);
    void show(int page) => setState(() => _index = page);
    final pages = [
      ModePage(
        title: strings.modeRegular,
        child: AccentTheme(
          accent: context.colors.regular,
          child: _RegularPage(onBot: openBot, onLogin: login),
        ),
      ),
      ModePage(
        title: strings.modeWhitelist,
        child: AccentTheme(
          accent: context.colors.whitelist,
          child: _WhitelistPage(onBot: openBot, onLogin: login),
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppShell(
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
                          size: AppSizes.topBarIcon - 4,
                        ),
                        tooltip: strings.settingsTooltip,
                        onPressed: login,
                      ),
                      const Spacer(),
                      PageDots(count: pages.length, index: _index, onTap: show),
                      const Spacer(),
                      TelegramButton(
                        onPressed: botUri == null ? null : openBot,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ModePager(
                  pages: pages,
                  index: _index,
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
                    index: _index,
                    onChanged: show,
                    position: _position,
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

/// The wordmark, the mode name, the button and its two status lines.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.status,
    required this.hint,
    required this.onPower,
  });

  final String title;
  final String status;
  final String hint;
  final VoidCallback? onPower;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.brandWordmark,
          style: AppText.wordmark.copyWith(color: colors.text),
        ),
        Text(
          title,
          style: AppText.bodyStrong.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 4),
        PowerButton(
          state: PowerState.idle,
          onPressed: onPower,
          caption: status,
        ),
        const SizedBox(height: AppSpacing.sm - 2),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onBot, required this.onLogin});

  final VoidCallback onBot;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(label: strings.freeGetFull, onPressed: onBot),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: strings.freeHaveAccount,
          variant: AppButtonVariant.text,
          onPressed: onLogin,
        ),
      ],
    );
  }
}

/// Scales the page down on short screens instead of overflowing.
class _Fit extends StatelessWidget {
  const _Fit({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: constraints.maxWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _RegularPage extends StatelessWidget {
  const _RegularPage({required this.onBot, required this.onLogin});

  final VoidCallback onBot;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    return _Fit(
      children: [
        const SizedBox(height: AppSpacing.sm),
        _Header(
          title: strings.modeRegular,
          status: strings.connectionNotConnected,
          hint: strings.connectionTapToConnect,
          // The free server needs an account the backend does not issue yet.
          onPower: () {},
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: colors.border, width: AppSizes.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: AppSizes.sheetHandleWidth,
                  height: AppSizes.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.serversTitle,
                        style: AppText.headline.copyWith(color: colors.text),
                      ),
                    ),
                    SheetChip(
                      icon: Icons.refresh_rounded,
                      tooltip: strings.pingRefresh,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              ServerTile(
                title: strings.freeServer,
                subtitle: strings.freeServerHint,
                ping: const PingValue.unknown(),
                selected: true,
                leading: Icon(
                  Icons.telegram,
                  color: colors.telegram,
                  size: AppSizes.flag,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Actions(onBot: onBot, onLogin: onLogin),
      ],
    );
  }
}

class _WhitelistPage extends StatelessWidget {
  const _WhitelistPage({required this.onBot, required this.onLogin});

  final VoidCallback onBot;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    return _Fit(
      children: [
        const SizedBox(height: AppSpacing.sm),
        _Header(
          title: strings.modeWhitelist,
          status: strings.connectionUnavailable,
          hint: strings.freeWhitelistHint,
          onPower: null,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border, width: AppSizes.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.freeWhitelistTitle,
                      style: AppText.headline.copyWith(color: colors.text),
                    ),
                  ),
                  Container(
                    width: AppSizes.chip,
                    height: AppSizes.chip,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: AppSizes.iconSmall,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.freeWhitelistText,
                style: AppText.caption.copyWith(
                  fontSize: 13,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Actions(onBot: onBot, onLogin: onLogin),
      ],
    );
  }
}
