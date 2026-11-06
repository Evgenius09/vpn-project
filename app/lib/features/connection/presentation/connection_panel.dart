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
import '../domain/connection_state.dart';
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
          caption: _caption(context, ref, view, connection.tunnel),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: AppDurations.normal,
          child: view.state == PowerState.connected && traffic != null
              ? TrafficCounter(upBps: traffic.upBps, downBps: traffic.downBps)
              : _Hint(view: view),
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

  String _caption(
    BuildContext context,
    WidgetRef ref,
    PowerView view,
    TunnelSnapshot tunnel,
  ) {
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
      PowerState.connected => strings.connectionConnected(
        formatElapsed(_since(ref, tunnel.connectedSince)),
      ),
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

/// The quiet line under the status that says what a tap does.
class _Hint extends StatelessWidget {
  const _Hint({required this.view});

  final PowerView view;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final text = switch (view.action) {
      StartTunnel() => strings.connectionTapToConnect,
      SwitchUserMode() => strings.connectionTapToSwitch,
      _ => null,
    };
    if (text == null) {
      return const SizedBox(height: AppSpacing.lg + 2);
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppText.label.copyWith(
        color: context.colors.textMuted,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
