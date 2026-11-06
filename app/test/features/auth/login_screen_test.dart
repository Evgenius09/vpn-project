import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/providers.dart';
import 'package:vpnclient/features/auth/presentation/login_screen.dart';
import 'package:vpnclient/gen/api/export.dart';
import 'package:vpnclient/ui/ui.dart';

import 'auth_harness.dart';

void main() {
  group('nick step', () {
    testWidgets('a guest lands on the nick field with an @ prefix', (
      tester,
    ) async {
      await AuthHarness().pumpLogin(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      final field = tester.widget<AppTextField>(find.byType(AppTextField));
      expect(field.prefixText, '@');
    });

    testWidgets('a malformed nick is refused before any request', (
      tester,
    ) async {
      final harness = AuthHarness();
      await harness.pumpLogin(tester);

      await enterUsername(tester, 'ab-c');

      expect(harness.api.starts, isEmpty);
      expect(
        find.text('Use 4 to 32 Latin letters, digits, or underscores'),
        findsOneWidget,
      );
    });

    testWidgets('a nick sends the normalized name and opens the code step', (
      tester,
    ) async {
      final harness = AuthHarness();
      await harness.pumpLogin(tester);

      await enterUsername(tester, '@Seed_User');

      final sent = harness.api.starts.single;
      expect(sent.username, 'seed_user');
      expect(sent.installId, testIdentity.installId);
      expect(sent.model, testIdentity.model);
      expect(find.byType(CodeInput), findsOneWidget);
      expect(find.textContaining('@seed_user'), findsOneWidget);
    });

    testWidgets('a rate limit shows the wait', (tester) async {
      final harness = AuthHarness();
      harness.api.authFailure = const ApiProblem(
        429,
        ProblemCode.rateLimited,
        retryAfterSec: 42,
      );
      await harness.pumpLogin(tester);

      await enterUsername(tester, 'seed_user');

      expect(
        find.text('Too many attempts. Try again in 42 s.'),
        findsOneWidget,
      );
      expect(find.byType(CodeInput), findsNothing);
    });

    testWidgets('an outage shows its text and keeps the nick', (tester) async {
      final harness = AuthHarness();
      harness.api.authFailure = const ApiUnavailable();
      await harness.pumpLogin(tester);

      await enterUsername(tester, 'seed_user');

      expect(
        find.text(
          'No connection to the server. Check the internet and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('seed_user'), findsOneWidget);
    });
  });

  group('bot not started', () {
    Future<AuthHarness> notFound(WidgetTester tester) async {
      final harness = AuthHarness();
      harness.api.authFailure = const ApiProblem(
        404,
        ProblemCode.telegramUserNotFound,
        botUrl: 'https://t.me/vpnclient_bot?start=login',
      );
      await harness.pumpLogin(tester);
      await enterUsername(tester, 'seed_user');
      return harness;
    }

    testWidgets('an unknown nick asks to open the bot and press Start', (
      tester,
    ) async {
      await notFound(tester);

      expect(find.text('Open the bot'), findsOneWidget);
      expect(find.byType(CodeInput), findsNothing);
    });

    testWidgets('the link opens the bot from the problem', (tester) async {
      final harness = await notFound(tester);

      await tester.tap(find.text('Open bot'));
      await tester.pumpAndSettle();

      expect(harness.opened, [
        Uri.parse('https://t.me/vpnclient_bot?start=login'),
      ]);
    });

    testWidgets('"I pressed Start" requests the code again', (tester) async {
      final harness = await notFound(tester);
      harness.api.authFailure = null;

      await tester.tap(find.text('I pressed Start, send the code'));
      await tester.pumpAndSettle();

      expect(harness.api.starts, hasLength(2));
      expect(harness.api.starts.last.username, 'seed_user');
      expect(find.byType(CodeInput), findsOneWidget);
    });

    testWidgets('a failed link shows an error', (tester) async {
      final harness = await notFound(tester);
      harness.openSucceeds = false;

      await tester.tap(find.text('Open bot'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the link'), findsOneWidget);
    });
  });

  group('code step', () {
    Future<AuthHarness> atCode(WidgetTester tester) async {
      final harness = AuthHarness();
      await harness.pumpLogin(tester);
      await enterUsername(tester, 'seed_user');
      return harness;
    }

    testWidgets('resend waits for the timer from the challenge', (
      tester,
    ) async {
      final harness = await atCode(tester);

      expect(find.text('Send the code again in 1:00'), findsOneWidget);
      await tester.tap(find.text('Send the code again in 1:00'));
      await tester.pump();
      expect(harness.api.starts, hasLength(1));

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Send the code again in 0:01'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Send the code again'));
      await tester.pumpAndSettle();

      expect(harness.api.starts, hasLength(2));
      expect(find.text('Send the code again in 1:00'), findsOneWidget);
    });

    testWidgets('a rate limited resend restarts the timer', (tester) async {
      final harness = await atCode(tester);
      await tester.pump(const Duration(seconds: 60));
      harness.api.authFailure = const ApiProblem(
        429,
        ProblemCode.rateLimited,
        retryAfterSec: 30,
      );

      await tester.tap(find.text('Send the code again'));
      await tester.pumpAndSettle();

      expect(find.text('Send the code again in 0:30'), findsOneWidget);
      expect(find.byType(CodeInput), findsOneWidget);
    });

    testWidgets('Open bot uses the link from the challenge', (tester) async {
      final harness = await atCode(tester);

      await tester.ensureVisible(find.text('Open bot'));
      await tester.tap(find.text('Open bot'));
      await tester.pumpAndSettle();

      expect(harness.opened, [Uri.parse('https://t.me/vpnclient_bot')]);
    });

    testWidgets('the code becomes a stored token and opens the home screen', (
      tester,
    ) async {
      final harness = await atCode(tester);

      await enterCode(tester, '123456');

      final sent = harness.api.verifies.single;
      expect(sent.code, '123456');
      expect(sent.loginId, '00000000-0000-4000-8000-000000000001');
      expect(sent.installId, testIdentity.installId);
      expect(sent.platform, Platform.windows);
      expect(sent.model, testIdentity.model);
      expect(sent.appVersion, appVersion);
      expect(await harness.tokens.read(), 'fake-device-token');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ModePager), findsOneWidget);
    });

    // The design keeps the wrong digits on screen, painted red.
    testWidgets('a wrong code shows the attempts left and keeps the digits', (
      tester,
    ) async {
      final harness = await atCode(tester);
      harness.api.authFailure = const ApiProblem(
        400,
        ProblemCode.codeInvalid,
        attemptsLeft: 4,
      );

      await enterCode(tester, '000000');

      expect(find.text('Wrong code. Attempts left: 4.'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '000000');
      expect(await harness.tokens.read(), isNull);

      harness.api.authFailure = null;
      await enterCode(tester, '123456');
      expect(find.byType(ModePager), findsOneWidget);
    });

    testWidgets('an expired code asks for a new one', (tester) async {
      final harness = await atCode(tester);
      harness.api.authFailure = const ApiProblem(410, ProblemCode.codeExpired);

      await enterCode(tester, '123456');

      expect(
        find.text(
          'The code has expired or the attempts ran out. Request a new code.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the device limit keeps the code step for a retry', (
      tester,
    ) async {
      final harness = await atCode(tester);
      harness.api.authFailure = const ApiProblem(
        409,
        ProblemCode.deviceLimitReached,
      );

      await enterCode(tester, '123456');

      expect(
        find.text(
          'Your account has reached its device limit. Disconnect another '
          'device and enter the code again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CodeInput), findsOneWidget);
    });

    testWidgets('Change username returns to the nick with it filled in', (
      tester,
    ) async {
      await atCode(tester);

      await tester.ensureVisible(find.text('Change username'));
      await tester.tap(find.text('Change username'));
      await tester.pumpAndSettle();

      expect(find.byType(CodeInput), findsNothing);
      expect(find.text('seed_user'), findsOneWidget);
    });
  });

  testWidgets('a 401 on the profile returns to the login screen', (
    tester,
  ) async {
    final harness = AuthHarness(token: 'old');
    harness.api.failure = const ApiProblem(401, ProblemCode.deviceRevoked);

    await harness.pump(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await harness.tokens.read(), isNull);
  });

  testWidgets('a login after a 401 loads the profile again', (tester) async {
    final harness = AuthHarness(token: 'old');
    harness.api.failure = const ApiProblem(401, ProblemCode.deviceRevoked);
    await harness.pump(tester);
    harness.api.failure = null;

    await enterUsername(tester, 'seed_user');
    await enterCode(tester, '123456');
    // The header holds the ping controls, so drag it rather than the middle.
    await tester.drag(find.text('Servers').first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byType(ServerTile), findsWidgets);
  });
}
