// Windows renders text differently, so goldens run on ubuntu only (tech.md
// 19.4). Regenerate with: flutter test --update-goldens test/ui/goldens_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/app/showcases.dart';
import 'package:vpnclient/ui/ui.dart';

import '../helpers.dart';

void main() {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  for (final showcase in showcases) {
    for (final theme in themes.entries) {
      testWidgets('${showcase.name} ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(420, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness(
            RepaintBoundary(
              key: const Key('showcase'),
              child: Builder(builder: showcase.build),
            ),
            theme: theme.value,
          ),
        );
        // A fixed pump, because progress indicators never settle.
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byKey(const Key('showcase')),
          matchesGoldenFile('goldens/${showcase.name}_${theme.key}.png'),
        );
      });
    }
  }
}
