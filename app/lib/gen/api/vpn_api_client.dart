// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/auth_client.dart';
import 'clients/profile_client.dart';

/// VPN client API `v1.0.0`.
///
/// HTTP API v1 and every shared type (tech.md 5.2 to 5.5 and 19). Operational endpoints (/healthz, /metrics) and the Telegram webhook are not part of the client contract and stay out of this file.
class VpnApiClient {
  VpnApiClient(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  AuthClient? _auth;
  ProfileClient? _profile;

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  ProfileClient get profile => _profile ??= ProfileClient(_dio, baseUrl: _baseUrl);
}
