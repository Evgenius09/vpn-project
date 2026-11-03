import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/whitelist/domain/mode_step.dart';

/// A pager position: a screen count of 1 to 8 and a screen within it.
extension on Any {
  Generator<(int, int)> get position => any
      .intInRange(1, 9)
      .bind((count) => any.intInRange(0, count).map((index) => (index, count)));
}

void main() {
  Glados(any.position).test('a step stays on the screens', (position) {
    final (index, count) = position;
    for (final step in ModeStep.values) {
      final next = screenAfter(step, index: index, count: count);
      expect(next, inInclusiveRange(0, count - 1), reason: '$step');
      expect((next - index).abs(), lessThanOrEqualTo(1), reason: '$step');
    }
  });

  Glados(any.position)
      .test('next moves right and stops at the last', (position) {
        final (index, count) = position;
        final next = screenAfter(ModeStep.next, index: index, count: count);
        expect(next, index == count - 1 ? index : index + 1);
      });

  Glados(any.position).test('previous moves left and stops at the first', (
    position,
  ) {
    final (index, count) = position;
    final previous = screenAfter(ModeStep.previous, index: index, count: count);
    expect(previous, index == 0 ? 0 : index - 1);
  });

  Glados(any.position).test('previous undoes next away from the last', (
    position,
  ) {
    final (index, count) = position;
    if (index == count - 1) {
      return;
    }
    final next = screenAfter(ModeStep.next, index: index, count: count);
    expect(screenAfter(ModeStep.previous, index: next, count: count), index);
  });
}
