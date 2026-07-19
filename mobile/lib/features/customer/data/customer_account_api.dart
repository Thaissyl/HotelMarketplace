import '../../../core/network/api_client.dart';
import '../domain/customer_account_models.dart';
import '../application/customer_state.dart';

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

  Future<List<SavedHotel>> getSavedHotels() {
    return _apiClient.get<List<SavedHotel>>(
      '/api/account/saved-hotels',
      decoder: (data) =>
          _asList(data).map(SavedHotel.fromJson).toList(growable: false),
    );
  }

  Future<SavedHotel> saveHotel(String hotelId) {
    return _apiClient.put<SavedHotel>(
      '/api/account/saved-hotels/$hotelId',
      decoder: SavedHotel.fromJson,
    );
  }

  Future<void> removeSavedHotel(String hotelId) {
    return _apiClient.delete('/api/account/saved-hotels/$hotelId');
  }

  Future<List<CustomerNotification>> getNotifications() {
    return _apiClient.get<List<CustomerNotification>>(
      '/api/account/notifications',
      queryParameters: const {'limit': 100},
      decoder: (data) => _asList(data)
          .map(CustomerNotification.fromJson)
          .toList(growable: false),
    );
  }

  Future<void> markAllNotificationsRead() {
    return _apiClient.post<void>(
      '/api/account/notifications/read-all',
      decoder: (_) {},
    );
  }
}

List<Object?> _asList(Object? data) => data is List ? data : const <Object?>[];
