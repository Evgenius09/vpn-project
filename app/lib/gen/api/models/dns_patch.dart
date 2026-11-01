// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'dns_strategy.dart';

part 'dns_patch.g.dart';

@JsonSerializable()
class DnsPatch {
  const DnsPatch({
    this.remote,
    this.direct,
    this.strategy,
  });
  
  factory DnsPatch.fromJson(Map<String, Object?> json) => _$DnsPatchFromJson(json);
  
  final String? remote;
  final String? direct;
  final DnsStrategy? strategy;

  Map<String, Object?> toJson() => _$DnsPatchToJson(this);
}
