// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_result.dart';
import '../models/telegram_login_challenge.dart';
import '../models/telegram_login_start.dart';
import '../models/telegram_login_verify.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  @POST('/v1/auth/telegram/start')
  Future<TelegramLoginChallenge> startTelegramLogin({
    @Body() required TelegramLoginStart body,
  });

  @POST('/v1/auth/telegram/verify')
  Future<AuthResult> verifyTelegramLogin({
    @Body() required TelegramLoginVerify body,
  });

  @POST('/v1/auth/logout')
  Future<void> logout();
}
