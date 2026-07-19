import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/network/session_invalidation_notifier.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../data/auth_api.dart';
import '../domain/auth_models.dart';
import 'auth_state.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authApi: ref.watch(authApiProvider),
    sessionStorage: ref.watch(secureSessionStorageProvider),
    sessionInvalidationNotifier: ref.watch(sessionInvalidationNotifierProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthApi authApi,
    required SecureSessionStorage sessionStorage,
    required SessionInvalidationNotifier sessionInvalidationNotifier,
  })  : _authApi = authApi,
        _sessionStorage = sessionStorage,
        super(const AuthState.checking()) {
    _sessionInvalidationSubscription =
        sessionInvalidationNotifier.events.listen((_) {
      if (mounted) {
        state = const AuthState.unauthenticated();
      }
    });
    unawaited(restoreSession());
  }

  final AuthApi _authApi;
  final SecureSessionStorage _sessionStorage;
  late final StreamSubscription<void> _sessionInvalidationSubscription;

  @override
  void dispose() {
    unawaited(_sessionInvalidationSubscription.cancel());
    super.dispose();
  }

  Future<void> restoreSession() async {
    state = const AuthState.checking();

    final accessToken = await _sessionStorage.getAccessToken();
    final userSession = await _sessionStorage.getUserSession();

    if (accessToken == null ||
        accessToken.isEmpty ||
        userSession == null ||
        !_hasUsableSession(accessToken, userSession)) {
      await _sessionStorage.clearSession();
      state = const AuthState.unauthenticated();
      return;
    }

    state = AuthState.authenticated(userSession);
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.authenticating(userSession: state.userSession);

    try {
      final response = await _authApi.login(
        LoginRequest(
          email: email,
          password: password,
        ),
      );
      await _persistAuthResponse(response);
      state = AuthState.authenticated(response.toUserSession());
      return true;
    } catch (error) {
      await _sessionStorage.clearSession();
      state = AuthState.authError(error);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRoleCode role,
  }) async {
    state = AuthState.authenticating(userSession: state.userSession);

    try {
      final response = await _authApi.register(
        RegisterRequest(
          email: email,
          password: password,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
        ),
      );
      await _persistAuthResponse(response);
      state = AuthState.authenticated(response.toUserSession());
      return true;
    } catch (error) {
      await _sessionStorage.clearSession();
      state = AuthState.authError(error);
      return false;
    }
  }

  Future<void> logout() async {
    await _sessionStorage.clearSession();
    state = const AuthState.unauthenticated();
  }

  Future<void> _persistAuthResponse(AuthResponse response) async {
    final userSession = response.toUserSession();
    await _sessionStorage.saveAccessToken(response.accessToken);
    await _sessionStorage.saveUserSession(userSession);

    if (userSession.hotelIds.isNotEmpty) {
      await _sessionStorage.saveCurrentHotelId(userSession.hotelIds.first);
    } else {
      await _sessionStorage.clearCurrentHotelId();
    }
  }

  bool _isExpired(DateTime expiresAtUtc) {
    return expiresAtUtc
        .toUtc()
        .isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)));
  }

  bool _hasUsableSession(String accessToken, UserSession userSession) {
    if (_isExpired(userSession.expiresAtUtc)) {
      return false;
    }

    final tokenExpiry = _tryReadJwtExpiry(accessToken);
    if (tokenExpiry == null) {
      return true;
    }

    return !_isExpired(tokenExpiry);
  }

  DateTime? _tryReadJwtExpiry(String accessToken) {
    final segments = accessToken.split('.');
    if (segments.length < 2) {
      return null;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(
          base64Url.normalize(segments[1]),
        ),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final exp = decoded['exp'];
      if (exp is! num) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
