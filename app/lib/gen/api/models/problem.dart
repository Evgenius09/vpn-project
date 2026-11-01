// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'problem_code.dart';

part 'problem.g.dart';

@JsonSerializable()
class Problem {
  const Problem({
    required this.title,
    required this.status,
    required this.code,
    this.type,
    this.detail,
    this.botUrl,
    this.attemptsLeft,
    this.retryAfterSec,
  });

  factory Problem.fromJson(Map<String, Object?> json) =>
      _$ProblemFromJson(json);

  final String? type;
  final String title;
  final int status;
  final String? detail;
  final ProblemCode code;
  final String? botUrl;
  final int? attemptsLeft;
  final int? retryAfterSec;

  Map<String, Object?> toJson() => _$ProblemToJson(this);
}
