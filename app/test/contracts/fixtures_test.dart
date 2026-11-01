// Runs the shared fixtures through the generated models (tech.md 10). The Go
// side validates the same files in core/internal/contracttest.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/gen/api/export.dart';

const _fixtures = '../contracts/fixtures';

typedef _Codec = Map<String, Object?> Function(Map<String, Object?> json);

List<File> _files(String dir) {
  final files = Directory('$_fixtures/$dir')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList();
  expect(files, isNotEmpty, reason: dir);
  return files;
}

Map<String, Object?> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

// Dart writes date-times with milliseconds, so instants compare by value.
Object? _normalize(Object? value) {
  if (value is Map<String, Object?>) {
    return {for (final e in value.entries) e.key: _normalize(e.value)};
  }
  if (value is List<Object?>) {
    return value.map(_normalize).toList();
  }
  if (value is String) {
    final isDateTime = RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value);
    if (isDateTime) {
      return DateTime.parse(value).toUtc().millisecondsSinceEpoch;
    }
  }
  return value;
}

void _expectLossless(String dir, _Codec codec) {
  for (final file in _files(dir)) {
    final original = _read(file);
    expect(
      _normalize(codec(original)),
      equals(_normalize(original)),
      reason: file.path,
    );
  }
}

void main() {
  test('profile fixtures survive the generated models', () {
    _expectLossless('profile', (json) => ProfileV1.fromJson(json).toJson());
  });

  test('tunnel request fixtures survive the generated models', () {
    _expectLossless(
      'tunnel_request',
      (json) => TunnelRequest.fromJson(json).toJson(),
    );
  });

  test('core event fixtures survive the generated models', () {
    _expectLossless('core_event', (json) => CoreEvent.fromJson(json).toJson());
  });

  test('settings keys keep their dotted wire values', () {
    expect(SettingsKey.dnsRemote.toJson(), 'dns.remote');
    expect(
      SettingsKey.whitelistAutoOnCellular.toJson(),
      'whitelist.autoOnCellular',
    );
  });

  test('an enum value outside the contract is rejected', () {
    final event = _read(File('$_fixtures/core_event/traffic.json'));
    event['type'] = 'unknown';
    expect(() => CoreEvent.fromJson(event), throwsA(anything));
  });

  test('a missing required field is rejected', () {
    final profile = _read(File('$_fixtures/profile/trial.json'));
    profile.remove('account');
    expect(() => ProfileV1.fromJson(profile), throwsA(anything));
  });
}
