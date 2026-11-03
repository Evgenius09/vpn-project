import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/core/api/api_client.dart';
import 'package:vpnclient/core/device/device_identity.dart';
import 'package:vpnclient/features/auth/data/auth_repository.dart';
import 'package:vpnclient/features/auth/domain/login_state.dart';
import 'package:vpnclient/gen/api/export.dart';

const _loginId = '1f0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f';

const identity = DeviceIdentity(
  platform: Platform.android,
  model: 'samsung SM-A225F',
  installId: '7b0c2f1e-5d0a-4c2b-9f3e-2a1d4c5b6e7f',
);

/// The request schemas of contracts/openapi.yaml, read as plain JSON so the
/// test sees the contract and not the generated model.
Map<String, Object?> _schema(String name) {
  final text = File('../contracts/openapi.yaml').readAsStringSync();
  final start = text.indexOf('    $name:\n');
  final end = text.indexOf(RegExp(r'\n    [A-Za-z]+:\n'), start + 1);
  final block = text.substring(start, end);
  final required = RegExp(r'required: \[([^\]]*)\]').firstMatch(block)!;
  return {
    'required': required
        .group(1)!
        .split(',')
        .map((field) => field.trim())
        .toList(),
  };
}

void main() {
  late FakeApiClient api;
  late AuthRepository repository;

  setUp(() {
    api = FakeApiClient(load: () async => '{}');
    repository = AuthRepository(api, () async => identity, appVersion: '1.2.3');
  });

  test('start sends the nick with the install id and model', () async {
    final challenge = await repository.start('seed_user');

    final sent = api.starts.single;
    expect(sent.username, 'seed_user');
    expect(sent.installId, identity.installId);
    expect(sent.model, identity.model);
    expect(challenge.resendAfterSec, greaterThan(0));
  });

  test('verify sends every field the contract requires', () async {
    final token = await repository.verify(_loginId, '123456');

    final sent = api.verifies.single.toJson();
    expect(token, 'fake-device-token');
    expect(sent, {
      'loginId': _loginId,
      'code': '123456',
      'installId': identity.installId,
      'platform': 'android',
      'model': identity.model,
      'appVersion': '1.2.3',
    });
    final required = _schema('TelegramLoginVerify')['required']! as List;
    expect(sent.keys, containsAll(required));
  });

  test('start covers every field the contract requires', () async {
    await repository.start('seed_user');
    final required = _schema('TelegramLoginStart')['required']! as List;
    expect(api.starts.single.toJson().keys, containsAll(required));
  });

  test('a problem becomes a login error with its extras', () async {
    api.authFailure = const ApiProblem(
      400,
      ProblemCode.codeInvalid,
      attemptsLeft: 2,
    );
    await expectLater(
      repository.verify(_loginId, '000000'),
      throwsA(
        isA<LoginException>()
            .having((e) => e.error.failure, 'failure', LoginFailure.codeInvalid)
            .having((e) => e.error.attemptsLeft, 'attemptsLeft', 2),
      ),
    );
  });

  test('an outage becomes unavailable', () async {
    api.authFailure = const ApiUnavailable();
    await expectLater(
      repository.start('seed_user'),
      throwsA(
        isA<LoginException>().having(
          (e) => e.error.failure,
          'failure',
          LoginFailure.unavailable,
        ),
      ),
    );
  });

  test('every problem code maps to its own failure', () {
    final failures = {
      for (final code in ProblemCode.values)
        loginErrorOf(ApiProblem(400, code)).failure,
    };
    expect(failures, hasLength(ProblemCode.values.length));
    expect(failures, isNot(contains(LoginFailure.unexpected)));
    expect(
      loginErrorOf(const ApiProblem(400, null)).failure,
      LoginFailure.unexpected,
    );
  });

  test('the unknown user keeps the bot link', () {
    final error = loginErrorOf(
      const ApiProblem(
        404,
        ProblemCode.telegramUserNotFound,
        botUrl: 'https://t.me/vpnclient_bot',
      ),
    );
    expect(error.botUrl, 'https://t.me/vpnclient_bot');
  });

  group('logout', () {
    test('revokes the device on the server', () async {
      await repository.logout();
      expect(api.logouts, 1);
    });

    test('an outage does not block logout', () async {
      api.authFailure = const ApiUnavailable();
      await expectLater(repository.logout(), completes);
    });

    test('an already revoked device does not block logout', () async {
      api.authFailure = const ApiProblem(401, ProblemCode.deviceRevoked);
      await expectLater(repository.logout(), completes);
    });
  });
}
