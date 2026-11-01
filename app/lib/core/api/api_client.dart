import 'package:dio/dio.dart';

import '../../gen/api/export.dart';
import '../storage/token_store.dart';

/// Adds the device token to every request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);

  final TokenStore _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

VpnApiClient createApiClient({
  required String baseUrl,
  required TokenStore tokens,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl))
    ..interceptors.add(AuthInterceptor(tokens));
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return VpnApiClient(dio, baseUrl: baseUrl);
}
