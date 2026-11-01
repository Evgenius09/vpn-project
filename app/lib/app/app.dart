import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<bool>(ref.read(sessionProvider));
  ref
    ..listen(sessionProvider, (_, signedIn) => session.value = signedIn)
    ..onDispose(session.dispose);

  final router = GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: session,
    redirect: (_, state) =>
        redirectFor(state.matchedLocation, signedIn: session.value),
    routes: [
      for (final route in routesFor())
        GoRoute(
          path: route.path,
          builder: (context, _) => route.build(context),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class VpnClientApp extends ConsumerWidget {
  const VpnClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
