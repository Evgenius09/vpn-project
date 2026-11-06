import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../application/login_controller.dart';
import '../domain/login_state.dart';
import 'login_error_text.dart';

/// Login through the Telegram bot (tech.md 2.2): nick, then code.
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

/// The frame every login step shares: the brand on top, the step's title and
/// text, its controls, and a footer pinned to the bottom.
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.message,
    required this.children,
    this.footer = const [],
  });

  final String title;
  final String message;
  final List<Widget> children;
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
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  title,
                  style: AppText.display.copyWith(color: colors.text),
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
      style: AppText.caption.copyWith(color: context.colors.textMuted),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.error);

  final LoginError? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: StatusBanner(
        kind: BannerKind.error,
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
    final error = state.error;
    final fieldError = error?.failure == LoginFailure.invalidUsername
        ? loginErrorText(strings, error!)
        : null;
    return _StepLayout(
      title: strings.loginUsernameTitle,
      message: strings.loginUsernameMessage,
      footer: [_Footnote(strings.loginBotFooter)],
      children: [
        if (fieldError == null) _ErrorBanner(error),
        AppTextField(
          controller: _username,
          label: strings.loginUsernameLabel,
          prefixText: '@',
          errorText: fieldError,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.loginUsernameHint,
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.loginGetCode,
          icon: Icons.login,
          loading: state.busy,
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .submitUsername(_username.text),
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
      title: strings.loginBotTitle,
      message: strings.loginBotMessage,
      children: [
        _ErrorBanner(state.error),
        if (state.botUrl != null) ...[
          AppButton(
            label: strings.loginOpenBot,
            icon: Icons.telegram,
            onPressed: controller.openBot,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: strings.loginPressedStart,
          variant: AppButtonVariant.secondary,
          loading: state.busy,
          onPressed: controller.retryAfterStart,
        ),
        AppButton(
          label: strings.loginChangeUsername,
          variant: AppButtonVariant.text,
          onPressed: state.busy ? null : controller.changeUsername,
        ),
      ],
    );
  }
}

class _CodeStep extends ConsumerWidget {
  const _CodeStep(this.state);

  final LoginCode state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final controller = ref.read(loginControllerProvider.notifier);
    final canResend = state.resendIn == 0 && !state.busy;
    return _StepLayout(
      title: strings.loginCodeTitle,
      message: strings.loginCodeMessage(state.username),
      footer: [_Footnote(strings.loginCodeFooter)],
      children: [
        _ErrorBanner(state.error),
        Text(
          strings.loginCodeLabel.toUpperCase(),
          style: AppText.overline.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CodeInput(
            // A new key after each rejected code empties the cells.
            key: ValueKey(state.attempt),
            enabled: !state.busy,
            onCompleted: controller.submitCode,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.loginOpenBot,
          icon: Icons.telegram,
          variant: AppButtonVariant.secondary,
          onPressed: controller.openBot,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.center,
          child: AppButton(
            label: state.resendIn > 0
                ? strings.loginResendIn(state.resendIn)
                : strings.loginResend,
            variant: AppButtonVariant.text,
            onPressed: canResend ? controller.resend : null,
          ),
        ),
        AppButton(
          label: strings.loginChangeUsername,
          variant: AppButtonVariant.text,
          onPressed: state.busy ? null : controller.changeUsername,
        ),
      ],
    );
  }
}
