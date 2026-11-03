import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/mode_step.dart';

/// Switches the mode screen with ← and → while the keyboard focus sits on a
/// control around the pager, such as the settings button or a dot. ModePager
/// handles the keys for focus inside its pages and stops them there, so a key
/// never moves two screens. Like a swipe, this never touches the tunnel
/// (tech.md 2.1).
class ModeScreenKeys extends StatelessWidget {
  const ModeScreenKeys({
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  void _step(ModeStep step) {
    final next = screenAfter(step, index: index, count: count);
    if (next != index) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _step(ModeStep.previous),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _step(ModeStep.next),
      },
      child: child,
    );
  }
}
