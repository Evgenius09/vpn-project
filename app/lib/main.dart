import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/desktop/window.dart';
import 'core/providers.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDesktopWindow();

  final config = AppConfig.fromEnvironment();
  final tokens = SecureTokenStore();
  if (config.devToken.isNotEmpty) {
    await tokens.write(config.devToken);
  }
  final token = await tokens.read();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        tokenStoreProvider.overrideWithValue(tokens),
        initialTokenProvider.overrideWithValue(token),
      ],
      child: const VpnClientApp(),
    ),
  );
}
