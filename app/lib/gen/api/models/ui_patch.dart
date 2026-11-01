// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ui_locale.dart';
import 'ui_theme.dart';

part 'ui_patch.g.dart';

@JsonSerializable()
class UiPatch {
  const UiPatch({
    this.sortByPing,
    this.locale,
    this.theme,
  });
  
  factory UiPatch.fromJson(Map<String, Object?> json) => _$UiPatchFromJson(json);
  
  final bool? sortByPing;
  final UiLocale? locale;
  final UiTheme? theme;

  Map<String, Object?> toJson() => _$UiPatchToJson(this);
}
