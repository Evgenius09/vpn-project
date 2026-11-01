// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'core_event_type.dart';
import 'error_payload.dart';
import 'mode_payload.dart';
import 'state_payload.dart';
import 'traffic_payload.dart';
import 'url_test_payload.dart';

part 'core_event.g.dart';

/// A flat envelope. Exactly one payload is set and it matches type.
@JsonSerializable()
class CoreEvent {
  const CoreEvent({
    required this.type,
    required this.at,
    this.state,
    this.mode,
    this.traffic,
    this.urlTest,
    this.error,
  });

  factory CoreEvent.fromJson(Map<String, Object?> json) =>
      _$CoreEventFromJson(json);

  final CoreEventType type;
  final DateTime at;
  final StatePayload? state;
  final ModePayload? mode;
  final TrafficPayload? traffic;
  final UrlTestPayload? urlTest;
  final ErrorPayload? error;

  Map<String, Object?> toJson() => _$CoreEventToJson(this);
}
