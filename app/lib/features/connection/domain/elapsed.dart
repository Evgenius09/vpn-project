/// The connection timer text, hours first: 00:12:31.
String formatElapsed(Duration elapsed) {
  final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:'
      '${two(seconds % 60)}';
}
