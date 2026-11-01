import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/app/showcases.dart';
import 'package:vpnclient/ui/ui.dart';

import '../helpers.dart';

void main() {
  group('PowerButton', () {
    testWidgets('fires on tap', (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        PowerButton(state: PowerState.idle, onPressed: () => taps++),
      );
      await tester.tap(find.byType(PowerButton));
      expect(taps, 1);
    });

    testWidgets('fires from the keyboard', (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        PowerButton(state: PowerState.idle, onPressed: () => taps++),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('shows progress only while busy', (tester) async {
      for (final state in PowerState.values) {
        await pumpHarness(tester, PowerButton(state: state, onPressed: null));
        final busy =
            state == PowerState.connecting || state == PowerState.disconnecting;
        expect(
          find.byType(CircularProgressIndicator),
          busy ? findsOneWidget : findsNothing,
          reason: state.name,
        );
      }
    });
  });

  group('ModePager', () {
    Future<List<int>> pumpPager(WidgetTester tester, {int index = 0}) async {
      final changes = <int>[];
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 300,
            child: StatefulBuilder(
              builder: (context, setState) => ModePager(
                index: index,
                onChanged: (value) {
                  changes.add(value);
                  setState(() => index = value);
                },
                pages: const [
                  ModePage(title: 'a', child: Text('A')),
                  ModePage(title: 'b', child: Text('B')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return changes;
    }

    testWidgets('a touch swipe changes the page', (tester) async {
      final changes = await pumpPager(tester);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(changes, [1]);
    });

    testWidgets('a mouse drag changes the page', (tester) async {
      final changes = await pumpPager(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-500, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(changes, [1]);
    });

    testWidgets('the arrow keys change the page and stop at the ends', (
      tester,
    ) async {
      final changes = await pumpPager(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes, isEmpty, reason: 'already on the first page');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes, [1]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes, [1], reason: 'already on the last page');
    });

    testWidgets('a new index animates without reporting back', (tester) async {
      final changes = <int>[];
      Widget build(int index) => harness(
        SizedBox(
          height: 300,
          child: ModePager(
            index: index,
            onChanged: changes.add,
            pages: const [
              ModePage(title: 'a', child: Text('A')),
              ModePage(title: 'b', child: Text('B')),
            ],
          ),
        ),
      );
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(changes, isEmpty, reason: 'the parent already knows the index');
    });
  });

  group('PageDots', () {
    testWidgets('reports the tapped dot', (tester) async {
      int? tapped;
      await pumpHarness(
        tester,
        PageDots(count: 3, index: 0, onTap: (value) => tapped = value),
      );
      await tester.tap(find.byType(InkWell).at(2));
      expect(tapped, 2);
    });
  });

  group('PingBadge', () {
    testWidgets('renders each value', (tester) async {
      Future<void> check(PingValue value, Finder expected) async {
        await pumpHarness(tester, PingBadge(value: value));
        expect(expected, findsOneWidget);
      }

      await check(const PingValue.ms(42), find.text('42 ms'));
      await check(const PingValue.unknown(), find.text('—'));
      await check(const PingValue.unreachable(), find.text('Unreachable'));
      await check(
        const PingValue.measuring(),
        find.byType(CircularProgressIndicator),
      );
    });
  });

  group('FlagIcon', () {
    testWidgets('builds an emoji from the country code', (tester) async {
      await pumpHarness(tester, const FlagIcon(countryCode: 'de'));
      expect(find.text('🇩🇪'), findsOneWidget);
    });

    testWidgets('falls back on a bad code', (tester) async {
      await pumpHarness(tester, const FlagIcon(countryCode: 'x'));
      expect(find.byIcon(Icons.public), findsOneWidget);
    });
  });

  group('TrafficCounter', () {
    testWidgets('picks the unit', (tester) async {
      await pumpHarness(
        tester,
        const TrafficCounter(upBps: 512, downBps: 1536000),
      );
      expect(find.text('512 B/s'), findsOneWidget);
      expect(find.text('1.5 MB/s'), findsOneWidget);
    });
  });

  group('CodeInput', () {
    testWidgets('completes on the last digit', (tester) async {
      final completed = <String>[];
      await pumpHarness(tester, CodeInput(onCompleted: completed.add));
      await tester.enterText(find.byType(TextField), '12345');
      expect(completed, isEmpty);
      await tester.enterText(find.byType(TextField), '123456');
      expect(completed, ['123456']);
    });

    testWidgets('accepts a pasted code with separators', (tester) async {
      final completed = <String>[];
      await pumpHarness(tester, CodeInput(onCompleted: completed.add));
      await tester.enterText(find.byType(TextField), '12 34 56');
      expect(completed, ['123456']);
    });

    testWidgets('drops everything past the length', (tester) async {
      final completed = <String>[];
      await pumpHarness(tester, CodeInput(onCompleted: completed.add));
      await tester.enterText(find.byType(TextField), '1234567890');
      expect(completed, ['123456']);
    });

    testWidgets('shows the error', (tester) async {
      await pumpHarness(
        tester,
        CodeInput(onCompleted: (_) {}, errorText: 'Wrong'),
      );
      expect(find.text('Wrong'), findsOneWidget);
    });
  });

  group('locked settings', () {
    testWidgets('a toggle ignores taps and shows why', (tester) async {
      var changes = 0;
      await pumpHarness(
        tester,
        SettingsToggleTile(
          title: 'T',
          value: true,
          onChanged: (_) => changes++,
          locked: true,
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.tap(find.text('T'));
      expect(changes, 0);
      expect(find.text('Set by provider'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('a select does not open', (tester) async {
      await pumpHarness(
        tester,
        SettingsSelectTile<int>(
          title: 'S',
          value: 1,
          options: const [SelectOption(value: 1, label: 'One')],
          onChanged: (_) {},
          locked: true,
        ),
      );
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing);
    });

    testWidgets('an input does not open', (tester) async {
      await pumpHarness(
        tester,
        SettingsInputTile(
          title: 'I',
          value: 'v',
          onSubmitted: (_) {},
          locked: true,
        ),
      );
      await tester.tap(find.text('I'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('settings tiles', () {
    testWidgets('a toggle flips', (tester) async {
      bool? value;
      await pumpHarness(
        tester,
        SettingsToggleTile(
          title: 'T',
          value: false,
          onChanged: (next) => value = next,
        ),
      );
      await tester.tap(find.text('T'));
      expect(value, isTrue);
    });

    testWidgets('a select reports the choice', (tester) async {
      int? chosen;
      await pumpHarness(
        tester,
        SettingsSelectTile<int>(
          title: 'S',
          value: 1,
          options: const [
            SelectOption(value: 1, label: 'One'),
            SelectOption(value: 2, label: 'Two'),
          ],
          onChanged: (value) => chosen = value,
        ),
      );
      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(chosen, 2);
    });

    testWidgets('an input validates before it submits', (tester) async {
      String? submitted;
      await pumpHarness(
        tester,
        SettingsInputTile(
          title: 'I',
          value: '1500',
          validator: (value) => value == 'bad' ? 'Invalid' : null,
          onSubmitted: (value) => submitted = value,
        ),
      );
      await tester.tap(find.text('I'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bad');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid'), findsOneWidget);
      expect(submitted, isNull);

      await tester.enterText(find.byType(TextField), '1400');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted, '1400');
    });
  });

  group('AppButton', () {
    testWidgets('ignores taps while loading', (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        AppButton(label: 'B', onPressed: () => taps++, loading: true),
      );
      await tester.tap(find.text('B'));
      expect(taps, 0);
    });
  });

  group('AppDialog.confirm', () {
    Future<bool?> open(WidgetTester tester, String button) async {
      bool? result;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => AppButton(
              label: 'open',
              onPressed: () async {
                result = await AppDialog.confirm(
                  context,
                  title: 'T',
                  message: 'M',
                  confirmLabel: 'Yes',
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns true on confirm', (tester) async {
      expect(await open(tester, 'Yes'), isTrue);
    });

    testWidgets('returns false on cancel', (tester) async {
      expect(await open(tester, 'Cancel'), isFalse);
    });
  });

  group('AppSnack', () {
    testWidgets('shows the text', (tester) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => AppButton(
              label: 'open',
              onPressed: () => AppSnack.show(context, text: 'Saved'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
    });
  });

  testWidgets('ErrorView retries', (tester) async {
    var retries = 0;
    await pumpHarness(
      tester,
      ErrorView(error: 'Failed', onRetry: () => retries++),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('AppShell limits the width of its content', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppShell(child: SizedBox.expand(key: Key('content'))),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('content'))).width,
      AppLayout.maxContentWidth,
    );
  });

  test('tokens match the contract', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
    expect(
      [AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.pill],
      [8, 12, 20, 999],
    );
    expect(AppDurations.fast, const Duration(milliseconds: 150));
    expect(AppDurations.normal, const Duration(milliseconds: 250));
    expect(AppDurations.slow, const Duration(milliseconds: 400));
    expect(AppLayout.maxContentWidth, 480);
  });

  test('the gallery covers every primitive of tech.md 8', () {
    expect(
      showcases.map((showcase) => showcase.name).toSet(),
      containsAll([
        'power_button',
        'mode_pager',
        'page_dots',
        'server_sheet',
        'server_tile',
        'ping_badge',
        'flag_icon',
        'status_banner',
        'traffic_counter',
        'code_input',
        'settings_section',
        'settings_toggle_tile',
        'settings_select_tile',
        'settings_nav_tile',
        'settings_input_tile',
        'app_button',
        'app_text_field',
        'empty_state',
        'loading_view',
        'error_view',
      ]),
    );
  });
}
