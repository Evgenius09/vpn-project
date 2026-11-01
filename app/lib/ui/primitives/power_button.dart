import 'package:flutter/material.dart';

import '../../gen/l10n/app_localizations.dart';
import '../tokens.dart';

enum PowerState { idle, connecting, connected, disconnecting, error }

class PowerButton extends StatelessWidget {
  const PowerButton({
    required this.state,
    required this.onPressed,
    this.size = 168,
    this.caption,
    super.key,
  });

  final PowerState state;
  final VoidCallback? onPressed;
  final double size;
  final String? caption;

  bool get _busy =>
      state == PowerState.connecting || state == PowerState.disconnecting;

  Color _color(AppColors colors) => switch (state) {
    PowerState.idle => colors.idle,
    PowerState.connecting || PowerState.disconnecting => colors.connecting,
    PowerState.connected => colors.connected,
    PowerState.error => colors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _color(colors);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: onPressed != null,
          label: AppLocalizations.of(context).powerButtonLabel,
          child: Material(
            color: colors.surface,
            shape: CircleBorder(
              side: BorderSide(color: color, width: AppSpacing.xs),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_busy)
                      SizedBox.square(
                        dimension: size - AppSpacing.xxl,
                        child: CircularProgressIndicator(color: color),
                      ),
                    Icon(
                      Icons.power_settings_new,
                      color: color,
                      size: size / 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            caption!,
            style: AppText.body.copyWith(color: colors.text),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
