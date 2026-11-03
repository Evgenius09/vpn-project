import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../application/ping_controller.dart';
import '../domain/server_ping.dart';

/// The badge value of a server's last ping. No entry means not pinged yet.
PingValue pingValueOf(ServerPing? ping) => switch (ping) {
  null || UnknownPing() => const PingValue.unknown(),
  MeasuringPing() => const PingValue.measuring(),
  DelayPing(:final ms) => PingValue.ms(ms),
  UnreachablePing() => const PingValue.unreachable(),
};

/// Starts a ping of every server (tech.md 31.2).
class PingRefreshButton extends ConsumerWidget {
  const PingRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(
      pingControllerProvider.select((state) => state.running),
    );
    return AppButton(
      label: AppLocalizations.of(context).pingRefresh,
      icon: Icons.refresh,
      variant: AppButtonVariant.text,
      loading: running,
      onPressed: ref.read(pingControllerProvider.notifier).run,
    );
  }
}

/// The `ui.sortByPing` toggle of the ServerSheet header (tech.md 31.2).
class SortByPingToggle extends ConsumerWidget {
  const SortByPingToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsToggleTile(
    title: AppLocalizations.of(context).pingSortByPing,
    value: ref.watch(sortByPingProvider),
    locked: ref.watch(sortByPingLockedProvider),
    onChanged: ref.read(sortChoiceProvider.notifier).choose,
  );
}
