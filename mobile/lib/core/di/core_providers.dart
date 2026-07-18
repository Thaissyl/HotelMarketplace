import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../network/api_client.dart';
import '../network/api_error_interceptor.dart';
import '../network/auth_header_interceptor.dart';
import '../storage/secure_session_storage.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw StateError('AppEnvironment must be provided at application startup.');
});

final secureSessionStorageProvider = Provider<SecureSessionStorage>((ref) {
  throw StateError(
    'SecureSessionStorage must be provided at application startup.',
  );
});

final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final sessionStorage = ref.watch(secureSessionStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: environment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        Headers.acceptHeader: 'application/json',
        Headers.contentTypeHeader: 'application/json',
      },
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.addAll([
    AuthHeaderInterceptor(sessionStorage),
    ApiErrorInterceptor(),
    if (kDebugMode)
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
      ),
  ]);

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
