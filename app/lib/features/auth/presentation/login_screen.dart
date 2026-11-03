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
    return Scaffold(
      body: SafeArea(
        child: AppShell(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: switch (state) {
              LoginUsername() => _UsernameStep(state),
              LoginBotNotStarted() => _BotStep(state),
              LoginCode() => _CodeStep(state),
            },
          ),
        ),
      ),
    );
  }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.login,
          title: strings.loginUsernameTitle,
          message: strings.loginUsernameMessage,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (fieldError == null) _ErrorBanner(error),
        AppTextField(
          controller: _username,
          label: strings.loginUsernameLabel,
          prefixText: '@',
          errorText: fieldError,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: strings.loginGetCode,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.smart_toy_outlined,
          title: strings.loginBotTitle,
          message: strings.loginBotMessage,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ErrorBanner(state.error),
        if (state.botUrl != null) ...[
          AppButton(
            label: strings.loginOpenBot,
            icon: Icons.open_in_new,
            onPressed: controller.openBot,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: strings.loginPressedStart,
          variant: AppButtonVariant.secondary,
          loading: state.busy,
          onPressed: controller.retryAfterStart,
        ),
        const SizedBox(height: AppSpacing.sm),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: Icons.password,
          title: strings.loginCodeTitle,
          message: strings.loginCodeMessage(state.username),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ErrorBanner(state.error),
        Center(
          child: CodeInput(
            // A new key after each rejected code empties the cells.
            key: ValueKey(state.attempt),
            enabled: !state.busy,
            onCompleted: controller.submitCode,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: strings.loginOpenBot,
          icon: Icons.open_in_new,
          variant: AppButtonVariant.secondary,
          onPressed: controller.openBot,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: state.resendIn > 0
              ? strings.loginResendIn(state.resendIn)
              : strings.loginResend,
          variant: AppButtonVariant.text,
          onPressed: canResend ? controller.resend : null,
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
