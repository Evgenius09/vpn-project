import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/auth/presentation/settings_screen.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import '../connection/connection_harness.dart';

// Acceptance of S2-01 (tech.md 16, 2.1, 28.1): the second mode screen lists
// the whitelist servers, and a swipe, a mouse drag, a click on PageDots, and
// the arrow keys only switch the screen.

const _regularNames = ['Frankfurt', 'Amsterdam', 'Helsinki'];
const _whitelistNames = ['Moscow', 'Saint Petersburg'];

int _shownIndex(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

/// The page the pager settled on, read from the screen title it shows. The
/// ModeSwitch under the pager names both modes, so only the pager counts.
TunnelMode _shownScreen(WidgetTester tester) {
  Finder title(String text) => find
      .descendant(of: find.byType(ModePager), matching: find.text(text))
      .hitTestable();
  final regular = title('Regular VPN');
  final whitelist = title('Whitelists');
  final onRegular = regular.evaluate().isNotEmpty;
  final onWhitelist = whitelist.evaluate().isNotEmpty;
  expect(onRegular != onWhitelist, isTrue, reason: 'exactly one screen');
  final mode = onRegular ? TunnelMode.regular : TunnelMode.whitelist;
  expect(_shownIndex(tester), mode.index, reason: 'dots follow the page');
  return mode;
}

/// Waits out the page animation. A ping or connection spinner never
/// settles, so pumpAndSettle is not an option once the tunnel runs.
Future<void> _animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDurations.normal * 2);
}

Future<void> _swipe(WidgetTester tester, Offset by) async {
  await tester.drag(find.byType(PageView), by);
  await _animate(tester);
}

/// Drags with a mouse from the PowerButton, a control that also takes clicks.
Future<void> _mouseDrag(WidgetTester tester, Offset by) async {
  await tester.drag(
    find.byType(PowerButton).hitTestable(),
    by,
    kind: PointerDeviceKind.mouse,
  );
  await _animate(tester);
}

Future<void> _clickDot(WidgetTester tester, int index) async {
  final dots = find.descendant(
    of: find.byType(PageDots),
    matching: find.byType(InkWell),
  );
  final gesture = await tester.startGesture(
    tester.getCenter(dots.at(index)),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await _animate(tester);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _animate(tester);
}

List<String> _tileTitles(WidgetTester tester) => [
  for (final tile in tester.widgetList<ServerTile>(find.byType(ServerTile)))
    tile.title,
];

/// Pulls the sheet up so every tile is built.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.drag(find.text('Servers').hitTestable(), const Offset(0, -400));
  await _animate(tester);
}

/// Tabs until the keyboard focus sits inside [target].
Future<void> _tabTo(WidgetTester tester, Finder target) async {
  bool focused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    final inside = find.descendant(
      of: target,
      matching: find.byElementPredicate((element) => element == context),
      matchRoot: true,
    );
    return inside.evaluate().isNotEmpty;
  }

  for (var i = 0; i < 20 && !focused(); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(focused(), isTrue, reason: 'Tab reaches $target');
}

void main() {
  group('the whitelist screen', () {
    testWidgets('lists only the whitelist servers', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _swipe(tester, const Offset(-500, 0));
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _openSheet(tester);

      expect(_tileTitles(tester), _whitelistNames);
      for (final name in _regularNames) {
        expect(find.text(name), findsNothing, reason: name);
      }
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('shows the empty state without whitelist servers', (
      tester,
    ) async {
      final app = ConnectionHarness(
        profile: profileWithout(TunnelMode.whitelist),
      );
      await app.pump(tester);
      await _openSheet(tester);
      expect(_tileTitles(tester), _regularNames, reason: 'regular unaffected');

      await _swipe(tester, const Offset(-500, 0));
      await _openSheet(tester);

      expect(_shownScreen(tester), TunnelMode.whitelist);
      expect(find.byType(EmptyState).hitTestable(), findsOneWidget);
      expect(find.text('No servers yet'), findsOneWidget);
      expect(find.byType(ServerTile), findsNothing);
      expect(app.taps, isEmpty);
    });

    testWidgets('keeps its own PowerButton', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _swipe(tester, const Offset(-500, 0));

      expect(find.byType(PowerButton).hitTestable(), findsOneWidget);
      expect(powerButton(tester).state, PowerState.idle);
    });
  });

  group('switching screens leaves the tunnel alone', () {
    // The harness checks that launch made exactly one getState call, so any
    // later bridge call shows up in app.taps.

    testWidgets('a touch swipe both ways', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      await _swipe(tester, const Offset(-500, 0));
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _swipe(tester, const Offset(500, 0));
      expect(_shownScreen(tester), TunnelMode.regular);

      expect(app.taps, isEmpty);
    });

    testWidgets('a mouse drag both ways', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      await _mouseDrag(tester, const Offset(-500, 0));
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _mouseDrag(tester, const Offset(500, 0));
      expect(_shownScreen(tester), TunnelMode.regular);

      expect(app.taps, isEmpty);
    });

    testWidgets('a click on each dot', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      await _clickDot(tester, 1);
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _clickDot(tester, 1);
      expect(_shownScreen(tester), TunnelMode.whitelist, reason: 'same dot');
      await _clickDot(tester, 0);
      expect(_shownScreen(tester), TunnelMode.regular);

      expect(app.taps, isEmpty);
    });

    testWidgets('a tap on each ModeSwitch segment', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      Future<void> tapSegment(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(ModeSwitch),
            matching: find.text(label),
          ),
        );
        await _animate(tester);
      }

      await tapSegment('Whitelists');
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await tapSegment('Whitelists');
      expect(_shownScreen(tester), TunnelMode.whitelist, reason: 'same one');
      await tapSegment('Regular VPN');
      expect(_shownScreen(tester), TunnelMode.regular);

      expect(app.taps, isEmpty);
    });

    testWidgets('a tap on the ModeSwitch while connected', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await app.emitState(tester, TunnelStatus.connected);
      final before = app.taps.length;
      await tester.tap(
        find.descendant(
          of: find.byType(ModeSwitch),
          matching: find.text('Whitelists'),
        ),
      );
      await _animate(tester);
      expect(_shownScreen(tester), TunnelMode.whitelist);
      expect(app.taps, hasLength(before));
    });

    testWidgets('the arrow keys, stopping at the ends', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_shownScreen(tester), TunnelMode.regular, reason: 'first page');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist, reason: 'last page');
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_shownScreen(tester), TunnelMode.regular);

      expect(app.taps, isEmpty);
    });

    for (final status in [
      TunnelStatus.connected,
      TunnelStatus.connecting,
      TunnelStatus.disconnecting,
    ]) {
      testWidgets('every input while ${status.json}', (tester) async {
        final app = ConnectionHarness();
        await app.pump(tester);
        await app.emitState(tester, status);

        await _swipe(tester, const Offset(-500, 0));
        await _swipe(tester, const Offset(500, 0));
        await _mouseDrag(tester, const Offset(-500, 0));
        await _clickDot(tester, 0);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_shownScreen(tester), TunnelMode.whitelist);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(_shownScreen(tester), TunnelMode.regular);

        expect(app.taps, isEmpty);
      });
    }
  });

  group('the arrow keys keep working', () {
    testWidgets('after Tab moves focus through the screen', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      // Walk focus over the settings button, the dots, and the screen
      // controls; the arrows must switch screens from every stop.
      for (var stop = 0; stop < 12; stop++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.toString();

        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(
          _shownScreen(tester),
          TunnelMode.whitelist,
          reason: 'focus stop $stop: $focused',
        );
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(
          _shownScreen(tester),
          TunnelMode.regular,
          reason: 'focus stop $stop: $focused',
        );
      }
      expect(app.taps, isEmpty);
    });

    testWidgets('with focus on the settings button', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _tabTo(tester, find.widgetWithIcon(IconButton, Icons.settings));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist, reason: 'last page');
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_shownScreen(tester), TunnelMode.regular);
      expect(app.taps, isEmpty);
    });

    testWidgets('with focus on a dot', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _tabTo(
        tester,
        find
            .descendant(
              of: find.byType(PageDots),
              matching: find.byType(InkWell),
            )
            .at(1),
      );

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_shownScreen(tester), TunnelMode.regular);
      expect(app.taps, isEmpty);
    });

    testWidgets('after a click on a dot', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);

      await _clickDot(tester, 1);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_shownScreen(tester), TunnelMode.regular);
      expect(app.taps, isEmpty);
    });

    testWidgets('after a server is chosen', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await _openSheet(tester);
      await tester.tap(find.widgetWithText(ServerTile, 'Amsterdam').first);
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_shownScreen(tester), TunnelMode.whitelist);
    });

    testWidgets('after a return from settings', (tester) async {
      final app = ConnectionHarness();
      await app.pump(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowRight);

      expect(_shownScreen(tester), TunnelMode.whitelist);
      expect(app.taps, isEmpty);
    });
  });
}
