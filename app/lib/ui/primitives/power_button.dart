import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';

enum PowerState { idle, connecting, connected, disconnecting, error }

/// The round connect button: a halo, a ring and the button itself. [size] is
/// the halo diameter. A wave rolls out of the halo once the tunnel connects
/// and a comet runs on the ring while busy.
class PowerButton extends StatefulWidget {
  const PowerButton({
    required this.state,
    required this.onPressed,
    this.size = AppSizes.powerButton,
    this.caption,
    super.key,
  });

  final PowerState state;
  final VoidCallback? onPressed;
  final double size;
  final String? caption;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  static const _haloRatio = 1.0;
  static const _ringRatio = 200 / 240;
  static const _buttonRatio = 160 / 240;
  static const _iconRatio = 64 / 240;
  static const _pressedScale = 0.94;
  static const _hoverScale = 1.03;
  static const _waveReach = 0.22;

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: AppDurations.wave,
  );
  bool _pressed = false;
  bool _hovered = false;

  bool get _busy =>
      widget.state == PowerState.connecting ||
      widget.state == PowerState.disconnecting;

  @override
  void didUpdateWidget(PowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // One wave says "connected"; a looping one would never let the UI rest.
    if (widget.state == PowerState.connected &&
        oldWidget.state != PowerState.connected) {
      _wave.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = widget.size;
    final state = widget.state;
    final connected = state == PowerState.connected;
    final error = state == PowerState.error;

    final buttonFill = connected || _busy ? colors.primary : colors.idle;
    final buttonEdge = switch (state) {
      PowerState.connected => colors.primaryText,
      PowerState.error => colors.danger,
      _ => colors.primary,
    };
    final iconColor = connected || _busy
        ? colors.onPrimary
        : error
        ? colors.danger
        : colors.primaryText;
    final haloColor = connected || _busy
        ? colors.primarySoft.withValues(alpha: 0.5)
        : colors.surface;
    final ringColor = connected || _busy
        ? colors.primarySoft
        : colors.surfaceAlt;
    final enabled = widget.onPressed != null;
    final scale = _pressed
        ? _pressedScale
        : _hovered && enabled
        ? _hoverScale
        : 1.0;

    final button = AnimatedScale(
      scale: scale,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: AnimatedContainer(
        duration: AppDurations.slow,
        curve: AppCurves.standard,
        width: size * _buttonRatio,
        height: size * _buttonRatio,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonFill,
          gradient: connected || _busy
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.primaryDeep],
                )
              : null,
          border: Border.all(color: buttonEdge, width: AppSizes.borderStrong),
          boxShadow: connected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.45),
                    blurRadius: size * 0.18,
                    spreadRadius: size * 0.01,
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onHover: (value) => setState(() => _hovered = value),
            customBorder: const CircleBorder(),
            child: Center(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: iconColor),
                duration: AppDurations.slow,
                builder: (context, color, _) => Icon(
                  Icons.power_settings_new_rounded,
                  color: color,
                  size: size * _iconRatio,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: AppLocalizations.of(context).powerButtonLabel,
          child: SizedBox.square(
            dimension: size,
            child: AnimatedBuilder(
              animation: _wave,
              builder: (context, child) {
                final wave = Curves.easeOutCubic.transform(_wave.value);
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (_wave.isAnimating)
                      Transform.scale(
                        scale: 1 + _waveReach * wave,
                        child: Opacity(
                          opacity: (1 - wave) * 0.8,
                          child: _Disc(
                            diameter: size * _haloRatio,
                            color: colors.primarySoft,
                          ),
                        ),
                      ),
                    _Disc(diameter: size * _haloRatio, color: haloColor),
                    _Disc(diameter: size * _ringRatio, color: ringColor),
                    if (_busy)
                      SizedBox.square(
                        dimension: size * _ringRatio,
                        child: CircularProgressIndicator(
                          strokeWidth: AppSizes.spinnerStroke * 2,
                          strokeCap: StrokeCap.round,
                          color: colors.primaryText,
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: button,
            ),
          ),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: AppSpacing.md),
          AnimatedDefaultTextStyle(
            duration: AppDurations.slow,
            // Merged, so the theme's font family survives.
            style: DefaultTextStyle.of(context).style
                .merge(AppText.title)
                .copyWith(
                  color: connected
                      ? colors.primaryText
                      : error
                      ? colors.danger
                      : colors.text,
                ),
            textAlign: TextAlign.center,
            child: AnimatedSwitcher(
              duration: AppDurations.normal,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: Text(
                widget.caption!,
                // Only a new meaning animates, not every tick of the timer.
                key: ValueKey(state),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppDurations.slow,
    curve: AppCurves.standard,
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
