import 'dart:async';

/// Runs [task] for every item with at most [limit] running at once
/// (tech.md 16 S1-12: no more than 8 pings in parallel). A failing task does
/// not stop the others: one bad server must not hide the rest.
Future<void> forEachBounded<T>(
  Iterable<T> items,
  int limit,
  Future<void> Function(T item) task,
) async {
  final queue = items.iterator;
  Future<void> worker() async {
    while (queue.moveNext()) {
      try {
        await task(queue.current);
      } on Object {
        continue;
      }
    }
  }

  // Each worker takes the next item when its task ends, so no more than
  // [limit] tasks ever run together.
  await Future.wait([for (var i = 0; i < limit; i++) worker()]);
}
