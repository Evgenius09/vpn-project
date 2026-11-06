import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../ping/application/ping_controller.dart';
import '../../ping/presentation/ping_controls.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../application/selection_controller.dart';
import '../application/server_choice.dart';

/// The servers of one mode screen with the chosen one highlighted. A tap
/// chooses a server for this group (tech.md 16 S1-09, 28). The ping feature
/// supplies the order, the badges, and the header controls (tech.md 31.2).
class ServerPicker extends ConsumerWidget {
  const ServerPicker({
    required this.group,
    this.minExtent = 0.22,
    this.maxExtent = 0.9,
    this.onExtent,
    super.key,
  });

  final TunnelMode group;
  final double minExtent;
  final double maxExtent;
  final ValueChanged<double>? onExtent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final state = ref.watch(profileControllerProvider);
    return ServerSheet(
      minExtent: minExtent,
      maxExtent: maxExtent,
      onExtent: onExtent,
      header: Row(
        children: [
          Expanded(
            child: Text(
              strings.serversTitle,
              style: AppText.headline.copyWith(color: context.colors.text),
            ),
          ),
          const PingRefreshButton(),
          const SizedBox(width: AppSpacing.sm),
          const SortByPingToggle(),
        ],
      ),
      body: switch (state) {
        ProfileLoading() => const SizedBox(
          height: AppSpacing.xxxl * 2,
          child: LoadingView(),
        ),
        ProfileFailed() => ErrorView(
          error: strings.profileLoadFailed,
          onRetry: ref.read(profileControllerProvider.notifier).load,
        ),
        ProfileReady(:final fromCache) => _Servers(
          group: group,
          servers: ref.watch(orderedServersProvider(group)),
          fromCache: fromCache,
        ),
      },
    );
  }
}

class _Servers extends ConsumerWidget {
  const _Servers({
    required this.group,
    required this.servers,
    required this.fromCache,
  });

  final TunnelMode group;
  final List<ServerNode> servers;
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final chosen = ref.watch(chosenServerProvider(group));
    final tappable = ref.watch(serverTapsEnabledProvider);
    final choice = ref.read(serverChoiceProvider);
    final pings = ref.watch(
      pingControllerProvider.select((state) => state.pings),
    );
    return Column(
      children: [
        if (fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: StatusBanner(
              kind: BannerKind.warning,
              text: strings.profileFromCache,
            ),
          ),
        if (servers.isEmpty)
          EmptyState(icon: Icons.dns_outlined, title: strings.serversEmpty)
        else
          for (final server in servers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs / 2),
              child: ServerTile(
                title: server.name,
                subtitle: switch (server.protocol) {
                  ServerProtocol.vlessReality => strings.protocolVlessReality,
                  ServerProtocol.hysteria2 => strings.protocolHysteria2,
                },
                countryCode: server.countryCode,
                ping: pingValueOf(pings[server.id]),
                selected: server.id == chosen,
                onTap: tappable ? () => choice.choose(group, server.id) : null,
              ),
            ),
      ],
    );
  }
}
