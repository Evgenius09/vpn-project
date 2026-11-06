import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../application/connection_controller.dart';
import '../application/power_view.dart';
import '../domain/elapsed.dart';
import 'connection_error_text.dart';
import 'mode_notice_text.dart';

/// The PowerButton, its status line, traffic, and the error banner of one
/// mode screen (tech.md 2.1, 27.1).
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({required this.mode, this.compact = 0, super.key});

  final TunnelMode mode;

  /// 0 shows the full button, 1 the small one of an open server sheet.
  final double compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final connection = ref.watch(connectionControllerProvider);
    final canStart = ref.watch(profileControllerProvider) is ProfileReady;
    final view = powerViewFor(
      mode,
      connection.tunnel,
      busy: connection.busy,
      canStart: canStart,
    );
    final traffic = connection.traffic;
    final issue = connection.issue;
    final notice = connection.notice;
    final controller = ref.read(connectionControllerProvider.notifier);
    // The open sheet folds the status into one line (Figma, tech.md 43).
    final folded = compact >= 0.5;
    final elapsed = view.state == PowerState.connected
        ? formatElapsed(_since(ref, connection.tunnel.connectedSince))
        : null;
    final hint = switch (view.state) {
      PowerState.connected => [
        ?elapsed,
        if (traffic != null)
          '↓ ${TrafficCounter.format(strings, traffic.downBps)}  '
              '↑ ${TrafficCounter.format(strings, traffic.upBps)}',
      ].join('  ·  '),
      _ => switch (view.action) {
        StartTunnel() => strings.connectionTapToConnect,
        SwitchUserMode() => strings.connectionTapToSwitch,
        _ => '',
      },
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PowerButton(
          state: view.state,
          onPressed: view.action == null ? null : () => controller.tap(mode),
          size: lerpDouble(
            AppSizes.powerButton,
            AppSizes.powerButtonCompact,
            compact,
          )!,
          caption: folded && elapsed != null
              ? '${strings.connectionConnectedShort} · $elapsed'
              : _caption(context, view),
        ),
        ClipRect(
          child: Align(
            heightFactor: (1 - compact * 2).clamp(0.0, 1.0),
            child: Opacity(
              opacity: (1 - compact * 2).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.colors.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            kind: notice.reason == ModeSwitchReason.noWhitelistServers
                ? BannerKind.warning
                : BannerKind.info,
            text: modeNoticeText(strings, notice),
          ),
        ],
        if (issue != null) ...[
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            kind: BannerKind.error,
            text: connectionErrorText(strings, issue),
          ),
        ],
      ],
    );
  }

  String _caption(BuildContext context, PowerView view) {
    final strings = AppLocalizations.of(context);
    final elsewhere = view.activeElsewhere;
    return switch (view.state) {
      PowerState.idle when elsewhere != null =>
        strings.connectionActiveElsewhere(switch (elsewhere) {
          TunnelMode.regular => strings.modeRegular,
          TunnelMode.whitelist => strings.modeWhitelist,
        }),
      PowerState.idle => strings.connectionDisconnected,
      PowerState.connecting => strings.connectionConnecting,
      PowerState.disconnecting => strings.connectionDisconnecting,
      PowerState.error => strings.connectionFailed,
      PowerState.connected => strings.connectionConnectedShort,
    };
  }

  /// Watching the tick only while connected keeps the timer off otherwise.
  Duration _since(WidgetRef ref, DateTime? connectedSince) {
    final now =
        ref.watch(connectionTickProvider).value ??
        ref.read(connectionClockProvider)();
    return connectedSince == null
        ? Duration.zero
        : now.difference(connectedSince);
  }
}
