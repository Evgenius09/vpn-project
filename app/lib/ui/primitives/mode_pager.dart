import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

class ModePage {
  const ModePage({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _AllPointersScrollBehavior extends MaterialScrollBehavior {
  const _AllPointersScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Horizontal pager of mode screens. Swipes, mouse drags, and the arrow keys
/// only report a new index. They never touch the tunnel (tech.md 2.1).
///
/// [position] follows the finger as a fractional page, so the chrome around
/// the pager (the ModeSwitch thumb, the accent color) moves with the swipe.
class ModePager extends StatefulWidget {
  const ModePager({
    required this.pages,
    required this.index,
    required this.onChanged,
    this.position,
    super.key,
  });

  final List<ModePage> pages;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<double>? position;

  @override
  State<ModePager> createState() => _ModePagerState();
}

class _ModePagerState extends State<ModePager> {
  /// A page shrinks and fades as it slides away, so the swipe reads as one
  /// screen giving way to the other rather than a flat strip.
  static const _minScale = 0.88;

  late final PageController _controller = PageController(
    initialPage: widget.index,
  )..addListener(_report);

  void _report() {
    final page = _controller.hasClients ? _controller.page : null;
    if (page != null) {
      widget.position?.value = page;
    }
  }

  @override
  void didUpdateWidget(ModePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _controller.hasClients ? _controller.page?.round() : null;
    if (widget.index != oldWidget.index && page != widget.index) {
      _controller.animateToPage(
        widget.index,
        duration: AppDurations.page,
        curve: AppCurves.emphasized,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => widget.index - 1,
      LogicalKeyboardKey.arrowRight => widget.index + 1,
      _ => null,
    };
    if (next == null) {
      return KeyEventResult.ignored;
    }
    if (next >= 0 && next < widget.pages.length) {
      widget.onChanged(next);
    }
    return KeyEventResult.handled;
  }

  Widget _page(int i, Widget child) => AnimatedBuilder(
    animation: _controller,
    child: child,
    builder: (context, child) {
      final page = _controller.hasClients && _controller.position.haveDimensions
          ? _controller.page ?? widget.index.toDouble()
          : widget.index.toDouble();
      final offset = (page - i).clamp(-1.0, 1.0);
      final distance = offset.abs();
      return Opacity(
        opacity: (1 - Curves.easeOut.transform(distance)).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: lerpDouble(1, _minScale, Curves.easeOut.transform(distance)),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ScrollConfiguration(
        behavior: const _AllPointersScrollBehavior(),
        child: PageView(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (page) {
            if (page != widget.index) {
              widget.onChanged(page);
            }
          },
          children: [
            for (var i = 0; i < widget.pages.length; i++)
              _page(i, widget.pages[i].child),
          ],
        ),
      ),
    );
  }
}

/// The segmented control under the mode screens. A tap only changes the
/// screen, like a swipe (tech.md 2.1, 43). The thumb follows [position], so it
/// slides with the finger during a swipe.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.position,
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueListenable<double>? position;

  @override
  Widget build(BuildContext context) {
    final position = this.position;
    if (position == null) {
      return TweenAnimationBuilder<double>(
        tween: Tween(end: index.toDouble()),
        duration: AppDurations.page,
        curve: AppCurves.emphasized,
        builder: (context, value, _) => _track(context, value),
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) => _track(context, value),
    );
  }

  Widget _track(BuildContext context, double value) {
    final colors = context.colors;
    final count = labels.length;
    final at = value.clamp(0.0, (count - 1).toDouble());
    return Container(
      height: AppSizes.modeSwitchHeight,
      padding: const EdgeInsets.all(AppSizes.modeSwitchInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border, width: AppSizes.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / count;
          return Stack(
            children: [
              Positioned(
                left: segment * at,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primaryDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.35),
                        blurRadius: AppSpacing.lg,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _Segment(
                        label: labels[i],
                        // 1 on the thumb, 0 a full segment away.
                        selection: (1 - (at - i).abs()).clamp(0.0, 1.0),
                        selected: i == index,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selection,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double selection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong.copyWith(
                color: Color.lerp(
                  colors.textMuted,
                  colors.onPrimary,
                  selection,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
