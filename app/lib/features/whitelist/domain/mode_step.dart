/// One step between the mode screens, as the arrow keys ask for it.
enum ModeStep { previous, next }

/// The screen [step] leads to from [index] out of [count] screens. The first
/// and last screens stay put rather than wrap, like a swipe at the edge.
int screenAfter(ModeStep step, {required int index, required int count}) {
  final target = switch (step) {
    ModeStep.previous => index - 1,
    ModeStep.next => index + 1,
  };
  return target.clamp(0, count - 1);
}
