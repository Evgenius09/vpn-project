import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/features/auth/domain/login_state.dart';
import 'package:vpnclient/features/auth/presentation/login_error_text.dart';
import 'package:vpnclient/gen/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ru')]) {
    test('every login failure has its own text in $locale', () {
      final strings = lookupAppLocalizations(locale);
      final texts = {
        for (final failure in LoginFailure.values)
          loginErrorText(
            strings,
            LoginError(failure, attemptsLeft: 3, retryAfterSec: 42),
          ),
      };
      // The design gives every outage on the server side one text:
      // no connection, a panel outage, and an internal error.
      final shared = locale.languageCode == 'ru' ? 2 : 0;
      expect(texts, hasLength(LoginFailure.values.length - shared));
      expect(texts.every((text) => text.trim().isNotEmpty), isTrue);
    });

    test('the extras reach the text in $locale', () {
      final strings = lookupAppLocalizations(locale);
      expect(
        loginErrorText(
          strings,
          const LoginError(LoginFailure.codeInvalid, attemptsLeft: 3),
        ),
        contains('3'),
      );
      expect(
        loginErrorText(
          strings,
          const LoginError(LoginFailure.rateLimited, retryAfterSec: 42),
        ),
        contains('42'),
      );
    });

    test('a rate limit without a wait still reads well in $locale', () {
      final strings = lookupAppLocalizations(locale);
      final text = loginErrorText(
        strings,
        const LoginError(LoginFailure.rateLimited),
      );
      expect(text, isNot(contains('null')));
    });
  }
}
