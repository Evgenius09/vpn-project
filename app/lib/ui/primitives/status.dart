import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';
import 'controls.dart';

enum BannerKind { info, warning, error, success }

extension on BannerKind {
  Color color(AppColors colors) => switch (this) {
    BannerKind.info => colors.primary,
    BannerKind.warning => colors.warning,
    BannerKind.error => colors.danger,
    BannerKind.success => colors.success,
  };

  IconData get icon => switch (this) {
    BannerKind.info => Icons.info_outline,
    BannerKind.warning => Icons.warning_amber,
    BannerKind.error => Icons.error_outline,
    BannerKind.success => Icons.check_circle_outline,
  };
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.kind,
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final BannerKind kind;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = kind.color(colors);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color, width: AppSizes.border),
      ),
      child: Row(
        children: [
          Icon(kind.icon, color: color, size: AppSizes.icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.label.copyWith(color: colors.text),
            ),
          ),
          if (actionLabel != null)
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.text,
            ),
        ],
      ),
    );
  }
}

class TrafficCounter extends StatelessWidget {
  const TrafficCounter({required this.upBps, required this.downBps, super.key});

  static const _kilo = 1024;

  final int upBps;
  final int downBps;

  String _format(AppLocalizations strings, int bps) {
    if (bps < _kilo) {
      return strings.speedBytes(bps.toString());
    }
    if (bps < _kilo * _kilo) {
      return strings.speedKilobytes((bps / _kilo).toStringAsFixed(1));
    }
    return strings.speedMegabytes((bps / (_kilo * _kilo)).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = AppLocalizations.of(context);
    final style = AppText.caption.copyWith(color: colors.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_upward,
          size: AppSizes.iconSmall,
          color: colors.textMuted,
        ),
        Text(_format(strings, upBps), style: style),
        const SizedBox(width: AppSpacing.md),
        Icon(
          Icons.arrow_downward,
          size: AppSizes.iconSmall,
          color: colors.textMuted,
        ),
        Text(_format(strings, downBps), style: style),
      ],
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({
    required this.count,
    required this.index,
    this.onTap,
    super.key,
  });

  final int count;
  final int index;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(i),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: AppSizes.dot,
                height: AppSizes.dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == index ? colors.primary : colors.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconLarge, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppText.title.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppText.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.colors.primary),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: error,
      action: onRetry == null
          ? null
          : AppButton(
              label: AppLocalizations.of(context).retry,
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            ),
    );
  }
}

abstract final class AppSnack {
  static void show(
    BuildContext context, {
    required String text,
    BannerKind kind = BannerKind.info,
  }) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.surfaceAlt,
        content: Row(
          children: [
            Icon(kind.icon, color: kind.color(colors), size: AppSizes.icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppText.label.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: child,
      ),
    );
  }
}
