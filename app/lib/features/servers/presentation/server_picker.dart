import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile_state.dart';
import '../application/selection_controller.dart';
import '../application/server_choice.dart';
import '../domain/server_selection.dart';

/// The servers of one mode screen with the chosen one highlighted. A tap
/// chooses a server for this group (tech.md 16 S1-09, 28).
class ServerPicker extends ConsumerWidget {
  const ServerPicker({required this.group, super.key});

  final TunnelMode group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final state = ref.watch(profileControllerProvider);
    return ServerSheet(
      header: Align(
        alignment: Alignment.centerLeft,
        child: Text(strings.serversTitle, style: AppText.title),
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
        ProfileReady(:final profile, :final fromCache) => _Servers(
          group: group,
          servers: serversOf(profile.servers, group),
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
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ServerTile(
                title: server.name,
                subtitle: server.city,
                countryCode: server.countryCode,
                // S1-12 measures the ping.
                ping: const PingValue.unknown(),
                selected: server.id == chosen,
                onTap: tappable ? () => choice.choose(group, server.id) : null,
              ),
            ),
      ],
    );
  }
}
