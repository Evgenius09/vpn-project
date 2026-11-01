// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum RuleMatch {
  @JsonValue('domain')
  domain('domain'),
  @JsonValue('domain_suffix')
  domainSuffix('domain_suffix'),
  @JsonValue('domain_keyword')
  domainKeyword('domain_keyword'),
  @JsonValue('ip_cidr')
  ipCidr('ip_cidr'),
  @JsonValue('rule_set')
  ruleSet('rule_set'),
  @JsonValue('app')
  app('app');

  const RuleMatch(this.json);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError('Cannot convert enum value with null JSON representation to String. '
          'This usually happens for \$unknown or @JsonValue(null) entries.');
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();
}
