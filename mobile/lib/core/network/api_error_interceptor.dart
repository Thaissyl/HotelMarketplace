import 'package:dio/dio.dart';

import 'api_exception.dart';

class ApiErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      err.copyWith(error: ApiExceptionMapper.fromDioException(err)),
    );
  }
}
