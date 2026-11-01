// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Problem _$ProblemFromJson(Map<String, dynamic> json) => Problem(
  title: json['title'] as String,
  status: (json['status'] as num).toInt(),
  code: $enumDecode(_$ProblemCodeEnumMap, json['code']),
  type: json['type'] as String?,
  detail: json['detail'] as String?,
  botUrl: json['botUrl'] as String?,
  attemptsLeft: (json['attemptsLeft'] as num?)?.toInt(),
  retryAfterSec: (json['retryAfterSec'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProblemToJson(Problem instance) => <String, dynamic>{
  'type': ?instance.type,
  'title': instance.title,
  'status': instance.status,
  'detail': ?instance.detail,
  'code': instance.code.toJson(),
  'botUrl': ?instance.botUrl,
  'attemptsLeft': ?instance.attemptsLeft,
  'retryAfterSec': ?instance.retryAfterSec,
};

const _$ProblemCodeEnumMap = {
  ProblemCode.unauthorized: 'unauthorized',
  ProblemCode.deviceRevoked: 'device_revoked',
  ProblemCode.validationFailed: 'validation_failed',
  ProblemCode.rateLimited: 'rate_limited',
  ProblemCode.telegramUserNotFound: 'telegram_user_not_found',
  ProblemCode.codeInvalid: 'code_invalid',
  ProblemCode.codeExpired: 'code_expired',
  ProblemCode.deviceLimitReached: 'device_limit_reached',
  ProblemCode.panelUnavailable: 'panel_unavailable',
  ProblemCode.notFound: 'not_found',
  ProblemCode.internal: 'internal',
};
