import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/auth/domain/username.dart';

const _allowed =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';

void main() {
  test('strips the @ and lowers the case', () {
    expect(normalizeUsername('@Seed_User'), 'seed_user');
    expect(normalizeUsername('seed_user'), 'seed_user');
    expect(normalizeUsername('  @seed_user  '), 'seed_user');
  });

  test('accepts the 4 to 32 characters tech.md 19.9 allows', () {
    expect(normalizeUsername('abcd'), 'abcd');
    expect(normalizeUsername('a' * 32), 'a' * 32);
    expect(normalizeUsername('abc'), isNull);
    expect(normalizeUsername('a' * 33), isNull);
  });

  test('rejects anything outside Latin letters, digits, and underscores', () {
    expect(normalizeUsername('seed-user'), isNull);
    expect(normalizeUsername('seed user'), isNull);
    expect(normalizeUsername('сид_юзер'), isNull);
    expect(normalizeUsername('@@seed_user'), isNull);
    expect(normalizeUsername(''), isNull);
  });

  Glados2<String, bool>(any.stringOf(_allowed), any.bool).test(
    'a valid nick normalizes to its lowercase form, with or without @',
    (raw, at) {
      final input = at ? '@$raw' : raw;
      final normalized = normalizeUsername(input);
      final validLength = raw.length >= 4 && raw.length <= 32;
      expect(normalized, validLength ? raw.toLowerCase() : isNull);
    },
  );

  Glados<String>(any.stringOf(_allowed))
      .test('normalizing is idempotent', (raw) {
        final once = normalizeUsername(raw);
        if (once != null) {
          expect(normalizeUsername(once), once);
        }
      });

  Glados2<String, int>(any.stringOf(_allowed), any.intInRange(0, 40)).test(
    'one foreign character makes the nick invalid',
    (raw, position) {
      final at = raw.isEmpty ? 0 : position % (raw.length + 1);
      final broken = '${raw.substring(0, at)}-${raw.substring(at)}';
      expect(normalizeUsername(broken), isNull);
    },
  );
}
