import '../../../core/network/api_client.dart';
import '../domain/customer_account_models.dart';

class CustomerAccountApi {
  CustomerAccountApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CustomerProfile> getProfile() {
    return _apiClient.get<CustomerProfile>(
      '/api/account/profile',
      decoder: CustomerProfile.fromJson,
    );
  }

  Future<CustomerProfile> updateProfile(UpdateCustomerProfileRequest request) {
    return _apiClient.put<CustomerProfile>(
      '/api/account/profile',
      data: request.toJson(),
      decoder: CustomerProfile.fromJson,
    );
  }

  Future<void> changePassword(ChangeCustomerPasswordRequest request) {
    return _apiClient.post<void>(
      '/api/account/change-password',
      data: request.toJson(),
      decoder: (_) {},
    );
  }
}
