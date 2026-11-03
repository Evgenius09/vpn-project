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

/// The PowerButton, its status line, traffic, and the error banner of one
/// mode screen (tech.md 2.1, 27.1).
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({required this.mode, super.key});

  final TunnelMode mode;

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
    final controller = ref.read(connectionControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PowerButton(
          state: view.state,
          onPressed: view.action == null ? null : () => controller.tap(mode),
          caption: _caption(context, ref, view, connection.tunnel),
        ),
        if (view.state == PowerState.connected && traffic != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TrafficCounter(upBps: traffic.upBps, downBps: traffic.downBps),
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
