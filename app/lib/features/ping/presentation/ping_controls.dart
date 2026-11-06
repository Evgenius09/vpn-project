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
    return SheetChip(
      icon: Icons.refresh_rounded,
      tooltip: AppLocalizations.of(context).pingRefresh,
      loading: running,
      onPressed: ref.read(pingControllerProvider.notifier).run,
    );
  }
}

/// The `ui.sortByPing` switch of the ServerSheet header, drawn as a chip
/// that flips between ping order and the default order (tech.md 31.2, 43).
class SortByPingToggle extends ConsumerWidget {
  const SortByPingToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final value = ref.watch(sortByPingProvider);
    final locked = ref.watch(sortByPingLockedProvider);
    return SheetChip(
      icon: locked
          ? Icons.lock_outline_rounded
          : value
          ? Icons.south_rounded
          : Icons.sort_rounded,
      label: value ? strings.pingSortByPingShort : strings.pingSortByOrder,
      tooltip: locked ? strings.lockedByProvider : strings.pingSortByPing,
      active: value,
      onPressed: locked
          ? null
          : () => ref.read(sortChoiceProvider.notifier).choose(!value),
    );
  }
}
