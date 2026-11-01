// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProblemCode {
  @JsonValue('unauthorized')
  unauthorized('unauthorized'),
  @JsonValue('device_revoked')
  deviceRevoked('device_revoked'),
  @JsonValue('validation_failed')
  validationFailed('validation_failed'),
  @JsonValue('rate_limited')
  rateLimited('rate_limited'),
  @JsonValue('telegram_user_not_found')
  telegramUserNotFound('telegram_user_not_found'),
  @JsonValue('code_invalid')
  codeInvalid('code_invalid'),
  @JsonValue('code_expired')
  codeExpired('code_expired'),
  @JsonValue('device_limit_reached')
  deviceLimitReached('device_limit_reached'),
  @JsonValue('panel_unavailable')
  panelUnavailable('panel_unavailable'),
  @JsonValue('not_found')
  notFound('not_found'),
  @JsonValue('internal')
  internal('internal');

  const ProblemCode(this.json);

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
