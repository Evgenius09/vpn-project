import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';

sealed class PingValue {
  const PingValue();

  const factory PingValue.unknown() = PingUnknown;
  const factory PingValue.measuring() = PingMeasuring;
  const factory PingValue.ms(int value) = PingMs;
  const factory PingValue.unreachable() = PingUnreachable;
}

final class PingUnknown extends PingValue {
  const PingUnknown();
}

final class PingMeasuring extends PingValue {
  const PingMeasuring();
}

final class PingMs extends PingValue {
  const PingMs(this.value);

  final int value;
}

final class PingUnreachable extends PingValue {
  const PingUnreachable();
}

class PingBadge extends StatelessWidget {
  const PingBadge({required this.value, super.key});

  static const _fastMs = 100;
  static const _slowMs = 300;

  final PingValue value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = AppLocalizations.of(context);
    Widget text(String label, Color color) =>
        Text(label, style: AppText.caption.copyWith(color: color));

    return switch (value) {
      PingUnknown() => text(strings.pingUnknown, colors.textMuted),
      PingMeasuring() => SizedBox.square(
        dimension: AppSizes.iconSmall,
        child: CircularProgressIndicator(
          strokeWidth: AppSizes.spinnerStroke,
          color: colors.textMuted,
        ),
      ),
      PingMs(:final value) => text(
        strings.pingMs(value),
        value < _fastMs
            ? colors.success
            : value < _slowMs
            ? colors.warning
            : colors.danger,
      ),
      PingUnreachable() => text(strings.pingUnreachable, colors.danger),
    };
  }
}

class FlagIcon extends StatelessWidget {
  const FlagIcon({required this.countryCode, this.size = 20, super.key});

  static const _regionalIndicatorA = 0x1F1E6;
  static const _letterA = 0x41;

  final String countryCode;
  final double size;

  String? get _emoji {
    final code = countryCode.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return null;
    }
    return String.fromCharCodes(
      code.codeUnits.map((c) => c - _letterA + _regionalIndicatorA),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji;
    if (emoji == null) {
      return Icon(Icons.public, size: size, color: context.colors.textMuted);
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }
}

class ServerTile extends StatelessWidget {
  const ServerTile({
    required this.title,
    required this.ping,
    required this.selected,
    this.subtitle,
    this.countryCode,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? countryCode;
  final PingValue ping;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.surfaceAlt : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (countryCode != null) ...[
                FlagIcon(countryCode: countryCode!),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(color: colors.text),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              PingBadge(value: ping),
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.check,
                  size: AppSizes.iconSmall,
                  color: colors.primary,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ServerSheet extends StatelessWidget {
  const ServerSheet({
    required this.header,
    required this.body,
    this.minExtent = 0.22,
    this.maxExtent = 0.9,
    super.key,
  });

  final Widget header;
  final Widget body;
  final double minExtent;
  final double maxExtent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: minExtent,
      minChildSize: minExtent,
      maxChildSize: maxExtent,
      builder: (context, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          border: Border.all(color: colors.border, width: AppSizes.border),
        ),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: AppSizes.sheetHandleWidth,
                    height: AppSizes.sheetHandleHeight,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: header,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(child: body),
            ),
          ],
        ),
      ),
    );
  }
}
