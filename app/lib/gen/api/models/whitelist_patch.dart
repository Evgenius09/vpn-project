// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'whitelist_patch.g.dart';

@JsonSerializable()
class WhitelistPatch {
  const WhitelistPatch({
    this.autoOnCellular,
  });
  
  factory WhitelistPatch.fromJson(Map<String, Object?> json) => _$WhitelistPatchFromJson(json);
  
  final bool? autoOnCellular;

  Map<String, Object?> toJson() => _$WhitelistPatchToJson(this);
}
