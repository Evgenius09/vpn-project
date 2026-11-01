// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_set_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleSetRef _$RuleSetRefFromJson(Map<String, dynamic> json) => RuleSetRef(
  id: json['id'] as String,
  url: json['url'] as String,
  sha256: json['sha256'] as String,
);

Map<String, dynamic> _$RuleSetRefToJson(RuleSetRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'sha256': instance.sha256,
    };
