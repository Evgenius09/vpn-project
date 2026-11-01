import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/desktop/window.dart';
import 'core/providers.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDesktopWindow();

  final tokens = SecureTokenStore();
  final token = await tokens.read();

  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        initialTokenProvider.overrideWithValue(token),
      ],
      child: const VpnClientApp(),
    ),
  );
}
