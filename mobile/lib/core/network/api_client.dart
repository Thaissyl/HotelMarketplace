import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? data) decoder,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: queryParameters,
      options: options,
    );

    return decoder(response.data);
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? data) decoder,
  }) async {
    final response = await _dio.post<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

    return decoder(response.data);
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? data) decoder,
  }) async {
    final response = await _dio.put<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

    return decoder(response.data);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? data) decoder,
  }) async {
    final response = await _dio.patch<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

    return decoder(response.data);
  }

  Future<void> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _dio.delete<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<ApiHealthStatus> getHealthStatus() {
    return get<ApiHealthStatus>(
      '/health',
      decoder: ApiHealthStatus.fromJson,
    );
  }
}

class ApiHealthStatus {
  const ApiHealthStatus({
    required this.status,
    required this.checks,
  });

  final String status;
  final List<ApiHealthCheck> checks;

  static ApiHealthStatus fromJson(Object? data) {
    final json = _asMap(data);
    final rawChecks = json['checks'];
    final checks = rawChecks is List
        ? rawChecks.map(ApiHealthCheck.fromJson).toList(growable: false)
        : const <ApiHealthCheck>[];

    return ApiHealthStatus(
      status: json['status']?.toString() ?? 'Unknown',
      checks: checks,
    );
  }
}

class ApiHealthCheck {
  const ApiHealthCheck({
    required this.name,
    required this.status,
    required this.duration,
  });

  final String name;
  final String status;
  final double duration;

  static ApiHealthCheck fromJson(Object? data) {
    final json = _asMap(data);

    return ApiHealthCheck(
      name: json['name']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'Unknown',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  return const <String, dynamic>{};
}
