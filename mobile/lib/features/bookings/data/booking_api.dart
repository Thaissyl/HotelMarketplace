import '../../../core/network/api_client.dart';
import '../domain/booking_models.dart';

class BookingApi {
  BookingApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Booking> createBooking(CreateBookingRequest request) {
    return _apiClient.post<Booking>(
      '/api/bookings',
      data: request.toJson(),
      decoder: Booking.fromJson,
    );
  }
}
