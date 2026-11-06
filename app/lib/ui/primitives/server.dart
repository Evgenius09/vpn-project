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
    Widget badge(String label, Color dot, Color text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.pingDot,
          height: AppSizes.pingDot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppText.label.copyWith(
            color: text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    final child = switch (value) {
      PingUnknown() => badge(
        strings.pingUnknown,
        colors.idle,
        colors.textMuted,
      ),
      PingMeasuring() => SizedBox.square(
        dimension: AppSizes.iconSmall,
        child: CircularProgressIndicator(
          strokeWidth: AppSizes.spinnerStroke,
          strokeCap: StrokeCap.round,
          color: colors.primaryText,
        ),
      ),
      PingMs(:final value) => badge(
        strings.pingMs(value),
        value < _fastMs
            ? colors.success
            : value < _slowMs
            ? colors.warning
            : colors.danger,
        colors.textMuted,
      ),
      PingUnreachable() => badge(
        strings.pingUnreachable,
        colors.danger,
        colors.danger,
      ),
    };
    return AnimatedSwitcher(
      duration: AppDurations.normal,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(value.runtimeType), child: child),
    );
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
    return Text(emoji, style: TextStyle(fontSize: size, height: 1));
  }
}

class ServerTile extends StatefulWidget {
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
  State<ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends State<ServerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.selected;
    final radius = BorderRadius.circular(AppRadius.tile);
    return AnimatedContainer(
      duration: AppDurations.normal,
      curve: AppCurves.standard,
      height: AppSizes.serverTileHeight,
      decoration: BoxDecoration(
        color: selected
            ? colors.primarySoft
            : _hovered
            ? colors.surfaceAlt
            : colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected
              ? colors.primary
              : colors.primary.withValues(alpha: 0),
          width: AppSizes.border,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDurations.normal,
                  width: AppSizes.flag,
                  height: AppSizes.flag,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.bg : colors.surfaceAlt,
                  ),
                  child: widget.countryCode == null
                      ? Icon(
                          Icons.public,
                          size: AppSizes.iconSmall,
                          color: colors.textMuted,
                        )
                      : FlagIcon(
                          countryCode: widget.countryCode!,
                          size: AppSizes.iconSmall + 2,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(color: colors.text),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: colors.primaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PingBadge(value: widget.ping),
                if (widget.trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill button of the ServerSheet header: an icon, a label, or both.
/// [active] tints it with the accent (tech.md 43).
class SheetChip extends StatelessWidget {
  const SheetChip({
    required this.onPressed,
    this.label,
    this.icon,
    this.tooltip,
    this.active = true,
    this.loading = false,
    super.key,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool active;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = active ? colors.primaryText : colors.textMuted;
    final radius = BorderRadius.circular(AppRadius.pill);
    final Widget? glyph = loading
        ? SizedBox.square(
            dimension: AppSizes.iconSmall - 2,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.spinnerStroke,
              strokeCap: StrokeCap.round,
              color: foreground,
            ),
          )
        : icon == null
        ? null
        : Icon(icon, size: AppSizes.iconSmall, color: foreground);
    final text = label;
    Widget chip = AnimatedContainer(
      duration: AppDurations.normal,
      height: AppSizes.chip,
      constraints: const BoxConstraints(minWidth: AppSizes.chip),
      decoration: BoxDecoration(
        color: active ? colors.primarySoft : colors.surfaceAlt,
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: text == null ? AppSpacing.xs + 3 : AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ?glyph,
                if (glyph != null && text != null)
                  const SizedBox(width: AppSpacing.xs),
                if (text != null)
                  AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: Text(
                      text,
                      key: ValueKey(text),
                      style: AppText.label.copyWith(color: foreground),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      chip = Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }
}

/// The server card at the bottom of a mode screen. It grows when the user
/// pulls its handle or any server row, and then scrolls (tech.md 2.1, 43).
/// [onExtent] reports how open the sheet is, from 0 (collapsed) to 1 (open),
/// so the screen above shrinks with it.
class ServerSheet extends StatefulWidget {
  const ServerSheet({
    required this.header,
    required this.body,
    this.minExtent = 0.22,
    this.maxExtent = 0.9,
    this.onExtent,
    super.key,
  });

  /// The height of the [header] row, pinned while the list scrolls.
  static const headerHeight = 72.0;

  final Widget header;
  final Widget body;
  final double minExtent;
  final double maxExtent;
  final ValueChanged<double>? onExtent;

  @override
  State<ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<ServerSheet> {
  final _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onNotification(DraggableScrollableNotification notification) {
    final span = widget.maxExtent - widget.minExtent;
    widget.onExtent?.call(
      span <= 0
          ? 0
          : ((notification.extent - widget.minExtent) / span).clamp(0.0, 1.0),
    );
    return false;
  }

  /// A tap on the handle opens a closed sheet and closes an open one.
  void _toggle() {
    if (!_controller.isAttached) {
      return;
    }
    final middle = (widget.minExtent + widget.maxExtent) / 2;
    _controller.animateTo(
      _controller.size < middle ? widget.maxExtent : widget.minExtent,
      duration: AppDurations.page,
      curve: AppCurves.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.xl);
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onNotification,
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: widget.minExtent,
        minChildSize: widget.minExtent,
        maxChildSize: widget.maxExtent,
        snap: true,
        snapAnimationDuration: AppDurations.slow,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: radius,
              border: Border.all(color: colors.border, width: AppSizes.border),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SheetHeader(
                      color: colors.surface,
                      handleColor: colors.border,
                      onHandleTap: _toggle,
                      child: widget.header,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      0,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(child: widget.body),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends SliverPersistentHeaderDelegate {
  const _SheetHeader({
    required this.color,
    required this.handleColor,
    required this.onHandleTap,
    required this.child,
  });

  static const _handleArea = AppSpacing.lg + AppSizes.sheetHandleHeight;

  final Color color;
  final Color handleColor;
  final VoidCallback onHandleTap;
  final Widget child;

  @override
  double get minExtent => ServerSheet.headerHeight;

  @override
  double get maxExtent => ServerSheet.headerHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return ColoredBox(
      color: color,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onHandleTap,
            child: SizedBox(
              height: _handleArea,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: AppSizes.sheetHandleWidth,
                  height: AppSizes.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SheetHeader oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.color != color ||
      oldDelegate.handleColor != handleColor;
}
