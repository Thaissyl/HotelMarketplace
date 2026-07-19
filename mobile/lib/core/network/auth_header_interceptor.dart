import 'package:dio/dio.dart';

import '../storage/secure_session_storage.dart';
import 'session_invalidation_notifier.dart';

class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(
    this._sessionStorage,
    this._sessionInvalidationNotifier,
  );

  static const String _hotelScopedExtraKey = 'hotelScoped';

  final SecureSessionStorage _sessionStorage;
  final SessionInvalidationNotifier _sessionInvalidationNotifier;

  static Options hotelScopedOptions([Options? options]) {
    final currentOptions = options ?? Options();
    final extra = Map<String, dynamic>.of(currentOptions.extra ?? const {});
    extra[_hotelScopedExtraKey] = true;

    return currentOptions.copyWith(
      extra: extra,
    );
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _sessionStorage.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    final isHotelScoped = options.extra[_hotelScopedExtraKey] == true ||
        _hasHotelRouteParameter(options.path);

    if (isHotelScoped) {
      final currentHotelId = await _sessionStorage.getCurrentHotelId();
      if (currentHotelId != null && currentHotelId.isNotEmpty) {
        options.headers['X-Hotel-Id'] = currentHotelId;
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final authorizationHeader =
        err.requestOptions.headers['Authorization']?.toString();
    final isAuthenticatedRequest = authorizationHeader != null &&
        authorizationHeader.startsWith('Bearer ') &&
        authorizationHeader.length > 'Bearer '.length;

    if (err.response?.statusCode == 401 &&
        isAuthenticatedRequest &&
        !_isAuthenticationEndpoint(err.requestOptions.path)) {
      await _sessionStorage.clearSession();
      _sessionInvalidationNotifier.notifySessionInvalidated();
    }

    handler.next(err);
  }

  bool _hasHotelRouteParameter(String path) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty);
    final segmentList = segments.toList(growable: false);

    for (var index = 0; index < segmentList.length - 1; index += 1) {
      if (segmentList[index] == 'hotels' &&
          _looksLikeGuid(segmentList[index + 1])) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeGuid(String value) {
    final guidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    return guidPattern.hasMatch(value);
  }

  bool _isAuthenticationEndpoint(String path) {
    return path == '/api/auth/login' || path == '/api/auth/register';
  }
}
