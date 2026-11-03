final _usernamePattern = RegExp(r'^[a-z0-9_]{4,32}$');

/// Normalizes a Telegram nick the way the backend does (tech.md 5.2, 19.9):
/// without the leading @, in lower case. Returns null for a nick the backend
/// would reject, so the screen can say so without a request.
String? normalizeUsername(String raw) {
  final trimmed = raw.trim();
  final bare = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  final username = bare.toLowerCase();
  return _usernamePattern.hasMatch(username) ? username : null;
}
