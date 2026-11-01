// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/profile_v1.dart';

part 'profile_client.g.dart';

@RestApi()
abstract class ProfileClient {
  factory ProfileClient(Dio dio, {String? baseUrl}) = _ProfileClient;

  @GET('/v1/profile')
  Future<ProfileV1> getProfile({@Header('If-None-Match') String? ifNoneMatch});

  @GET('/v1/rulesets/{id}.srs')
  @DioResponseType(ResponseType.stream)
  Stream<String> getRuleSet({@Path('id') required String id});
}
