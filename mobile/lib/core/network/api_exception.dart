import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() {
    if (errorCode == null) {
      return message;
    }

    return '$message ($errorCode)';
  }
}

final class BadRequestApiException extends ApiException {
  const BadRequestApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class UnauthorizedApiException extends ApiException {
  const UnauthorizedApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class ForbiddenApiException extends ApiException {
  const ForbiddenApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class NotFoundApiException extends ApiException {
  const NotFoundApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class ConflictApiException extends ApiException {
  const ConflictApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class LockedApiException extends ApiException {
  const LockedApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class ServerApiException extends ApiException {
  const ServerApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class NetworkApiException extends ApiException {
  const NetworkApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

final class UnknownApiException extends ApiException {
  const UnknownApiException({
    required super.message,
    super.statusCode,
    super.errorCode,
  });
}

class ApiExceptionMapper {
  const ApiExceptionMapper._();

  static ApiException fromDioException(DioException exception) {
    final response = exception.response;

    if (response == null) {
      return NetworkApiException(
        message: _networkMessage(exception),
      );
    }

    final problem = BackendProblemDetails.fromResponseData(response.data);
    final message = problem.detail ??
        problem.title ??
        _statusMessage(
          response.statusCode,
        );
    final statusCode = response.statusCode ?? 0;

    return switch (statusCode) {
      400 => BadRequestApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      401 => UnauthorizedApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      403 => ForbiddenApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      404 => NotFoundApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      409 => ConflictApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      423 => LockedApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      int code when code >= 500 => ServerApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
      _ => UnknownApiException(
          message: message,
          statusCode: statusCode,
          errorCode: problem.code,
        ),
    };
  }

  static String _networkMessage(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out.',
      DioExceptionType.sendTimeout => 'Request timed out while sending data.',
      DioExceptionType.receiveTimeout =>
        'Request timed out while reading data.',
      DioExceptionType.transformTimeout => 'Response processing timed out.',
      DioExceptionType.badCertificate => 'The server certificate is invalid.',
      DioExceptionType.connectionError => 'Unable to connect to the API.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.unknown => 'A network error occurred.',
      DioExceptionType.badResponse =>
        'The server returned an invalid response.',
    };
  }

  static String _statusMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'The request is invalid.',
      401 => 'Authentication is required.',
      403 => 'Access is denied.',
      404 => 'The requested resource was not found.',
      409 => 'The request conflicts with the current resource state.',
      423 => 'The resource is temporarily locked.',
      int code when code >= 500 => 'The server could not process the request.',
      _ => 'The request failed.',
    };
  }
}

class BackendProblemDetails {
  const BackendProblemDetails({
    this.title,
    this.detail,
    this.code,
  });

  final String? title;
  final String? detail;
  final String? code;

  static BackendProblemDetails fromResponseData(Object? data) {
    if (data is! Map) {
      return const BackendProblemDetails();
    }

    return BackendProblemDetails(
      title: data['title']?.toString(),
      detail: data['detail']?.toString(),
      code: data['code']?.toString(),
    );
  }
}
