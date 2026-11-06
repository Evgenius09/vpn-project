import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../application/login_controller.dart';
import '../domain/login_state.dart';
import 'login_error_text.dart';

/// Login through the Telegram bot (tech.md 2.2), laid out as the Figma login
/// row: nick, code, open the bot (tech.md 43).
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginControllerProvider);
    final step = switch (state) {
      LoginUsername() => _UsernameStep(state),
      LoginBotNotStarted() => _BotStep(state),
      LoginCode() => _CodeStep(state),
    };
    return Scaffold(
      body: SafeArea(
        child: AppShell(
          child: AnimatedSwitcher(
            duration: AppDurations.slow,
            switchInCurve: AppCurves.standard,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            // A new step slides in; a tick of the resend timer does not.
            child: KeyedSubtree(key: ValueKey(state.runtimeType), child: step),
          ),
        ),
      ),
    );
  }
}

/// The frame every login step shares: an optional back arrow, the brand,
/// the step's title and text, its controls, and a footer at the bottom.
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.message,
    required this.children,
    this.onBack,
    this.footer = const [],
  });

  final String title;
  final String message;
  final List<Widget> children;
  final VoidCallback? onBack;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: AppSizes.topBarButton + AppSpacing.md,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: onBack == null
                        ? null
                        : IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: colors.text,
                            ),
                            onPressed: onBack,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  strings.brandWordmark,
                  textAlign: TextAlign.center,
                  style: AppText.wordmark.copyWith(color: colors.text),
                ),
                Text(
                  strings.brandTagline,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xxxl + AppSpacing.sm),
                Text(
                  title,
                  style: AppText.screenTitle.copyWith(color: colors.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  style: AppText.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                ...children,
                const Spacer(),
                const SizedBox(height: AppSpacing.xl),
                ...footer,
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppText.caption.copyWith(
        fontSize: 13,
        color: context.colors.textMuted,
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: AppText.overline.copyWith(
        letterSpacing: 0,
        color: context.colors.textMuted,
      ),
    ),
  );
}

/// The banner under the nick or the code. A failure that waiting fixes is a
/// warning, the rest are errors (the "Ошибки входа" frame).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.error);

  final LoginError? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) {
      return const SizedBox.shrink();
    }
    final warning = switch (error.failure) {
      LoginFailure.rateLimited ||
      LoginFailure.unavailable ||
      LoginFailure.panelUnavailable ||
      LoginFailure.internal ||
      LoginFailure.telegramUserNotFound => true,
      _ => false,
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: StatusBanner(
        kind: warning ? BannerKind.warning : BannerKind.error,
        text: loginErrorText(AppLocalizations.of(context), error),
      ),
    );
  }
}

class _UsernameStep extends ConsumerStatefulWidget {
  const _UsernameStep(this.state);

  final LoginUsername state;

  @override
  ConsumerState<_UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends ConsumerState<_UsernameStep> {
  late final _username = TextEditingController(text: widget.state.username);

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final state = widget.state;
    final controller = ref.read(loginControllerProvider.notifier);
    return _StepLayout(
      title: strings.loginUsernameTitle,
      message: strings.loginUsernameMessage,
      footer: [
        _Footnote(strings.loginBotFooter),
        AppButton(
          label: strings.loginOpenBot,
          variant: AppButtonVariant.secondary,
          onPressed: controller.openBot,
        ),
      ],
      children: [
        AppTextField(
          controller: _username,
          label: strings.loginUsernameLabel,
          prefixText: '@',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.loginUsernameHint,
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
        _ErrorBanner(state.error),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.loginGetCode,
          loading: state.busy,
          onPressed: () => controller.submitUsername(_username.text),
        ),
      ],
    );
  }
}

class _BotStep extends ConsumerWidget {
  const _BotStep(this.state);

  final LoginBotNotStarted state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final controller = ref.read(loginControllerProvider.notifier);
    return _StepLayout(
      title: strings.loginBotHeading,
      message: strings.loginBotIntro(state.username),
      onBack: state.busy ? null : controller.changeUsername,
      footer: [_Footnote(strings.loginNoNickFooter)],
      children: [
        StatusBanner(
          kind: BannerKind.warning,
          text: state.error == null
              ? strings.loginBotNotFound
              : loginErrorText(strings, state.error!),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.botUrl != null) ...[
          AppButton(label: strings.loginOpenBot, onPressed: controller.openBot),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: strings.loginPressedStart,
          variant: AppButtonVariant.secondary,
          loading: state.busy,
          onPressed: controller.retryAfterStart,
        ),
      ],
    );
  }
}

class _CodeStep extends ConsumerStatefulWidget {
  const _CodeStep(this.state);

  final LoginCode state;

  @override
  ConsumerState<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<_CodeStep> {
  static const _length = 6;

  String _code = '';

  String _timer(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    final state = widget.state;
    final controller = ref.read(loginControllerProvider.notifier);
    final canResend = state.resendIn == 0 && !state.busy;
    final codeFailed = switch (state.error?.failure) {
      LoginFailure.codeInvalid || LoginFailure.codeExpired => true,
      _ => false,
    };
    return _StepLayout(
      title: strings.loginCodeTitle,
      message: strings.loginCodeIntro(state.username),
      onBack: state.busy ? null : controller.changeUsername,
      footer: [
        _Footnote(strings.loginCodeFooter),
        AppButton(
          label: strings.loginOpenBot,
          variant: AppButtonVariant.secondary,
          onPressed: controller.openBot,
        ),
      ],
      children: [
        _FieldLabel(strings.loginCodeLabel),
        CodeInput(
          length: _length,
          enabled: !state.busy,
          errorText: codeFailed ? '' : null,
          onChanged: (value) => setState(() => _code = value),
          onCompleted: controller.submitCode,
        ),
        _ErrorBanner(state.error),
        if (!codeFailed) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: state.resendIn > 0
                ? Text(
                    strings.loginResendInTimer(_timer(state.resendIn)),
                    style: AppText.caption.copyWith(
                      fontSize: 13,
                      color: colors.textMuted,
                    ),
                  )
                : AppButton(
                    label: strings.loginResend,
                    variant: AppButtonVariant.text,
                    onPressed: canResend ? controller.resend : null,
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.loginSignIn,
          loading: state.busy,
          // Drawn enabled as in the design; an unfinished code waits.
          onPressed: () {
            if (_code.length == _length) {
              controller.submitCode(_code);
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (codeFailed)
          AppButton(
            label: strings.loginNewCode,
            variant: AppButtonVariant.text,
            onPressed: canResend ? controller.resend : null,
          )
        else
          AppButton(
            label: strings.loginChangeUsername,
            variant: AppButtonVariant.text,
            onPressed: state.busy ? null : controller.changeUsername,
          ),
      ],
    );
  }
}
