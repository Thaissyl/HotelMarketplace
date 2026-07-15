import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResponse> login(LoginRequest request) {
    return _apiClient.post<AuthResponse>(
      '/api/auth/login',
      data: request.toJson(),
      decoder: AuthResponse.fromJson,
    );
  }

  Future<AuthResponse> register(RegisterRequest request) {
    return _apiClient.post<AuthResponse>(
      '/api/auth/register',
      data: request.toJson(),
      decoder: AuthResponse.fromJson,
    );
  }
}
