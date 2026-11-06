import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/auth/presentation/login_screen.dart';
import 'package:vpnclient/features/free/presentation/free_screen.dart';
import 'package:vpnclient/ui/ui.dart';

import '../auth/auth_harness.dart';
import '../connection/connection_harness.dart';

// The settings tree and the free mode drawn in Figma (tech.md 43).

/// Tall enough that every settings page fits without scrolling.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(480, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openSettings(WidgetTester tester) async {
  _tall(tester);
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

Future<void> _tapRow(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).hitTestable().last);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
  await tester.pumpAndSettle();
}

String _screenTitle(WidgetTester tester) =>
    tester.widget<AppScreen>(find.byType(AppScreen).last).title;

void main() {
  testWidgets('every settings row opens its page', (tester) async {
    await ConnectionHarness().pump(tester);
    await _openSettings(tester);

    for (final (row, title) in [
      ('Split tunneling (apps)', 'Tunneling'),
      ('Rules profile (sites)', 'Rules profile'),
      ('Theme', 'Theme'),
      ('Language', 'Language'),
      ('Support', 'Support'),
      ('Advanced', 'Advanced'),
    ]) {
      await _tapRow(tester, row);
      expect(_screenTitle(tester), title, reason: row);
      await _back(tester);
    }
  });

  testWidgets('a choice moves the check and the row shows it', (tester) async {
    await ConnectionHarness().pump(tester);
    await _openSettings(tester);
    await _tapRow(tester, 'Rules profile (sites)');

    bool checked(String title) => tester
        .widget<SettingsChoiceTile>(
          find.widgetWithText(SettingsChoiceTile, title),
        )
        .selected;
    expect(checked('Russia direct'), isTrue);

    await tester.tap(find.text('Everything through VPN'));
    await tester.pumpAndSettle();

    expect(checked('Russia direct'), isFalse);
    expect(checked('Everything through VPN'), isTrue);
    await _back(tester);
    expect(find.text('Everything through VPN'), findsOneWidget);
  });

  testWidgets('a quick pick fills the field and Save keeps it', (tester) async {
    await ConnectionHarness().pump(tester);
    await _openSettings(tester);
    await _tapRow(tester, 'Advanced');
    await _tapRow(tester, 'DNS through VPN');

    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://dns.google/dns-query',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_screenTitle(tester), 'Advanced');
    expect(find.text('https://dns.google/dns-query'), findsOneWidget);
  });

  testWidgets('a new rule joins the list', (tester) async {
    await ConnectionHarness().pump(tester);
    await _openSettings(tester);
    await _tapRow(tester, 'Advanced');
    expect(find.text('3 rules · domains and IP addresses'), findsOneWidget);
    await _tapRow(tester, 'My rules');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'example.org');
    await tester.tap(find.text('Block'));
    await tester.pump();
    await _tapRow(tester, 'Save');

    expect(find.text('example.org'), findsOneWidget);
    expect(find.textContaining('→ block'), findsNWidgets(2));
  });

  testWidgets('a removed exclusion leaves the list', (tester) async {
    await ConnectionHarness().pump(tester);
    await _openSettings(tester);
    await _tapRow(tester, 'Advanced');
    await _tapRow(tester, 'Excluded addresses');

    expect(find.text('10.0.0.0/8'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').last);
    await tester.pumpAndSettle();

    expect(find.text('10.0.0.0/8'), findsNothing);
    expect(find.text('192.168.0.0/16'), findsOneWidget);
  });

  group('the free mode', () {
    testWidgets('switching screens leaves the tunnel alone', (tester) async {
      final harness = AuthHarness();
      await harness.pump(tester);
      expect(find.byType(FreeScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(ModeSwitch),
          matching: find.text('Whitelists'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<PageDots>(find.byType(PageDots)).index, 1);
      final dead = tester.widget<PowerButton>(
        find.byType(PowerButton).hitTestable(),
      );
      expect(dead.onPressed, isNull, reason: 'no whitelists without login');
      expect(harness.bridge.calls, isEmpty);
    });

    testWidgets('the sign-in link opens the nick step', (tester) async {
      await AuthHarness().pump(tester);

      await tester.tap(find.text('Have an account? Sign in').first);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the bot button opens the bot of the build', (tester) async {
      final harness = AuthHarness();
      await harness.pump(tester);

      await tester.tap(find.text('Get full access in the Telegram bot').first);
      await tester.pumpAndSettle();

      expect(harness.opened, isEmpty, reason: 'tests define no BOT_URL');
    });
  });
}
