import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/whitelist/presentation/mode_screen_keys.dart';
import 'package:vpnclient/ui/ui.dart';

import '../../helpers.dart';

/// Three screens, so a key handled twice would skip one.
Future<List<int>> _pump(WidgetTester tester) async {
  final changes = <int>[];
  var index = 0;
  await tester.pumpWidget(
    harness(
      StatefulBuilder(
        builder: (context, setState) {
          void show(int value) {
            changes.add(value);
            setState(() => index = value);
          }

          return ModeScreenKeys(
            index: index,
            count: 3,
            onChanged: show,
            child: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('outside')),
                SizedBox(
                  height: 200,
                  child: ModePager(
                    index: index,
                    onChanged: show,
                    pages: const [
                      ModePage(title: 'a', child: Text('A')),
                      ModePage(title: 'b', child: Text('B')),
                      ModePage(title: 'c', child: Text('C')),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('steps one screen from focus outside the pager', (tester) async {
    final changes = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextButton>(),
      isNotNull,
      reason: 'focus on the button above the pager',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(changes, isEmpty, reason: 'already on the first screen');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, [1, 2], reason: 'stops at the last screen');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(changes, [1, 2, 1]);
  });

  testWidgets('leaves keys inside the pager to the pager', (tester) async {
    final changes = await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, [1], reason: 'one step, not two');
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('ignores other keys', (tester) async {
    final changes = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });
}
