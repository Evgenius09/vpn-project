// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum UtlsFingerprint {
  @JsonValue('chrome')
  chrome('chrome'),
  @JsonValue('firefox')
  firefox('firefox'),
  @JsonValue('safari')
  safari('safari'),
  @JsonValue('ios')
  ios('ios'),
  @JsonValue('android')
  android('android'),
  @JsonValue('edge')
  edge('edge'),
  @JsonValue('random')
  random('random');

  const UtlsFingerprint(this.json);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to String. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
}
