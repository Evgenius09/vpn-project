import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen/api/export.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../ui/ui.dart';
import '../application/profile_controller.dart';
import '../domain/profile_state.dart';

/// The read-only server list of one mode screen (tech.md 15.2).
class ServerList extends ConsumerWidget {
  const ServerList({required this.group, super.key});

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
          servers: profile.serversIn(group),
          fromCache: fromCache,
        ),
      },
    );
  }
}

class _Servers extends StatelessWidget {
  const _Servers({required this.servers, required this.fromCache});

  final List<ServerNode> servers;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
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
                ping: const PingValue.unknown(),
                selected: false,
              ),
            ),
      ],
    );
  }
}
