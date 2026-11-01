// Renders every primitive with the real engine of the platform it runs on,
// which widget tests cannot do (tech.md 15.3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpnclient/app/app.dart';
import 'package:vpnclient/app/kitchen_sink.dart';
import 'package:vpnclient/app/routes.dart';
import 'package:vpnclient/app/showcases.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/core/storage/token_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the kitchen sink renders every primitive', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
        child: const VpnClientApp(),
      ),
    );
    await tester.pump();
    ProviderScope.containerOf(tester.element(find.byType(VpnClientApp)))
        .read(routerProvider)
        .go(RoutePaths.kitchenSink);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(KitchenSinkScreen), findsOneWidget);

    for (final theme in [
      'Тёмная тема',
      'Светлая тема',
      'Dark theme',
      'Light theme',
    ]) {
      final tab = find.text(theme);
      if (tab.evaluate().isEmpty) {
        continue;
      }
      await tester.tap(tab);
      await tester.pump(const Duration(seconds: 1));
      final list = find.byType(Scrollable).last;
      for (final showcase in showcases) {
        await tester.scrollUntilVisible(
          find.text(showcase.name),
          200,
          scrollable: list,
        );
        expect(tester.takeException(), isNull, reason: showcase.name);
      }
    }
  });
}
