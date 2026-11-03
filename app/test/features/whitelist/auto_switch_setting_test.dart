import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:vpnclient/features/whitelist/domain/auto_switch_setting.dart';
import 'package:vpnclient/gen/api/export.dart';

// Merging ClientPolicy with the user's toggle (tech.md 34.1, 10): the user's
// choice wins unless the provider locked the key, then the policy default,
// then the built-in value; the flag turns the request's auto switch off.

/// One combination of the inputs: flag, locked, policy default, user choice.
typedef _Case = (bool, bool, bool?, bool?);

ClientPolicy _policy(_Case input) {
  final (flag, locked, policyDefault, _) = input;
  final json =
      jsonDecode(
            File('../contracts/fixtures/profile/seed.json').readAsStringSync(),
          )['policy']
          as Map<String, Object?>;
  json['flags'] = {'autoWhitelist': flag};
  json['locked'] = [if (locked) 'whitelist.autoOnCellular'];
  json['defaults'] = {
    if (policyDefault != null) 'whitelist': {'autoOnCellular': policyDefault},
  };
  return ClientPolicy.fromJson(json);
}

extension on Any {
  Generator<bool?> get maybeBool => any.choose(const [null, true, false]);

  Generator<_Case> get policyCase => combine4(
    any.bool,
    any.bool,
    any.maybeBool,
    any.maybeBool,
    (bool a, bool b, bool? c, bool? d) => (a, b, c, d),
  );
}

void main() {
  Glados(any.policyCase).test('a locked key ignores the user', (input) {
    final (_, locked, policyDefault, choice) = input;
    if (!locked) {
      return;
    }
    expect(
      autoOnCellularFrom(_policy(input), choice),
      policyDefault ?? builtInAutoOnCellular,
    );
    expect(autoOnCellularLocked(_policy(input)), isTrue);
  });

  Glados(any.policyCase)
      .test('an open key takes the user choice first', (input) {
        final (_, locked, policyDefault, choice) = input;
        if (locked) {
          return;
        }
        expect(
          autoOnCellularFrom(_policy(input), choice),
          choice ?? policyDefault ?? builtInAutoOnCellular,
        );
      });

  Glados(any.policyCase).test('the flag gates the request', (input) {
    final (flag, _, _, choice) = input;
    final policy = _policy(input);
    expect(
      autoSwitchEnabled(policy, choice),
      flag && autoOnCellularFrom(policy, choice),
    );
  });

  test('the built-in value matches backend/config/policy.yaml', () {
    final yaml = File('../backend/config/policy.yaml').readAsStringSync();
    expect(yaml, contains('autoOnCellular: $builtInAutoOnCellular'));
  });

  Glados(any.bool).test('setting the toggle keeps every other key', (value) {
    const settings = SettingsPatch(
      ui: UiPatch(sortByPing: false),
      ping: PingPatch(onOpen: false),
    );
    final next = withAutoOnCellular(settings, value);
    expect(next.whitelist?.autoOnCellular, value);
    expect(next.ui?.sortByPing, isFalse);
    expect(next.ping?.onOpen, isFalse);
  });
}
