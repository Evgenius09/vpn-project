// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutingRule _$RoutingRuleFromJson(Map<String, dynamic> json) => RoutingRule(
  id: json['id'] as String,
  match: $enumDecode(_$RuleMatchEnumMap, json['match']),
  value: json['value'] as String,
  action: $enumDecode(_$RuleActionEnumMap, json['action']),
);

Map<String, dynamic> _$RoutingRuleToJson(RoutingRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'match': instance.match.toJson(),
      'value': instance.value,
      'action': instance.action.toJson(),
    };

const _$RuleMatchEnumMap = {
  RuleMatch.domain: 'domain',
  RuleMatch.domainSuffix: 'domain_suffix',
  RuleMatch.domainKeyword: 'domain_keyword',
  RuleMatch.ipCidr: 'ip_cidr',
  RuleMatch.ruleSet: 'rule_set',
  RuleMatch.app: 'app',
};

const _$RuleActionEnumMap = {
  RuleAction.proxy: 'proxy',
  RuleAction.direct: 'direct',
  RuleAction.block: 'block',
};
