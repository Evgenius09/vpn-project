import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../gen/l10n/app_localizations.dart';
import '../ui/ui.dart';
import '../features/settings/application/local_settings.dart';
import '../gen/api/export.dart';
import 'home_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<bool>(ref.read(sessionProvider));
  // A session that ends goes to login, not to the free mode of a first start.
  var signedOut = false;
  ref
    ..listen(sessionProvider, (_, signedIn) {
      signedOut = !signedIn;
      session.value = signedIn;
    })
    ..onDispose(session.dispose);

  final router = GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: session,
    redirect: (_, state) => redirectFor(
      state.matchedLocation,
      signedIn: session.value,
      signedOut: signedOut,
    ),
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
    // Screens outside home wear the accent of the mode screen they came from.
    final accent = ref.watch(homePageProvider) == TunnelMode.whitelist.index
        ? AccentKind.whitelist
        : AccentKind.regular;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // The design is dark only (tech.md 43).
      theme: AppTheme.dark(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: ThemeMode.dark,
      locale: switch (ref.watch(
        localSettingsProvider.select((settings) => settings.language),
      )) {
        LanguageChoice.ru => const Locale('ru'),
        LanguageChoice.en => const Locale('en'),
        LanguageChoice.system => null,
      },
      themeAnimationDuration: AppDurations.slow,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
