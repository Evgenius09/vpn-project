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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), colors.surface),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: AppSizes.border,
        ),
      ),
      child: Row(
        children: [
          Icon(kind.icon, color: color, size: AppSizes.icon),
          const SizedBox(width: AppSpacing.md),
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
    final style = AppText.label.copyWith(
      color: colors.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget part(IconData icon, int bps) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSmall, color: colors.primaryText),
        const SizedBox(width: AppSpacing.xs),
        Text(_format(strings, bps), style: style),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        part(Icons.south_rounded, downBps),
        const SizedBox(width: AppSpacing.lg),
        part(Icons.north_rounded, upBps),
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
              padding: const EdgeInsets.all(AppSpacing.xs + AppSizes.border),
              child: AnimatedContainer(
                duration: AppDurations.page,
                curve: AppCurves.emphasized,
                width: i == index ? AppSizes.dotActive : AppSizes.dot,
                height: AppSizes.dot,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
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
            Container(
              width: AppSizes.logoTile,
              height: AppSizes.logoTile,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primarySoft,
              ),
              child: Icon(icon, size: AppSizes.icon, color: colors.primaryText),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppText.headline.copyWith(color: colors.text),
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
