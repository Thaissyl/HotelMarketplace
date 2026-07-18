import '../../../core/storage/secure_session_storage.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticating,
  authenticated,
  authError,
}

class AuthState {
  const AuthState({
    required this.status,
    this.userSession,
    this.error,
  });

  const AuthState.checking() : this(status: AuthStatus.checking);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticating({UserSession? userSession})
      : this(
          status: AuthStatus.authenticating,
          userSession: userSession,
        );

  const AuthState.authenticated(UserSession userSession)
      : this(
          status: AuthStatus.authenticated,
          userSession: userSession,
        );

  const AuthState.authError(Object error)
      : this(
          status: AuthStatus.authError,
          error: error,
        );

  final AuthStatus status;
  final UserSession? userSession;
  final Object? error;

  bool get isChecking => status == AuthStatus.checking;

  bool get isLoading => status == AuthStatus.authenticating;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && userSession != null;
}
